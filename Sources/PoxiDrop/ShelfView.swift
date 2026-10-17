import SwiftUI
import PoxiDropCore

/// Lo que las vistas piden a su controlador.
struct ShelfCommands {
    var close: (_ clearing: Bool) -> Void
    var showMenu: () -> Void
    var toggleDetail: () -> Void
    var open: ([ShelfItem]) -> Void
    var reveal: ([ShelfItem]) -> Void
    var dragOperation: () -> NSDragOperation
    var dragEnded: ([ShelfItem], NSDragOperation) -> Void
    var itemMenu: (ShelfItem) -> NSMenu?
}

struct ShelfView: View {
    @ObservedObject var model: ShelfModel
    @ObservedObject var thumbnails = Thumbnails.shared
    let commands: ShelfCommands

    var body: some View {
        ZStack {
            WindowDragArea()
            if model.compact { compactBody } else { fullBody }
            if let toast = model.toast {
                ToastView(toast: toast).transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: ShelfGeometry.cornerRadius)
                .strokeBorder(Color.accentColor, lineWidth: model.isActive || model.isDropTarget ? 3 : 0)
        )
        .animation(.easeOut(duration: 0.15), value: model.isDropTarget)
    }

    private var size: CGSize { model.compact ? ShelfGeometry.compactSize : ShelfGeometry.shelfSize }

    private var fullBody: some View {
        VStack(spacing: 0) {
            HStack {
                CircleButton(symbol: "xmark", help: "Cerrar (con ⌥ además la vacía)") {
                    commands.close(NSEvent.modifierFlags.contains(.option))
                }
                Spacer()
                if model.busy {
                    ProgressView().controlSize(.small).padding(.trailing, 4)
                }
                CircleButton(symbol: "ellipsis", help: "Acciones", action: commands.showMenu)
            }
            .padding([.top, .horizontal], 9)
            Spacer(minLength: 0)
            if model.shelf.items.isEmpty {
                EmptyShelfHint()
            } else {
                StackPreview(items: model.shelf.items, thumbnails: thumbnails)
                    .overlay(
                        DragSource(items: { model.shelf.items },
                                   operation: commands.dragOperation,
                                   onClick: { count, _ in count >= 2 ? commands.open(model.shelf.items) : commands.toggleDetail() },
                                   onDragEnded: commands.dragEnded)
                    )
            }
            Spacer(minLength: 0)
            if !model.shelf.items.isEmpty {
                CountPill(text: ShelfNaming.countLabel(for: model.shelf.items), open: model.showingDetail, action: commands.toggleDetail)
                    .padding(.bottom, 10)
            }
        }
    }

    private var compactBody: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text("\(model.shelf.items.count)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            DragSource(items: { model.shelf.items }, operation: commands.dragOperation,
                       onClick: { _, _ in }, onDragEnded: commands.dragEnded)
        )
    }
}

struct CircleButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @StateObject private var hovering = ViewState(false)

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.black.opacity(hovering.value ? 0.6 : 0.42)))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering.value = $0 }
    }
}

/// Miniatura de un elemento: las imágenes con borde blanco, como una foto; el resto, su icono.
struct Thumb: View {
    let item: ShelfItem
    let image: NSImage
    let size: CGFloat

    var body: some View {
        Group {
            if item.kind == .image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: size, maxHeight: size)
                    .padding(3)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            } else {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
        }
        .opacity(item.exists ? 1 : 0.4)
    }
}

struct StackPreview: View {
    let items: [ShelfItem]
    @ObservedObject var thumbnails: Thumbnails

    var body: some View {
        let shown = Array(items.prefix(3).enumerated())
        ZStack {
            ForEach(shown.reversed(), id: \.element.id) { index, item in
                Thumb(item: item, image: thumbnails.image(for: item.url), size: 74)
                    .offset(x: CGFloat(index) * -6, y: CGFloat(index) * -6)
                    .rotationEffect(.degrees(Double(index) * -3))
            }
        }
        .frame(width: 112, height: 98)
    }
}

struct CountPill: View {
    let text: String
    let open: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(text).font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 11))
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .foregroundStyle(Color.primary.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyShelfHint: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 22, weight: .medium))
            Text("Suelta aquí")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .frame(width: 120, height: 92)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }
}

struct ToastView: View {
    let toast: ShelfModel.Toast

    var body: some View {
        VStack {
            Spacer()
            Text(toast.text)
                .font(.system(size: 11, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(toast.isError ? Color.red.opacity(0.88) : Color.black.opacity(0.72)))
                .padding(8)
        }
    }
}
