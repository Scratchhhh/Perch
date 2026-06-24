import Foundation
import Network

enum RelayError: Error, CustomStringConvertible {
    case invalidPort
    case timeout
    case connection(String)

    var description: String {
        switch self {
        case .invalidPort: return "invalid listener port"
        case .timeout: return "timed out reaching the app"
        case .connection(let detail): return "connection failed: \(detail)"
        }
    }
}

/// Sends a single `RelayEnvelope` to the app's loopback listener and returns once the bytes are
/// flushed. Synchronous on purpose: the helper is a short-lived process.
enum RelayClient {
    static func send(_ message: RelayMessage, timeout: TimeInterval = 3) throws {
        let endpoint = try PerchPaths.readEndpoint()
        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
            throw RelayError.invalidPort
        }

        let envelope = RelayEnvelope(token: endpoint.token, message: message)
        let data = try PerchJSON.encoder().encode(envelope)

        let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        let queue = DispatchQueue(label: "com.perch.relay")
        let semaphore = DispatchSemaphore(value: 0)
        let outcome = Outcome()
        let box = ConnectionBox(connection)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                box.connection.send(content: data, completion: .contentProcessed { error in
                    if let error {
                        outcome.set(error)
                        semaphore.signal()
                        return
                    }
                    box.connection.send(
                        content: nil,
                        contentContext: .finalMessage,
                        isComplete: true,
                        completion: .contentProcessed { _ in semaphore.signal() }
                    )
                })
            case .failed(let error):
                outcome.set(error)
                semaphore.signal()
            case .cancelled:
                semaphore.signal()
            default:
                break
            }
        }

        connection.start(queue: queue)
        let waitResult = semaphore.wait(timeout: .now() + timeout)
        connection.cancel()

        if waitResult == .timedOut {
            throw RelayError.timeout
        }
        if let error = outcome.value {
            throw RelayError.connection(error.localizedDescription)
        }
    }
}

private final class Outcome: @unchecked Sendable {
    private var error: Error?
    private let lock = NSLock()

    func set(_ newError: Error) {
        lock.lock()
        if error == nil { error = newError }
        lock.unlock()
    }

    var value: Error? {
        lock.lock()
        defer { lock.unlock() }
        return error
    }
}

private final class ConnectionBox: @unchecked Sendable {
    let connection: NWConnection
    init(_ connection: NWConnection) {
        self.connection = connection
    }
}
