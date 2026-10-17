import Foundation
import CoreGraphics

public enum DockEdge: String, Codable, Sendable {
    case left, right
}

/// Una estantería: lo que el usuario ha ido soltando en una misma ventana.
public struct Shelf: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var items: [ShelfItem]
    public var customName: String?
    public var isFavorite: Bool
    public var createdAt: Date
    /// Posición de la ventana (esquina inferior izquierda, coordenadas de pantalla).
    public var origin: CGPoint?
    public var dock: DockEdge?

    public init(id: UUID = UUID(), items: [ShelfItem] = [], customName: String? = nil, isFavorite: Bool = false,
                createdAt: Date = Date(), origin: CGPoint? = nil, dock: DockEdge? = nil) {
        self.id = id
        self.items = items
        self.customName = customName
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.origin = origin
        self.dock = dock
    }

    public var name: String { customName ?? ShelfNaming.automaticName(for: items) }
}
