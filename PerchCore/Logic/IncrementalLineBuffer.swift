import Foundation

/// Accumulates bytes appended to a file and hands back complete `\n`-terminated lines, holding any
/// trailing partial line until the rest arrives. Survives a writer that flushes mid-line.
public struct IncrementalLineBuffer {
    private var partial = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [Data] {
        partial.append(data)
        var lines: [Data] = []
        let newline: UInt8 = 0x0A

        while let index = partial.firstIndex(of: newline) {
            let line = partial[partial.startIndex..<index]
            lines.append(Data(line))
            partial = Data(partial[partial.index(after: index)...])
        }
        return lines
    }

    public mutating func reset() {
        partial.removeAll(keepingCapacity: false)
    }
}
