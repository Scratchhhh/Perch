import Foundation
import Network
import PerchCore

/// Loopback TCP listener that receives `RelayEnvelope` payloads from `perch-helper`.
/// All Network.framework callbacks run on a single serial queue, which is what makes the
/// `@unchecked Sendable` here honest: mutable state is only ever touched on `queue`.
final class LocalListener: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.perch.listener")
    private let token: String
    private let onMessage: @Sendable (RelayMessage) -> Void

    private var listener: NWListener?
    private var readers: Set<ConnectionReader> = []

    init(token: String, onMessage: @escaping @Sendable (RelayMessage) -> Void) {
        self.token = token
        self.onMessage = onMessage
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        parameters.allowLocalEndpointReuse = true
        parameters.acceptLocalOnly = true

        let listener = try NWListener(using: parameters, on: .any)
        listener.stateUpdateHandler = { [weak self] state in
            self?.handleStateChange(state)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        for reader in readers {
            reader.cancel()
        }
        readers.removeAll()
        listener?.cancel()
        listener = nil
    }

    private func handleStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            if let port = listener?.port?.rawValue {
                writePort(port)
            }
        case .failed(let error):
            PerchLog.listener.error("listener failed: \(error.localizedDescription, privacy: .public)")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func writePort(_ port: UInt16) {
        do {
            try PerchPaths.ensureSupportDirectory()
            try Data(String(port).utf8).write(to: PerchPaths.portFile, options: .atomic)
            PerchLog.listener.info("listening on 127.0.0.1:\(port)")
        } catch {
            PerchLog.listener.error("failed to publish port: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func accept(_ connection: NWConnection) {
        let reader = ConnectionReader(connection: connection, queue: queue) { [weak self] data in
            guard let self else { return }
            if let data {
                self.process(data)
            }
            self.finishReader(forConnection: connection)
        }
        readers.insert(reader)
        reader.start()
    }

    private func finishReader(forConnection connection: NWConnection) {
        readers = readers.filter { $0.connection !== connection }
    }

    private func process(_ data: Data) {
        guard !data.isEmpty else { return }
        do {
            let envelope = try PerchJSON.decoder().decode(RelayEnvelope.self, from: data)
            guard ConstantTime.equal(envelope.token, token) else {
                PerchLog.listener.error("rejected payload: invalid token")
                return
            }
            onMessage(envelope.message)
        } catch {
            PerchLog.listener.error("failed to decode payload: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Reads a single connection to completion on the listener queue and reports the bytes back.
/// Keeping the `NWConnection` inside one queue-confined object avoids passing it across isolation.
private final class ConnectionReader: Hashable, @unchecked Sendable {
    let connection: NWConnection
    private let queue: DispatchQueue
    private let limit: Int
    private let completion: @Sendable (Data?) -> Void

    private var buffer = Data()
    private var done = false

    init(connection: NWConnection, queue: DispatchQueue, limit: Int = 256 * 1024, completion: @escaping @Sendable (Data?) -> Void) {
        self.connection = connection
        self.queue = queue
        self.limit = limit
        self.completion = completion
    }

    func start() {
        connection.start(queue: queue)
        readMore()
    }

    func cancel() {
        finish(with: nil)
    }

    private func readMore() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [self] data, _, isComplete, error in
            if let data, !data.isEmpty {
                buffer.append(data)
                if buffer.count > limit {
                    finish(with: nil)
                    return
                }
            }
            if let error {
                PerchLog.listener.error("receive error: \(error.localizedDescription, privacy: .public)")
                finish(with: nil)
                return
            }
            if isComplete {
                finish(with: buffer)
            } else {
                readMore()
            }
        }
    }

    private func finish(with data: Data?) {
        guard !done else { return }
        done = true
        connection.cancel()
        completion(data)
    }

    static func == (lhs: ConnectionReader, rhs: ConnectionReader) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

enum ConstantTime {
    /// Length-independent-ish comparison so token checks don't leak timing. Localhost only,
    /// but cheap to do correctly.
    static func equal(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for index in a.indices {
            difference |= a[index] ^ b[index]
        }
        return difference == 0
    }
}
