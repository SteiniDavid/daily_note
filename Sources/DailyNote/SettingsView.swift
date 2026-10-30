import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: NoteStore
    @AppStorage("fontSize") private var fontSize = 15.0
    @AppStorage("monospaced") private var monospaced = false

    var body: some View {
        Form {
            LabeledContent("Notes folder") {
                HStack {
                    Text((store.folder.path as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Button("Change…", action: chooseFolder)
                }
            }

            Picker("Font", selection: $monospaced) {
                Text("System").tag(false)
                Text("Monospaced").tag(true)
            }

            LabeledContent("Size") {
                Stepper(value: $fontSize, in: 11...28, step: 1) {
                    Text("\(Int(fontSize)) pt").monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = store.folder
        panel.prompt = "Use Folder"
        if panel.runModal() == .OK, let url = panel.url {
            store.setFolder(url)
        }
    }
}
