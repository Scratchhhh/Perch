import Foundation

func failHelper(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

let arguments = CommandLine.arguments

guard arguments.count >= 2 else {
    failHelper("usage: perch-helper <hook|mcp>", code: 64)
}

switch arguments[1] {
case "hook":
    exit(HookCommand.run())
case "mcp":
    exit(MCPCommand.run())
default:
    failHelper("unknown subcommand: \(arguments[1])", code: 64)
}
