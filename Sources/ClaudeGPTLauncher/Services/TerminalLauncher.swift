import Foundation

enum TerminalLauncherError: LocalizedError {
    case missingBackend
    case couldNotWriteCommand(String)
    case couldNotOpenTerminal(String)

    var errorDescription: String? {
        switch self {
        case .missingBackend:
            "The claude-gpt backend launcher is missing from ~/.local/bin."
        case .couldNotWriteCommand(let detail):
            "Could not prepare the Terminal session: \(detail)"
        case .couldNotOpenTerminal(let detail):
            "Could not open Terminal: \(detail)"
        }
    }
}

enum TerminalLauncher {
    static var backendURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/claude-gpt")
    }

    static func launch(project: ProjectInfo, model: ModelOption) throws {
        guard FileManager.default.isExecutableFile(atPath: backendURL.path) else {
            throw TerminalLauncherError.missingBackend
        }

        let cacheRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/app.claudegpt.launcher", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: cacheRoot,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw TerminalLauncherError.couldNotWriteCommand(error.localizedDescription)
        }

        let commandURL = cacheRoot
            .appendingPathComponent("launch-\(UUID().uuidString)")
            .appendingPathExtension("command")
        let command = """
        #!/bin/zsh
        command_file=\(shellQuote(commandURL.path))
        trap 'rm -f -- "$command_file"' EXIT
        export CLAUDE_GPT_MODEL=\(shellQuote(model.rawValue))
        export CLAUDE_GPT_SMALL_MODEL=\(shellQuote(model.smallModel))
        exec \(shellQuote(backendURL.path)) \(shellQuote(project.rootURL.path))
        """

        do {
            try command.write(to: commandURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: commandURL.path)
        } catch {
            throw TerminalLauncherError.couldNotWriteCommand(error.localizedDescription)
        }

        let result: ShellResult
        do {
            result = try Shell.run("/usr/bin/open", ["-a", "Terminal", commandURL.path])
        } catch {
            try? FileManager.default.removeItem(at: commandURL)
            throw TerminalLauncherError.couldNotOpenTerminal(error.localizedDescription)
        }

        guard result.status == 0 else {
            try? FileManager.default.removeItem(at: commandURL)
            throw TerminalLauncherError.couldNotOpenTerminal(result.error)
        }
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
