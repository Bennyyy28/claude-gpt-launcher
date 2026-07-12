import Foundation

struct CommandResult {
    let output: String
    let error: String
    let status: Int32
}

enum CommandRunnerError: LocalizedError {
    case launchFailed(String)
    case timedOut
    case outputLimitExceeded

    var errorDescription: String? {
        switch self {
        case .launchFailed(let detail): "Could not launch Claude Code: \(detail)"
        case .timedOut: "Claude Code exceeded the 10-minute MCP time limit."
        case .outputLimitExceeded: "Claude Code exceeded the 10 MB MCP output limit."
        }
    }
}

enum CommandRunner {
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 600,
        outputLimitBytes: UInt64 = 10 * 1_024 * 1_024
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
            process.environment = sanitizedEnvironment(overrides: environment)
        }

        do {
            try process.run()
        } catch {
            throw CommandRunnerError.launchFailed(error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            let outputSize = fileSize(outputURL) + fileSize(errorURL)
            if outputSize > outputLimitBytes {
                process.terminate()
                process.waitUntilExit()
                throw CommandRunnerError.outputLimitExceeded
            }
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

    private static func fileSize(_ url: URL) -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private static func sanitizedEnvironment(overrides: [String: String]) -> [String: String] {
        let source = ProcessInfo.processInfo.environment
        let exactKeys = Set([
            "HOME", "PATH", "TMPDIR", "USER", "LOGNAME", "SHELL", "LANG", "TERM",
            "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
            "http_proxy", "https_proxy", "all_proxy", "no_proxy",
            "SSL_CERT_FILE", "NODE_EXTRA_CA_CERTS",
        ])
        var result = source.filter { key, _ in
            exactKeys.contains(key) || key.hasPrefix("LC_") || key.hasPrefix("XDG_")
        }
        result.merge(overrides) { _, new in new }
        return result
    }
}
