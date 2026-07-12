import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: LauncherStore
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            projectSection
            modelSection
            statusSection
            Spacer(minLength: 0)
            launchBar
        }
        .padding(28)
        .background(.regularMaterial)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("Claude GPT")
                    .font(.largeTitle.bold())
                Text("The Claude Code interface, backed by your selected GPT model.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(store.backendReady ? "Backend ready" : "Backend missing",
                  systemImage: store.backendReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(store.backendReady ? .green : .orange)
        }
    }

    private var projectSection: some View {
        GroupBox("Project") {
            VStack(alignment: .leading, spacing: 14) {
                if let project = store.project {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.name).font(.headline)
                            Text(project.rootURL.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(project.branch).font(.callout.monospaced())
                            Text(project.hasChanges
                                 ? "\(project.changedFileCount) changed file\(project.changedFileCount == 1 ? "" : "s")"
                                 : "Working tree clean")
                                .font(.caption)
                                .foregroundStyle(project.hasChanges ? .orange : .secondary)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "folder.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(isDropTargeted ? "Drop project folder" : "Choose or drop a Git project folder")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                }

                Divider()

                Button("Choose Project…", systemImage: "folder") {
                    chooseProject()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            .padding(8)
        }
    }

    private var modelSection: some View {
        GroupBox("Model") {
            HStack(spacing: 10) {
                ForEach(ModelOption.allCases) { model in
                    Button {
                        store.setModel(model)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(model.title).font(.headline)
                                Spacer()
                                if store.selectedModel == model {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                            Text(model.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .background(store.selectedModel == model ? Color.accentColor.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(store.selectedModel == model ? Color.accentColor : Color.secondary.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let error = store.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else if let message = store.launchMessage {
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Label("The proxy runs on localhost and stops when the Terminal session exits.",
                  systemImage: "lock.shield")
                .foregroundStyle(.secondary)
        }
    }

    private var launchBar: some View {
        HStack {
            Text("Claude Code opens in Terminal with normal project behavior.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Open Claude GPT", systemImage: "play.fill") {
                store.launch()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(store.project == nil || !store.backendReady || store.isInspecting)
        }
    }

    private func chooseProject() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Git project"
        panel.prompt = "Choose Project"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            store.chooseProject(url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in store.chooseProject(url) }
        }
        return true
    }
}
