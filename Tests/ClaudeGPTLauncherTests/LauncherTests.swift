import Foundation
import Testing
@testable import ClaudeGPTLauncher
@testable import ClaudeGPTMCP

@Test func modelIdentifiersRemainExplicit() {
    #expect(ModelOption.sol.rawValue == "gpt-5.6-sol")
    #expect(ModelOption.terra.rawValue == "gpt-5.6-terra")
    #expect(ModelOption.luna.smallModel == "gpt-5.6-luna")
}

@Test func shellQuotingHandlesSpacesAndApostrophes() {
    #expect(TerminalLauncher.shellQuote("/tmp/My Project") == "'/tmp/My Project'")
    #expect(TerminalLauncher.shellQuote("Developer's App") == "'Developer'\\''s App'")
}

@Test func configuredProtectedRemotesAreDetected() {
    let patterns = ["example/private-app", "company/production"]
    #expect(MCPProjectGuard.isProtectedRemote("https://github.com/example/private-app.git", patterns: patterns))
    #expect(!MCPProjectGuard.isProtectedRemote("https://github.com/example/public-app.git", patterns: patterns))
}

@Test func repositoryPathMustRemainInsideHomeBoundary() {
    #expect(MCPProjectGuard.isPath("/Users/example/project", inside: "/Users/example"))
    #expect(!MCPProjectGuard.isPath("/Users/example-escape/project", inside: "/Users/example"))
    #expect(!MCPProjectGuard.isPath("/private/etc", inside: "/Users/example"))
}

@Test func symlinkCannotEscapeHomeBoundary() throws {
    let fileManager = FileManager.default
    let link = fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/claude-gpt-test-\(UUID().uuidString)")
    try fileManager.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/private/tmp"))
    defer { try? fileManager.removeItem(at: link) }

    #expect(throws: MCPProjectGuardError.self) {
        _ = try MCPProjectGuard.validate(link.path)
    }
}

@Test func mcpEditsRequireInstallTimeOptIn() {
    #expect(!ClaudeHarnessRunner.editsEnabled(environment: [:]))
    #expect(ClaudeHarnessRunner.editsEnabled(environment: ["CLAUDE_GPT_ENABLE_MCP_EDITS": "1"]))
}
