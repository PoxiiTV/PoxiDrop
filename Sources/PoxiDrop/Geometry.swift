import AppKit

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

enum ShelfGeometry {
    static let shelfSize = CGSize(width: 170, height: 170)
    static let compactSize = CGSize(width: 54, height: 120)
    static let cornerRadius: CGFloat = 20

    /// Origen para que una ventana de `size` quede centrada en `point` sin salirse de su pantalla.
    static func origin(centeredAt point: CGPoint, size: CGSize) -> CGPoint {
        var origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            let area = screen.visibleFrame
            origin.x = min(max(origin.x, area.minX + 8), area.maxX - size.width - 8)
            origin.y = min(max(origin.y, area.minY + 8), area.maxY - size.height - 8)
        }
        return origin
    }
}

enum DetailGeometry {
    static let width: CGFloat = 340

    /// Tamaño del panel de detalle (cabe «Mostrar en el Finder» además de los elementos).
    static func size(itemCount: Int, layout: DetailLayout) -> CGSize {
        switch layout {
        case .grid:
            let rows = min(3, (itemCount + 1 + 2) / 3)
            return CGSize(width: width, height: 56 + CGFloat(rows) * 112)
        case .list:
            let rows = min(8, itemCount + 1)
            return CGSize(width: width, height: 56 + CGFloat(rows) * 34)
        }
    }
}

/// La muesca de los MacBook.
enum NotchZone {
    static var hasNotch: Bool {
        NSScreen.screens.contains { rect(for: $0) != nil }
    }

    /// Zona de la muesca en coordenadas de pantalla, algo más ancha para que sea fácil de alcanzar.
    static func rect(for screen: NSScreen) -> CGRect? {
        let top = screen.safeAreaInsets.top
        guard top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
        let width = screen.frame.width - left.width - right.width
        guard width > 0 else { return nil }
        return CGRect(x: screen.frame.minX + left.width, y: screen.frame.maxY - top, width: width, height: top + 1)
            .insetBy(dx: -12, dy: 0)
    }

    static func contains(_ point: CGPoint) -> Bool {
        NSScreen.screens.contains { rect(for: $0)?.contains(point) == true }
    }
}
