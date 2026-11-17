import Foundation

final class ControlSettler {
    private let later: (@escaping () -> Void) -> Void
    private var generation = 0
    private var pending = false

    init(later: @escaping (@escaping () -> Void) -> Void = { work in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }) {
        self.later = later
    }

    func cancel() { generation += 1; pending = false }

    func recheck(_ refresh: @escaping () -> Void) {
        guard !pending else { return }
        pending = true
        let token = generation
        later { [weak self] in
            guard let self, self.generation == token else { return }
            self.pending = false
            refresh()
        }
    }
}
