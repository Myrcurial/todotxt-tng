import Foundation

extension TodoStore {
    /// Adds a task built by `AddTaskCommand`. Returns the new task's id.
    @discardableResult
    public func add(_ command: AddTaskCommand) throws(StoreError) -> TodoTask.ID? {
        guard let task = command.makeTask(today: today) else { return nil }
        try transact { $0.append(task) }
        return task.id
    }

    public func toggleCompletion(_ id: TodoTask.ID) throws(StoreError) {
        let today = self.today
        try update(id) { t in
            if t.isCompleted { t.uncomplete() } else { t.complete(on: today) }
        }
    }

    public func update(_ id: TodoTask.ID, _ change: (inout TodoTask) -> Void) throws(StoreError) {
        try transact { f throws(StoreError) in
            guard let i = f.tasks.firstIndex(where: { $0.id == id }) else { throw .conflict }
            change(&f.tasks[i])
        }
    }

    public func delete(_ id: TodoTask.ID) throws(StoreError) {
        try transact { f throws(StoreError) in
            guard let i = f.tasks.firstIndex(where: { $0.id == id }) else { throw .conflict }
            f.tasks.remove(at: i)
        }
    }
}
