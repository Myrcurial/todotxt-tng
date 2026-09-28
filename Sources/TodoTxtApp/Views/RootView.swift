import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let store = model.store {
            NavigationSplitView {
                SidebarView()
            } detail: {
                TaskListView()
            }
            .navigationSubtitle(store.url.lastPathComponent)
        } else {
            WelcomeView()
        }
    }
}

struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("todotxt-tng").font(.largeTitle.weight(.semibold))
            Text("Your tasks, in a plain todo.txt file.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Open todo.txt…") { model.showOpenPanel() }
                    .keyboardShortcut(.defaultAction)
                Button("New todo.txt…") { model.showNewPanel() }
            }
            .controlSize(.large)
            if let e = model.errorMessage {
                Text(e).foregroundStyle(.red).font(.callout)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
