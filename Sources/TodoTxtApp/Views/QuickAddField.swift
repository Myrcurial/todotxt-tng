import SwiftUI

/// Type a todo.txt line and press Return: `(A) Call Mom +Family @phone due:2026-10-01`.
struct QuickAddField: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .font(.title3)
            TextField("Add a task — (A) Call Mom +Family @phone due:2026-10-01", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($focused)
                .onSubmit(submit)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear { focused = true }
    }

    private func submit() {
        var line = text
        // Add the current project or context so the new task shows up in this view.
        switch model.selection {
        case .project(let p) where !line.contains("+" + p): line += " +" + p
        case .context(let c) where !line.contains("@" + c): line += " @" + c
        default: break
        }
        model.add(line)
        text = ""
    }
}
