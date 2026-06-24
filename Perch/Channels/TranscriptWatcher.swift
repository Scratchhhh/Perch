import Foundation
import CoreServices
import PerchCore

/// Passive backstop: tails Claude Code transcripts under ~/.claude/projects and emits a "finished"
/// signal when an assistant turn ends. Shares the real session id with the hook channel, so the
/// deduplicator collapses the two when both fire. All state is touched only on `queue`.
final class TranscriptWatcher: @unchecked Sendable {
    private let root: URL
    private let onMessage: @Sendable (RelayMessage) -> Void
    private let queue = DispatchQueue(label: "com.perch.filewatch")

    private var stream: FSEventStreamRef?
    private var offsets: [String: UInt64] = [:]
    private var buffers: [String: IncrementalLineBuffer] = [:]

    init(root: URL = TranscriptWatcher.defaultRoot(), onMessage: @escaping @Sendable (RelayMessage) -> Void) {
        self.root = root
        self.onMessage = onMessage
    }

    static func defaultRoot() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    func start() {
        queue.async { [self] in
            guard FileManager.default.fileExists(atPath: root.path) else {
                PerchLog.filewatch.info("transcript root missing; file watch idle")
                return
            }
            seedOffsets()
            startStream()
        }
    }

    func stop() {
        queue.async { [self] in
            guard let stream else { return }
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    private func seedOffsets() {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            offsets[url.path] = fileSize(of: url)
        }
    }

    private func fileSize(of url: URL) -> UInt64 {
        let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        return UInt64(size ?? 0)
    }

    private func startStream() {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<TranscriptWatcher>.fromOpaque(info).takeUnretainedValue()
            let cPaths = paths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
            for index in 0..<count {
                let path = String(cString: cPaths[index])
                if path.hasSuffix(".jsonl") {
                    watcher.handleChange(atPath: path)
                }
            }
        }

        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [root.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            PerchLog.filewatch.error("failed to create FSEvents stream")
            return
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
        PerchLog.filewatch.info("watching \(self.root.path, privacy: .public)")
    }

    private func handleChange(atPath path: String) {
        let url = URL(fileURLWithPath: path)
        let size = fileSize(of: url)
        var offset = offsets[path] ?? 0

        if size < offset {
            offset = 0
            buffers[path] = IncrementalLineBuffer()
        }
        guard size > offset else {
            offsets[path] = size
            return
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: offset)
        } catch {
            return
        }

        let data = (try? handle.read(upToCount: Int(size - offset))) ?? Data()
        offsets[path] = offset + UInt64(data.count)
        guard !data.isEmpty else { return }

        var buffer = buffers[path] ?? IncrementalLineBuffer()
        let lines = buffer.append(data)
        buffers[path] = buffer

        for line in lines {
            guard let signal = TranscriptParser.signal(forLine: line) else { continue }
            onMessage(RelayMessage(
                sessionId: signal.sessionId,
                source: .claudeCode,
                channel: .filewatch,
                kind: signal.kind,
                message: "Agent finished (detected from transcript).",
                project: signal.cwd,
                transcriptPath: path,
                timestamp: signal.timestamp ?? Date()
            ))
        }
    }
}
