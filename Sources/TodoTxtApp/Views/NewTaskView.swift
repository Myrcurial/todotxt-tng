import SwiftUI
import TodoTxtCore

/// The New Task dialog (⌘N): every field, with dropdowns of values already in the file.
struct NewTaskView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    let vocabulary: TaskVocabulary

    @State var draft = TaskDraft()
    @State var priorityText = ""
    @State var hasCreated = true
    @State var created = Date()
    @State var hasDue = false
    @State var due = Date()
    @State var hasThreshold = false
    @State var threshold = Date()
    @State var tags: [EditableTag] = []

    struct EditableTag: Identifiable { let id = UUID(); var key = ""; var value = "" }

    init(vocabulary: TaskVocabulary, initial: SmartView?) {
        self.vocabulary = vocabulary
        var d = TaskDraft()
        switch initial {
        case .project(let p): d.projects = [p]
        case .context(let c): d.contexts = [c]
        default: break
        }
        _draft = State(initialValue: d)
        _hasDue = State(initialValue: initial == .today)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Description", text: $draft.text, prompt: Text("What needs doing?"))
                        .onSubmit { if draft.isValid { save() } }
                    LabeledContent("Priority") {
                        HStack {
                            Picker("Priority", selection: $priorityText) {
                                Text("None").tag("")
                                ForEach(priorityChoices, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .fixedSize()
                            Spacer()
                        }
                    }
                }
                Section("Dates") {
                    dateRow("Created", on: $hasCreated, date: $created)
                    dateRow("Due", on: $hasDue, date: $due)
                    dateRow("Hide until", on: $hasThreshold, date: $threshold)
                    LabeledContent("Repeats") {
                        ComboField(title: "Repeats", text: $draft.recurrence,
                                   options: Self.merge(vocabulary.recurrences, ["1d", "1w", "2w", "1m", "+1m", "1y", "1b"]),
                                   prompt: "e.g. 1w, +1m")
                    }
                }
                Section("Projects and contexts") {
                    LabeledContent("Projects") {
                        TokenListField(title: "Project", sigil: "+", values: $draft.projects, options: vocabulary.projects)
                    }
                    LabeledContent("Contexts") {
                        TokenListField(title: "Context", sigil: "@", values: $draft.contexts, options: vocabulary.contexts)
                    }
                }
                Section("Other tags") {
                    ForEach($tags) { $tag in
                        HStack {
                            ComboField(title: "Key", text: $tag.key, options: vocabulary.tagKeys, prompt: "key")
                            Text(":").foregroundStyle(.secondary)
                            ComboField(title: "Value", text: $tag.value,
                                       options: vocabulary.tagValues[tag.key] ?? [], prompt: "value")
                            Button { tags.removeAll { $0.id == tag.id } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove tag")
                        }
                    }
                    Button("Add Tag", systemImage: "plus") { tags.append(EditableTag()) }
                }
            }
            .formStyle(.grouped)
            Divider()
            footer
        }
        .frame(width: 560, height: 640)
        .onChange(of: fieldsSnapshot, initial: true) { sync() }
    }

    func dateRow(_ title: String, on: Binding<Bool>, date: Binding<Date>) -> some View {
        LabeledContent(title) {
            HStack {
                Toggle(title, isOn: on).labelsHidden()
                DatePicker(title, selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!on.wrappedValue)
                    .opacity(on.wrappedValue ? 1 : 0.4)
                Spacer()
            }
        }
    }

    var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.line.isEmpty ? " " : draft.line)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("preview")
            if let problem = draft.problems.first(where: { $0 != "Description is empty" }) {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Cancel")
                Button("Add Task") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(!draft.isValid)
                    .accessibilityLabel("Add Task")
                    .help("Add Task (⌘↩)")
            }
        }
        .padding(14)
    }
}
