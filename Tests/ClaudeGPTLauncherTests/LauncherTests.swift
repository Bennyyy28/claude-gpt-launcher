import Foundation
import XCTest
@testable import ClaudeGPTLauncher
@testable import ClaudeGPTMCP

final class LauncherTests: XCTestCase {
    func testModelIdentifiersRemainExplicit() {
        XCTAssertEqual(ModelOption.sol.rawValue, "gpt-5.6-sol")
        XCTAssertEqual(ModelOption.terra.rawValue, "gpt-5.6-terra")
        XCTAssertEqual(ModelOption.luna.smallModel, "gpt-5.6-luna")
    }

    func testShellQuotingHandlesSpacesAndApostrophes() {
        XCTAssertEqual(TerminalLauncher.shellQuote("/tmp/My Project"), "'/tmp/My Project'")
        XCTAssertEqual(TerminalLauncher.shellQuote("Developer's App"), "'Developer'\\''s App'")
    }

    func testConfiguredProtectedRemotesAreDetected() {
        let patterns = ["example/private-app", "company/production"]
        XCTAssertTrue(MCPProjectGuard.isProtectedRemote(
            "https://github.com/example/private-app.git",
            patterns: patterns
        ))
        XCTAssertFalse(MCPProjectGuard.isProtectedRemote(
            "https://github.com/example/public-app.git",
            patterns: patterns
        ))
    }

    func testRepositoryPathMustRemainInsideHomeBoundary() {
        XCTAssertTrue(MCPProjectGuard.isPath("/Users/example/project", inside: "/Users/example"))
        XCTAssertFalse(MCPProjectGuard.isPath("/Users/example-escape/project", inside: "/Users/example"))
        XCTAssertFalse(MCPProjectGuard.isPath("/private/etc", inside: "/Users/example"))
    }

    func testSymlinkCannotEscapeHomeBoundary() throws {
        let fileManager = FileManager.default
        let link = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/claude-gpt-test-\(UUID().uuidString)")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/private/tmp"))
        defer { try? fileManager.removeItem(at: link) }

        XCTAssertThrowsError(try MCPProjectGuard.validate(link.path)) { error in
            XCTAssertTrue(error is MCPProjectGuardError)
        }
    }

    func testMcpEditsRequireInstallTimeOptIn() {
        XCTAssertFalse(ClaudeHarnessRunner.editsEnabled(environment: [:]))
        XCTAssertTrue(ClaudeHarnessRunner.editsEnabled(
            environment: ["CLAUDE_GPT_ENABLE_MCP_EDITS": "1"]
        ))
    }
}
