import SwiftUI
import ServiceManagement
import PoxiDropCore

enum SettingsSection: String, CaseIterable, Identifiable {
    case activation = "Activación"
    case interaction = "Interacción"
    case actions = "Acciones"
    case shortcuts = "Atajos"
    case general = "General"
    case about = "Acerca de"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .activation: return "cursorarrow.motionlines"
        case .interaction: return "slider.horizontal.3"
        case .actions: return "bolt.fill"
        case .shortcuts: return "command"
        case .general: return "gearshape.fill"
        case .about: return "info"
        }
    }

    var color: Color {
        switch self {
        case .activation: return .blue
        case .interaction: return .indigo
        case .actions: return .orange
        case .shortcuts: return .purple
        case .general: return .gray
        case .about: return .teal
        }
    }
}

@MainActor
final class SettingsViewState: ObservableObject {
    @Published var section: SettingsSection?
    @Published var loginError: String?
    @Published var refresh = false

    init(section: SettingsSection) {
        self.section = section
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ShelfStore
    @StateObject private var state: SettingsViewState

    init(settings: AppSettings, store: ShelfStore, section: SettingsSection = .activation) {
        self.settings = settings
        self.store = store
        _state = StateObject(wrappedValue: SettingsViewState(section: section))
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $state.section) { section in
                Label {
                    Text(section.rawValue)
                } icon: {
                    SettingsIcon(symbol: section.symbol, color: section.color)
                }
                .tag(section)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            Form { pane }
                .formStyle(.grouped)
                .navigationTitle((state.section ?? .activation).rawValue)
        }
        .frame(width: 680, height: 470)
    }

    @ViewBuilder private var pane: some View {
        switch state.section ?? .activation {
        case .activation: activation
        case .interaction: interaction
        case .actions: actions
        case .shortcuts: shortcuts
        case .general: general
        case .about: about
        }
    }

    @ViewBuilder private var activation: some View {
        Section {
            Toggle("Agitar el ratón mientras arrastras", isOn: $settings.shakeEnabled)
            Picker("Sensibilidad", selection: $settings.shakeSensitivity) {
                Text("Baja").tag(0)
                Text("Media").tag(1)
                Text("Alta").tag(2)
            }
            .disabled(!settings.shakeEnabled)
        } header: {
            Text("Agitar")
        } footer: {
            SettingsFooter("Arrastra algo y muévelo rápido de lado a lado: aparece una estantería para soltarlo.")
        }
        Section("Tecla") {
            Toggle("Abrir al mantener una tecla mientras arrastras", isOn: $settings.modifierEnabled)
            Picker("Tecla", selection: $settings.modifierKey) {
                ForEach(ModifierChoice.allCases) { Text($0.label).tag($0) }
            }
            .disabled(!settings.modifierEnabled)
        }
        Section {
            Toggle("Abrir al llevar lo que arrastras a la muesca", isOn: $settings.notchEnabled)
                .disabled(!NotchZone.hasNotch)
        } header: {
            Text("Muesca")
        } footer: {
            SettingsFooter(NotchZone.hasNotch ? "Solo en pantallas con muesca, como la de tu MacBook." : "Esta pantalla no tiene muesca.")
        }
        Section {
            Toggle("Acciones directas al arrastrar sobre una estantería", isOn: $settings.quickActionsEnabled)
        } footer: {
            SettingsFooter("Salen casillas de AirDrop, Mensajes, Mail y ZIP: suelta encima para hacerlo al momento.")
        }
    }

    @ViewBuilder private var interaction: some View {
        Section("Al sacar archivos de una estantería") {
            Picker("Al arrastrar fuera", selection: $settings.dragOutMode) {
                ForEach(DragOutMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Cerrar la estantería al sacar todo", isOn: $settings.closeWhenEmpty)
        }
        Section("Detalle") {
            Picker("Vista", selection: $settings.detailLayout) {
                Text("Cuadrícula").tag(DetailLayout.grid)
                Text("Lista").tag(DetailLayout.list)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder private var actions: some View {
        Section {
            if settings.customScripts.isEmpty {
                Text("Todavía no has añadido ningún script.").foregroundStyle(.secondary)
            }
            ForEach(settings.customScripts) { script in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(script.name)
                        Text(script.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        settings.customScripts.removeAll { $0.id == script.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button("Añadir script…", action: addScript)
        } header: {
            Text("Mis acciones")
        } footer: {
            SettingsFooter("Cada script recibe las rutas de los archivos como argumentos. Lo que guarde en la carpeta $POXIDROP_OUTPUT aparece en la estantería.")
        }
    }

    @ViewBuilder private var shortcuts: some View {
        Section {
            Toggle("Atajos de teclado globales", isOn: $settings.hotkeysEnabled)
            LabeledContent("Nueva estantería", value: "⌃⌥D")
            LabeledContent("Nueva estantería con el portapapeles", value: "⌃⌥V")
            LabeledContent("Mostrar u ocultar estanterías", value: "⌃⌥S")
        } footer: {
            SettingsFooter("Funcionan desde cualquier app.")
        }
        Section("Dentro de una estantería") {
            LabeledContent("Vista rápida", value: "Espacio")
            LabeledContent("Quitar lo seleccionado", value: "⌫")
            LabeledContent("Cerrar y vaciar", value: "⌥ + clic en ✕")
        }
    }

    @ViewBuilder private var general: some View {
        Section {
            Toggle("Abrir PoxiDrop al iniciar sesión", isOn: launchAtLogin)
            Toggle("Icono en la barra de menús", isOn: $settings.showMenuBarIcon)
        } footer: {
            if let loginError = state.loginError {
                SettingsFooter(loginError, color: .red)
            } else {
                SettingsFooter("Si quitas el icono, abre PoxiDrop otra vez desde Aplicaciones para volver a los ajustes.")
            }
        }
        Section("Estanterías") {
            LabeledContent("Recientes guardadas", value: "\(store.recents.count)")
            Button("Borrar recientes") { store.clearRecents() }
                .disabled(store.recents.isEmpty)
        }
    }

    @ViewBuilder private var about: some View {
        Section {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("PoxiDrop").font(.title2.bold())
                    Text("Versión \(appVersion)").foregroundStyle(.secondary)
                    Text("Gratis y open source. Hecho por Alexis Juárez.").font(.callout)
                }
            }
        }
        Section {
            Link("Código en GitHub", destination: URL(string: "https://github.com/PoxiiTV/PoxiDrop")!)
            Link("Más programas Poxi", destination: URL(string: "https://tools.alexiis.dev")!)
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { _ = state.refresh; return SMAppService.mainApp.status == .enabled },
            set: { enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    state.loginError = nil
                } catch {
                    state.loginError = "No se pudo cambiar: \(error.localizedDescription)"
                }
                state.refresh.toggle()
            }
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "en desarrollo"
    }

    private func addScript() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Elige un script para «Mis acciones»"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.customScripts.append(CustomScript(name: url.deletingPathExtension().lastPathComponent, path: url.path))
    }
}

/// Texto bajo una sección, alineado a la izquierda como en los Ajustes del Sistema.
struct SettingsFooter: View {
    let text: String
    var color: Color = .secondary

    init(_ text: String, color: Color = .secondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 6).fill(color.gradient))
    }
}
