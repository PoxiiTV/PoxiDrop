import SwiftUI
import PoxiDropCore

/// Panel con todos los elementos: cuadrícula o lista, selección y arrastre individual.
struct DetailView: View {
    @ObservedObject var model: ShelfModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var thumbnails = Thumbnails.shared
    @ObservedObject var sizes = SizeCache.shared
    let commands: ShelfCommands

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(header)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Picker("Vista", selection: $settings.detailLayout) {
                    Image(systemName: "square.grid.2x2").tag(DetailLayout.grid)
                    Image(systemName: "list.bullet").tag(DetailLayout.list)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 72)
            }
            ScrollView {
                if settings.detailLayout == .grid { grid } else { list }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.selection = [] }
    }

    private var header: String {
        let items = model.selectedItems
        let label = ShelfNaming.countLabel(for: items)
        let size = sizes.total(for: items.filter(\.exists).map(\.url)).map(FileSizes.format)
        let prefix = model.selection.isEmpty ? "" : "Seleccionado: "
        return prefix + label + (size.map { " · \($0)" } ?? "")
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(98), spacing: 8), count: 3), spacing: 8) {
            ForEach(model.shelf.items) { item in
                ItemTile(item: item, image: thumbnails.image(for: item.url), size: sizes.size(for: item.url),
                         selected: model.selection.contains(item.id))
                    .overlay(dragSource(for: item))
            }
            RevealTile { commands.reveal(model.shelf.items) }
        }
    }

    private var list: some View {
        LazyVStack(spacing: 2) {
            ForEach(model.shelf.items) { item in
                ItemRow(item: item, image: thumbnails.image(for: item.url), size: sizes.size(for: item.url),
                        selected: model.selection.contains(item.id))
                    .overlay(dragSource(for: item))
            }
            Button { commands.reveal(model.shelf.items) } label: {
                Label("Mostrar en el Finder", systemImage: "arrowshape.turn.up.right.circle")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func dragSource(for item: ShelfItem) -> DragSource {
        DragSource(
            items: { model.selection.contains(item.id) ? model.selectedItems : [item] },
            operation: commands.dragOperation,
            onClick: { count, flags in click(item, count: count, flags: flags) },
            onDragEnded: commands.dragEnded,
            menu: { commands.itemMenu(item) }
        )
    }

    private func click(_ item: ShelfItem, count: Int, flags: NSEvent.ModifierFlags) {
        if count >= 2 {
            commands.open([item])
        } else if flags.contains(.command) {
            if model.selection.contains(item.id) { model.selection.remove(item.id) } else { model.selection.insert(item.id) }
        } else {
            model.selection = model.selection == [item.id] ? [] : [item.id]
        }
    }
}

struct ItemTile: View {
    let item: ShelfItem
    let image: NSImage
    let size: Int64?
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Thumb(item: item, image: image, size: 52).frame(height: 58)
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
            Text(item.exists ? (size.map(FileSizes.format) ?? " ") : "No encontrado")
                .font(.system(size: 10))
                .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary)
        }
        .foregroundStyle(selected ? Color.white : Color.primary)
        .padding(6)
        .frame(width: 98, height: 104)
        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor : Color.clear))
    }
}

struct ItemRow: View {
    let item: ShelfItem
    let image: NSImage
    let size: Int64?
    let selected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
            Text(item.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(item.exists ? (size.map(FileSizes.format) ?? "") : "No encontrado")
                .font(.system(size: 11))
                .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary)
        }
        .foregroundStyle(selected ? Color.white : Color.primary)
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.accentColor : Color.clear))
        .opacity(item.exists ? 1 : 0.6)
    }
}

struct RevealTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "arrowshape.turn.up.right.circle")
                    .font(.system(size: 36, weight: .light))
                Text("Mostrar en el Finder")
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 98, height: 104)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
