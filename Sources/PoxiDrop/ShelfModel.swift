import Foundation
import PoxiDropCore

/// Estado de una estantería que dibujan sus vistas.
@MainActor
final class ShelfModel: ObservableObject {
    struct Toast: Equatable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    @Published var shelf: Shelf
    @Published var isActive = false
    @Published var isDropTarget = false
    @Published var busy = false
    @Published var toast: Toast?
    @Published var showingDetail = false
    @Published var selection: Set<UUID> = []
    @Published var compact = false

    init(shelf: Shelf) {
        self.shelf = shelf
    }

    /// Lo seleccionado, o todo si no hay selección.
    var selectedItems: [ShelfItem] {
        selection.isEmpty ? shelf.items : shelf.items.filter { selection.contains($0.id) }
    }

    func show(_ text: String, isError: Bool = false) {
        let toast = Toast(text: text, isError: isError)
        self.toast = toast
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: isError ? 5_000_000_000 : 2_500_000_000)
            if self?.toast == toast { self?.toast = nil }
        }
    }
}
