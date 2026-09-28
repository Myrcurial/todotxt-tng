import AppKit
import SwiftUI
import TodoTxtCore

/// Settings window (⌘,).
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                LabeledContent("File") {
                    Text(model.store?.url.path(percentEncoded: false) ?? "No file open")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                LabeledContent("Standard format") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Button("Rewrite in Standard Format…") { confirmRewrite() }
                            .disabled(!needsRewrite)
                        Text(summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("""
                    Normally only lines you edit are rewritten. This rewrites every line in the \
                    todo.txt spec's order with single spaces, removes blank lines, and uses LF line \
                    endings with no BOM. A priority on a completed task becomes pri:.
                    """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A standard modal alert. More reliable than confirmationDialog inside a
    /// Settings form, and visible to VoiceOver and AppleScript.
    private func confirmRewrite() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Rewrite the whole file?"
        alert.informativeText = "\(summary). Other todo.txt tools will still read it, but this can't be undone from the app."
        alert.addButton(withTitle: "Rewrite \(model.store?.url.lastPathComponent ?? "File")")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            model.rewriteInStandardFormat()
        }
    }

    private var changes: (lines: Int, fileFormat: Bool) {
        model.store?.file.normalizationChanges ?? (0, false)
    }

    private var needsRewrite: Bool { changes.lines > 0 || changes.fileFormat }

    private var summary: String {
        guard model.store != nil else { return "Open a file first" }
        guard needsRewrite else { return "Already in standard format" }
        let n = changes.lines
        let lines = n == 0 ? "" : "\(n) line\(n == 1 ? "" : "s") will change"
        let format = changes.fileFormat ? "line endings/encoding will be standardized" : ""
        return [lines, format].filter { !$0.isEmpty }.joined(separator: "; ")
    }
}
