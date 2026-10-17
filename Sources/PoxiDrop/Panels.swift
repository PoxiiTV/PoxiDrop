import AppKit

/// Ventana flotante sin bordes que no activa la app, visible en todos los escritorios.
final class ShelfPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onResignKey: (() -> Void)?

    init(size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true { super.keyDown(with: event) }
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

@MainActor
protocol ShelfDropTarget: AnyObject {
    func dropEntered(_ info: NSDraggingInfo) -> NSDragOperation
    func dropUpdated(_ info: NSDraggingInfo) -> NSDragOperation
    func dropExited()
    func performDrop(_ info: NSDraggingInfo) -> Bool
    func hoverChanged(_ inside: Bool)
}

/// Fondo de vidrio con esquinas redondeadas que además recibe lo que se suelta encima.
final class GlassView: NSVisualEffectView {
    weak var dropTarget: ShelfDropTarget?

    init(content: NSView, cornerRadius: CGFloat) {
        super.init(frame: content.frame)
        material = .popover
        blendingMode = .behindWindow
        state = .active
        maskImage = Self.mask(radius: cornerRadius)
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        registerForDraggedTypes(PasteboardReader.dropTypes)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { dropTarget?.hoverChanged(true) }
    override func mouseExited(with event: NSEvent) { dropTarget?.hoverChanged(false) }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { dropTarget?.dropEntered(sender) ?? [] }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { dropTarget?.dropUpdated(sender) ?? [] }
    override func draggingExited(_ sender: NSDraggingInfo?) { dropTarget?.dropExited() }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { dropTarget?.performDrop(sender) ?? false }

    static func mask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
