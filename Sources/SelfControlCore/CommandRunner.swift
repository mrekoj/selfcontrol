import Foundation

public struct CommandResult {
    public let exitCode: Int32
    public let output: String
}

public protocol CommandRunner {
    func run(_ launchPath: String, _ arguments: [String]) -> CommandResult
}

public final class ProcessCommandRunner: CommandRunner {
    public init() {}

    public func run(_ launchPath: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: -1, output: error.localizedDescription)
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return CommandResult(exitCode: process.terminationStatus, output: output)
    }
}
