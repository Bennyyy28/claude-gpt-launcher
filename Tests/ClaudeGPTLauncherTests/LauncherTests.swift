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
