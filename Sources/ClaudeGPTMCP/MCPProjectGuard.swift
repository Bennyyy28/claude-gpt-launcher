import Foundation

enum MCPProjectGuardError: LocalizedError {
    case outsideHome
    case notGitRepository
    case protectedRepository
    case gitFailure(String)

    var errorDescription: String? {
        switch self {
        case .outsideHome:
            "The project must be inside your home directory."
        case .notGitRepository:
            "The project must be a Git working tree."
        case .protectedRepository:
            "This repository matches CLAUDE_GPT_PROTECTED_REMOTES and requires explicit opt-in."
        case .gitFailure(let detail):
            "Git validation failed: \(detail)"
        }
    }
}

enum MCPProjectGuard {
    static func validate(_ requestedPath: String, allowProtectedRepository: Bool = false) throws -> URL {
        let selectedURL = URL(fileURLWithPath: requestedPath).standardizedFileURL
        let homeURL = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let selectedPath = selectedURL.path
        let homePrefix = homeURL.path.hasSuffix("/") ? homeURL.path : homeURL.path + "/"

        guard selectedPath == homeURL.path || selectedPath.hasPrefix(homePrefix) else {
            throw MCPProjectGuardError.outsideHome
        }

        let rootResult = try runGit(["-C", selectedPath, "rev-parse", "--show-toplevel"])
        guard rootResult.status == 0 else {
            if rootResult.error.contains("not a git repository") {
                throw MCPProjectGuardError.notGitRepository
            }
            throw MCPProjectGuardError.gitFailure(rootResult.error)
        }

        let rootURL = URL(
            fileURLWithPath: rootResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        ).standardizedFileURL
        let remote = try runGit(["-C", rootURL.path, "remote", "get-url", "origin"])
        let protectedPatterns = ProcessInfo.processInfo.environment["CLAUDE_GPT_PROTECTED_REMOTES"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty } ?? []
        if remote.status == 0,
           isProtectedRemote(remote.output, patterns: protectedPatterns),
           !allowProtectedRepository {
            throw MCPProjectGuardError.protectedRepository
        }

        return rootURL
    }

    static func isProtectedRemote(_ remote: String, patterns: [String]) -> Bool {
        let normalized = remote.lowercased()
        return patterns.contains { normalized.contains($0.lowercased()) }
    }

    private static func runGit(_ arguments: [String]) throws -> CommandResult {
        try CommandRunner.run(executable: "/usr/bin/git", arguments: arguments, timeout: 15)
    }
}
