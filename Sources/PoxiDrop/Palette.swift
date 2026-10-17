import SwiftUI
import PoxiDropCore

struct PaletteEntry: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let run: () -> Void
}

@MainActor
final class PaletteModel: ObservableObject {
    @Published var query = "" { didSet { highlighted = 0 } }
    @Published var highlighted = 0
    let entries: [PaletteEntry]

    init(entries: [PaletteEntry]) {
        self.entries = entries
    }

    var results: [PaletteEntry] {
        let needle = ActionRegistry.normalized(query)
        guard !needle.isEmpty else { return entries }
        return entries.filter { ActionRegistry.normalized($0.title).contains(needle) }
    }

    func move(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        highlighted = min(max(highlighted + delta, 0), count - 1)
    }
}

/// Buscador de acciones: escribe y pulsa Intro.
struct PaletteView: View {
    @ObservedObject var model: PaletteModel
    let close: () -> Void
    @FocusState private var focused: Bool

    init(model: PaletteModel, close: @escaping () -> Void) {
        self.model = model
        self.close = close
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar acción", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($focused)
                    .onSubmit(runHighlighted)
                    .onKeyPress(.downArrow) { model.move(1); return .handled }
                    .onKeyPress(.upArrow) { model.move(-1); return .handled }
                    .onExitCommand(perform: close)
                if !model.query.isEmpty {
                    Button { model.query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.08)))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, entry in
                            Button {
                                entry.run()
                                close()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: entry.symbol).frame(width: 18)
                                    Text(entry.title).lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .frame(height: 30)
                                .foregroundStyle(index == model.highlighted ? Color.white : Color.primary)
                                .background(RoundedRectangle(cornerRadius: 7).fill(index == model.highlighted ? Color.accentColor : Color.clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                        if model.results.isEmpty {
                            Text("No hay acciones con ese nombre").foregroundStyle(.secondary).padding(.top, 20)
                        }
                    }
                }
                .onChange(of: model.highlighted) { _, index in proxy.scrollTo(index) }
            }
        }
        .padding(10)
        .frame(width: 300, height: 320)
        .onAppear { focused = true }
    }

    private func runHighlighted() {
        let results = model.results
        guard results.indices.contains(model.highlighted) else { return }
        results[model.highlighted].run()
        close()
    }
}
