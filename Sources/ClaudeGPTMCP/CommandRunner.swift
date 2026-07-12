import Foundation

struct CommandResult {
    let output: String
    let error: String
    let status: Int32
}

enum CommandRunnerError: LocalizedError {
    case launchFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .launchFailed(let detail): "Could not launch Claude Code: \(detail)"
        case .timedOut: "Claude Code exceeded the 10-minute MCP time limit."
        }
    }
}

enum CommandRunner {
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 600
    ) throws -> CommandResult {
        let process = Process()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-gpt-mcp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempRoot,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let outputURL = tempRoot.appendingPathComponent("stdout")
        let errorURL = tempRoot.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        FileManager.default.createFile(atPath: errorURL.path, contents: nil, attributes: [.posixPermissions: 0o600])

        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        do {
            try process.run()
        } catch {
            throw CommandRunnerError.launchFailed(error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw CommandRunnerError.timedOut
        }

        try outputHandle.synchronize()
        try errorHandle.synchronize()
        return CommandResult(
            output: String(decoding: try Data(contentsOf: outputURL), as: UTF8.self),
            error: String(decoding: try Data(contentsOf: errorURL), as: UTF8.self),
            status: process.terminationStatus
        )
    }
}
