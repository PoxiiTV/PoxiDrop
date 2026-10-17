import AppKit
import SwiftUI
import PoxiDropCore

/// Zona de la que se pueden sacar archivos arrastrando. También recibe clics y clic secundario.
struct DragSource: NSViewRepresentable {
    var items: () -> [ShelfItem]
    var operation: () -> NSDragOperation
    var onClick: (_ clickCount: Int, _ modifiers: NSEvent.ModifierFlags) -> Void
    var onDragEnded: (_ items: [ShelfItem], _ operation: NSDragOperation) -> Void
    var menu: (() -> NSMenu?)? = nil

    func makeNSView(context: Context) -> DragSourceView { DragSourceView() }

    func updateNSView(_ view: DragSourceView, context: Context) {
        view.items = items
        view.operation = operation
        view.onClick = onClick
        view.onDragEnded = onDragEnded
        view.menuProvider = menu
    }
}

final class DragSourceView: NSView, NSDraggingSource {
    var items: () -> [ShelfItem] = { [] }
    var operation: () -> NSDragOperation = { .copy }
    var onClick: (Int, NSEvent.ModifierFlags) -> Void = { _, _ in }
    var onDragEnded: ([ShelfItem], NSDragOperation) -> Void = { _, _ in }
    var menuProvider: (() -> NSMenu?)?

    private var mouseDownEvent: NSEvent?
    private var draggedItems: [ShelfItem] = []

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownEvent else { return }
        let distance = hypot(event.locationInWindow.x - start.locationInWindow.x, event.locationInWindow.y - start.locationInWindow.y)
        guard distance > 3 else { return }
        mouseDownEvent = nil
        let list = items().filter(\.exists)
        guard !list.isEmpty else { return }
        draggedItems = list
        let point = convert(event.locationInWindow, from: nil)
        let draggingItems = list.enumerated().map { index, item -> NSDraggingItem in
            let draggingItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            let image = Thumbnails.shared.cached(item.url) ?? NSWorkspace.shared.icon(forFile: item.url.path)
            let offset = CGFloat(min(index, 4)) * 4
            draggingItem.setDraggingFrame(NSRect(x: point.x - 32 + offset, y: point.y - 32 - offset, width: 64, height: 64), contents: image)
            return draggingItem
        }
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }

    override func mouseUp(with event: NSEvent) {
        if mouseDownEvent != nil { onClick(event.clickCount, event.modifierFlags) }
        mouseDownEvent = nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuProvider?()
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .copy : operation()
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onDragEnded(draggedItems, operation)
        draggedItems = []
    }
}

/// Fondo que mueve la ventana al arrastrarlo.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowDragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WindowDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
