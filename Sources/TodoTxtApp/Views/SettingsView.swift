import SwiftUI
import TodoTxtCore

/// Settings window (⌘,).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirming = false

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
                        Button("Rewrite in Standard Format…") { confirming = true }
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
        .confirmationDialog("Rewrite the whole file?", isPresented: $confirming) {
            Button("Rewrite \(model.store?.url.lastPathComponent ?? "File")", role: .destructive) {
                model.rewriteInStandardFormat()
            }
        } message: {
            Text("\(summary). Other todo.txt tools will still read it, but this can't be undone from the app.")
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
