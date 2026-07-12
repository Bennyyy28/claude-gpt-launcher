import AppKit
import SwiftUI

enum SingleInstancePolicy {
    static func shouldContinueLaunching(
        currentProcessIdentifier: pid_t,
        runningProcessIdentifiers: [pid_t]
    ) -> Bool {
        !runningProcessIdentifiers.contains { $0 != currentProcessIdentifier }
    }
}

@main
struct ClaudeGPTLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LauncherStore()

    var body: some Scene {
        WindowGroup("Claude GPT", id: "launcher") {
            ContentView(store: store)
                .frame(minWidth: 680, minHeight: 520)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var isSecondaryLaunch = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningApplications = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )
        let activeApplications = runningApplications.filter { !$0.isTerminated }
        guard !SingleInstancePolicy.shouldContinueLaunching(
            currentProcessIdentifier: currentPID,
            runningProcessIdentifiers: activeApplications.map(\.processIdentifier)
        ), let existingApplication = activeApplications.first(where: {
            $0.processIdentifier != currentPID
        }) else {
            return
        }

        isSecondaryLaunch = true
        existingApplication.activate(options: [.activateAllWindows])
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isSecondaryLaunch else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
