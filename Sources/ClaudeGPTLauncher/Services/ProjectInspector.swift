import Foundation

enum ProjectInspectionError: LocalizedError {
    case notDirectory
    case notGitRepository
    case gitFailure(String)

    var errorDescription: String? {
        switch self {
        case .notDirectory:
            "Choose a project folder."
        case .notGitRepository:
            "Choose a Git working tree so changes remain reviewable."
        case .gitFailure(let detail):
            "Git could not inspect this project: \(detail)"
        }
    }
}

enum ProjectInspector {
    static func inspect(_ selectedURL: URL) throws -> ProjectInfo {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: selectedURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ProjectInspectionError.notDirectory
        }

        let root = try git(["-C", selectedURL.path, "rev-parse", "--show-toplevel"])
        guard !root.isEmpty else { throw ProjectInspectionError.notGitRepository }

        let rootURL = URL(fileURLWithPath: root).standardizedFileURL
        let branchOutput = try git(["-C", rootURL.path, "branch", "--show-current"])
        let revision = branchOutput.isEmpty
            ? try git(["-C", rootURL.path, "rev-parse", "--short", "HEAD"])
            : branchOutput
        let status = try git(["-C", rootURL.path, "status", "--porcelain"])
        let changedFiles = status.split(separator: "\n").count

        return ProjectInfo(rootURL: rootURL, branch: revision, changedFileCount: changedFiles)
    }

    private static func git(_ arguments: [String]) throws -> String {
        let result = try Shell.run("/usr/bin/git", arguments)
        guard result.status == 0 else {
            let detail = result.error.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.contains("not a git repository") {
                throw ProjectInspectionError.notGitRepository
            }
            throw ProjectInspectionError.gitFailure(detail)
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
