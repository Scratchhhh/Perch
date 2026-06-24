import Foundation

enum MCPCommand {
    static func run() -> Int32 {
        FileHandle.standardError.write(Data("perch-helper mcp: the MCP server is not available in this build\n".utf8))
        return 70
    }
}
