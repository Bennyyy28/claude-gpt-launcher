import Foundation

enum ClaudeHarnessMode: String {
    case plan
    case edit
}

struct ClaudeHarnessResult {
    let mode: ClaudeHarnessMode
    let model: String
    let projectPath: String
    let output: String
}

enum ClaudeHarnessRunnerError: LocalizedError {
    case missingPrompt
    case editsNotConfirmed
    case unsupportedModel
    case backendMissing
    case editsDisabled
    case promptTooLong
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPrompt: "A non-empty prompt is required."
        case .editsNotConfirmed: "Set confirmEdits to true to use the editing tool."
        case .unsupportedModel: "Model must be gpt-5.6-sol, gpt-5.6-terra, or gpt-5.6-luna."
        case .backendMissing: "The claude-gpt backend launcher is missing."
        case .editsDisabled: "MCP edits are disabled. Re-register with CLAUDE_GPT_ENABLE_MCP_EDITS=1 after reviewing the risk."
        case .promptTooLong: "The MCP prompt exceeds the 20,000-character limit."
        case .executionFailed(let detail): "Claude Code failed: \(detail)"
        }
    }
}

enum ClaudeHarnessRunner {
    static let allowedModels = ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"]

    static func run(
        projectPath: String,
        prompt: String,
        model: String,
        mode: ClaudeHarnessMode,
        confirmEdits: Bool,
        allowProtectedRepository: Bool
    ) throws -> ClaudeHarnessResult {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { throw ClaudeHarnessRunnerError.missingPrompt }
        guard trimmedPrompt.count <= 20_000 else { throw ClaudeHarnessRunnerError.promptTooLong }
        guard allowedModels.contains(model) else { throw ClaudeHarnessRunnerError.unsupportedModel }
        if mode == .edit && !confirmEdits { throw ClaudeHarnessRunnerError.editsNotConfirmed }
        if mode == .edit && !editsEnabled() {
            throw ClaudeHarnessRunnerError.editsDisabled
        }

        let projectURL = try MCPProjectGuard.validate(
            projectPath,
            allowProtectedRepository: allowProtectedRepository
        )
        guard let backend = backendURL() else {
            throw ClaudeHarnessRunnerError.backendMissing
        }

        let tools = mode == .plan ? "Read,Glob,Grep" : "Read,Glob,Grep,Edit,Write"
        let permissionMode = mode == .plan ? "plan" : "acceptEdits"
        let scopedPrompt = """
        Work only inside this Git repository: \(projectURL.path)
        Do not access parent or sibling directories. Do not use network tools.
        \(mode == .plan ? "Do not edit files or execute shell commands." : "You may edit files, but do not execute shell commands.")

        Task:
        \(trimmedPrompt)
        """

        let result = try CommandRunner.run(
            executable: backend.path,
            arguments: [
                projectURL.path,
                "--bare",
                "--no-session-persistence",
                "--permission-mode", permissionMode,
                "--tools", tools,
                "--disallowedTools", "Read(../**),Read(~/.ssh/**),Read(~/.aws/**),Read(~/.config/**),Read(~/.codex/**),Read(~/.claude/**),Edit(../**),Edit(~/**)",
                "--max-turns", "20",
                "--model", model,
                "-p", scopedPrompt,
            ],
            environment: [
                "CLAUDE_GPT_MODEL": model,
                "CLAUDE_GPT_SMALL_MODEL": "gpt-5.6-luna",
            ]
        )
        guard result.status == 0 else {
            let detail = result.error.isEmpty ? result.output : result.error
            throw ClaudeHarnessRunnerError.executionFailed(String(detail.prefix(8_000)))
        }

        return ClaudeHarnessResult(
            mode: mode,
            model: model,
            projectPath: projectURL.path,
            output: String(result.output.prefix(50_000))
        )
    }

    static func backendURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        executableURL: URL = URL(fileURLWithPath: CommandLine.arguments[0])
    ) -> URL? {
        let installed = homeDirectory.appendingPathComponent(".local/bin/claude-gpt")
        let resources = executableURL.standardizedFileURL
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let bundled = resources.appendingPathComponent("backend/claude-gpt")
        return [installed, bundled].first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }

    static func editsEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment["CLAUDE_GPT_ENABLE_MCP_EDITS"] == "1"
    }
}
