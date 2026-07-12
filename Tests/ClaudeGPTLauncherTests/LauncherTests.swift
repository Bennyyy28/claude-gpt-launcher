import Foundation
import XCTest
@testable import ClaudeGPTLauncher
@testable import ClaudeGPTMCP

final class LauncherTests: XCTestCase {
    func testAppBackendPrefersInstalledHelperAndFallsBackToBundle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-gpt-backend-test-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let resources = root.appendingPathComponent("Resources")
        let installed = home.appendingPathComponent(".local/bin/claude-gpt")
        let bundled = resources.appendingPathComponent("backend/claude-gpt")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: bundled.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: bundled.path, contents: Data("#!/bin/zsh\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: bundled.path)

        XCTAssertEqual(TerminalLauncher.backendURL(homeDirectory: home, bundleResourceURL: resources), bundled)

        try FileManager.default.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: installed.path, contents: Data("#!/bin/zsh\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: installed.path)
        XCTAssertEqual(TerminalLauncher.backendURL(homeDirectory: home, bundleResourceURL: resources), installed)
    }

    func testMcpBackendFallsBackToBundledHelper() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-gpt-mcp-backend-test-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let executable = root.appendingPathComponent("Resources/mcp-bin/claude-gpt-mcp")
        let bundled = root.appendingPathComponent("Resources/backend/claude-gpt")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: bundled.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: bundled.path, contents: Data("#!/bin/zsh\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: bundled.path)

        XCTAssertEqual(ClaudeHarnessRunner.backendURL(homeDirectory: home, executableURL: executable), bundled)
    }

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
