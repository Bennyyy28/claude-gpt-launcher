import XCTest
@testable import ClaudeGPTLauncher

final class SingleInstanceTests: XCTestCase {
    func testFirstApplicationInstanceContinuesLaunching() {
        XCTAssertTrue(SingleInstancePolicy.shouldContinueLaunching(
            currentProcessIdentifier: 100,
            runningProcessIdentifiers: [100]
        ))
    }

    func testLaterApplicationInstanceStopsLaunching() {
        XCTAssertFalse(SingleInstancePolicy.shouldContinueLaunching(
            currentProcessIdentifier: 200,
            runningProcessIdentifiers: [100, 200]
        ))
    }
}
