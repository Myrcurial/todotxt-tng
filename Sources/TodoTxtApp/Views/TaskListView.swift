import SwiftUI
import TodoTxtCore

struct TaskListView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Set<TodoTask.ID> = []

    var body: some View {
        @Bindable var model = model
        let tasks = model.visibleTasks()
        VStack(spacing: 0) {
            QuickAddField()
            Divider()
            if let e = model.errorMessage {
                Label(e, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
            }
            if tasks.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: (model.selection ?? .all).symbol)
                    .frame(maxHeight: .infinity)
            } else {
                List(tasks, selection: $selected) { task in
                    TaskRow(task: task, today: model.store?.today ?? .today())
                        .contextMenu { menu(for: task) }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle((model.selection ?? .all).title)
        .searchable(text: $model.search, placement: .toolbar)
        .onDeleteCommand { selected.forEach(model.delete); selected = [] }
    }

    private var emptyTitle: String {
        model.search.isEmpty ? "Nothing here" : "No matches for “\(model.search)”"
    }

    @ViewBuilder private func menu(for task: TodoTask) -> some View {
        Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") { model.toggle(task.id) }
        if !task.isCompleted {
            Menu("Priority") {
                ForEach(["A", "B", "C", "D"], id: \.self) { l in
                    Button(l) { model.setPriority(task.id, Priority(l)) }
                }
                Divider()
                Button("None") { model.setPriority(task.id, nil) }
            }
        }
        if let url = task.sourceURL {
            Button("Open Source Link") { NSWorkspace.shared.open(url) }
        }
        Button("Copy Line") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(task.line, forType: .string)
        }
        Divider()
        Button("Delete", role: .destructive) { model.delete(task.id) }
    }
}
