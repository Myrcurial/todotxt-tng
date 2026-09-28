import SwiftUI
import TodoTxtCore

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let tasks = model.store?.file.tasks ?? []
        List(selection: $model.selection) {
            Section("Views") {
                row(.all)
                row(.priority)
            }
            Section("Due") {
                row(.overdue)
                row(.today)
                row(.upcoming)
                row(.noDate)
            }
            Section("Done") {
                row(.completed)
            }
            let projects = TaskSort.counts(tasks, \.projects)
            if !projects.isEmpty {
                Section("Projects") {
                    ForEach(projects, id: \.name) { row(.project($0.name), count: $0.count) }
                }
            }
            let contexts = TaskSort.counts(tasks, \.contexts)
            if !contexts.isEmpty {
                Section("Contexts") {
                    ForEach(contexts, id: \.name) { row(.context($0.name), count: $0.count) }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 210)
    }

    private func row(_ view: SmartView, count: Int? = nil) -> some View {
        let n = count ?? model.count(view)
        return Label(view.title, systemImage: view.symbol)
            .badge(n)
            .foregroundStyle(view == .overdue && n > 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            .tag(view)
    }
}
