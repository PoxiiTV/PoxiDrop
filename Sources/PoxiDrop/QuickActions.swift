import AppKit
import SwiftUI

enum QuickAction: CaseIterable {
    case airDrop, messages, mail, zip

    var title: String {
        switch self {
        case .airDrop: return "AirDrop"
        case .messages: return "Mensajes"
        case .mail: return "Mail"
        case .zip: return "ZIP"
        }
    }

    var symbol: String {
        switch self {
        case .airDrop: return "dot.radiowaves.left.and.right"
        case .messages: return "message.fill"
        case .mail: return "envelope.fill"
        case .zip: return "doc.zipper"
        }
    }

    var color: Color {
        switch self {
        case .airDrop: return .blue
        case .messages: return .green
        case .mail: return .cyan
        case .zip: return .orange
        }
    }

    var service: NSSharingService.Name? {
        switch self {
        case .airDrop: return .sendViaAirDrop
        case .messages: return .composeMessage
        case .mail: return .composeEmail
        case .zip: return nil
        }
    }
}

@MainActor
final class QuickActionsModel: ObservableObject {
    @Published var hovered: QuickAction?
}

struct QuickActionsView: View {
    @ObservedObject var model: QuickActionsModel

    var body: some View {
        VStack(spacing: 8) {
            Text(model.hovered?.title ?? "Acciones directas")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 22)
                .background(Capsule().fill(model.hovered == nil ? Color.black.opacity(0.55) : Color.accentColor))
            LazyVGrid(columns: [GridItem(.fixed(89), spacing: 6), GridItem(.fixed(89), spacing: 6)], spacing: 6) {
                ForEach(QuickAction.allCases, id: \.self) { action in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(model.hovered == action ? Color.accentColor : Color(white: 0.24))
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: action.symbol)
                                    .font(.system(size: 26))
                                    .foregroundStyle(model.hovered == action ? Color.white : action.color)
                                Text(action.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        )
                        .frame(width: 89, height: 89)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.13).opacity(0.94)))
        }
        .frame(width: 196, height: 226, alignment: .top)
    }
}

/// Vista que recibe lo que se suelta sobre las casillas.
final class QuickActionsDropView: NSView {
    var model: QuickActionsModel?
    var onDrop: ((QuickAction, [URL]) -> Void)?
    var onEnterExit: ((Bool) -> Void)?

    init(frame: CGRect, content: NSView) {
        super.init(frame: frame)
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    /// Casilla bajo un punto (coordenadas de esta vista, origen abajo a la izquierda).
    func action(at point: CGPoint) -> QuickAction? {
        guard point.y < 196, point.x > 6, point.x < 190, point.y > 6, point.y < 190 else { return nil }
        let column = point.x < 98 ? 0 : 1
        let row = point.y >= 98 ? 0 : 1
        return QuickAction.allCases[row * 2 + column]
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onEnterExit?(true)
        return draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let action = action(at: convert(sender.draggingLocation, from: nil))
        model?.hovered = action
        return action == nil ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        model?.hovered = nil
        onEnterExit?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let action = action(at: convert(sender.draggingLocation, from: nil)),
              let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty else { return false }
        onDrop?(action, urls)
        return true
    }
}

/// Las casillas de «acciones directas» que salen bajo la estantería cuando arrastras encima.
@MainActor
final class QuickActionsController {
    static let size = CGSize(width: 196, height: 226)

    let model = QuickActionsModel()
    var perform: ((QuickAction, [URL]) -> Void)?
    private let panel = ShelfPanel(size: QuickActionsController.size)
    private var hideTask: Task<Void, Never>?

    var contentView: NSView? { panel.contentView }

    init() {
        let hosting = NSHostingView(rootView: QuickActionsView(model: model))
        hosting.frame = CGRect(origin: .zero, size: Self.size)
        let dropView = QuickActionsDropView(frame: hosting.frame, content: hosting)
        dropView.model = model
        dropView.onDrop = { [weak self] action, urls in
            self?.hide()
            self?.perform?(action, urls)
        }
        dropView.onEnterExit = { [weak self] inside in
            if inside { self?.cancelHide() } else { self?.scheduleHide() }
        }
        panel.contentView = dropView
        panel.hasShadow = false
    }

    func show(below frame: CGRect) {
        cancelHide()
        panel.setFrameOrigin(CGPoint(x: frame.midX - Self.size.width / 2, y: frame.minY - Self.size.height - 6))
        panel.orderFrontRegardless()
    }

    func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func cancelHide() {
        hideTask?.cancel()
    }

    func hide() {
        hideTask?.cancel()
        model.hovered = nil
        panel.orderOut(nil)
    }
}
