import Foundation

@MainActor
final class LauncherStore: ObservableObject {
    @Published var project: ProjectInfo?
    @Published var selectedModel: ModelOption
    @Published var isInspecting = false
    @Published var errorMessage: String?
    @Published var launchMessage: String?

    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedModel")
        selectedModel = ModelOption(rawValue: saved ?? "") ?? .sol
    }

    var backendReady: Bool {
        FileManager.default.isExecutableFile(atPath: TerminalLauncher.backendURL.path)
    }

    func chooseProject(_ url: URL) {
        isInspecting = true
        errorMessage = nil
        launchMessage = nil

        Task {
            do {
                let inspected = try await Task.detached {
                    try ProjectInspector.inspect(url)
                }.value
                project = inspected
            } catch {
                project = nil
                errorMessage = error.localizedDescription
            }
            isInspecting = false
        }
    }

    func setModel(_ model: ModelOption) {
        selectedModel = model
        UserDefaults.standard.set(model.rawValue, forKey: "selectedModel")
    }

    func launch() {
        guard let project else { return }
        errorMessage = nil
        launchMessage = nil

        do {
            try TerminalLauncher.launch(project: project, model: selectedModel)
            launchMessage = "Opened \(project.name) in Claude Code with \(selectedModel.title)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
