// Banner del README (2560x760) con el estilo de la familia Poxi.
// Uso: make-banner <icono.png> <estanteria.png> <detalle.png> <salida.png>
import SwiftUI
import AppKit

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

let mint = Color(hex: 0x34E0A8)
let edge = Color(hex: 0x2A3446)
let panelColor = Color(hex: 0x111827)
let hardShadow = Color(hex: 0x04070D)

struct Grid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            stride(from: 0, through: size.width, by: 40).forEach { path.addRect(CGRect(x: $0, y: 0, width: 1, height: size.height)) }
            stride(from: 0, through: size.height, by: 40).forEach { path.addRect(CGRect(x: 0, y: $0, width: size.width, height: 1)) }
            context.fill(path, with: .color(.white.opacity(0.035)))
        }
    }
}

struct PixelBox<Content: View>: View {
    var shadow: CGFloat = 8
    var fill = panelColor
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(fill)
            .overlay(Rectangle().strokeBorder(edge, lineWidth: 3))
            .background(hardShadow.offset(x: shadow, y: shadow))
    }
}

struct Chip: View {
    let text: String
    let color: Color

    var body: some View {
        PixelBox(shadow: 5, fill: Color(hex: 0x0D1320)) {
            HStack(spacing: 14) {
                Rectangle().fill(color).frame(width: 13, height: 13)
                Text(text)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(Color(hex: 0xEEF2FB))
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
        }
    }
}

struct Banner: View {
    let icon: NSImage
    let shelf: NSImage
    let detail: NSImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: 0x0A111F)
            Grid()
            RadialGradient(colors: [mint.opacity(0.08), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 700)

            PixelBox {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 26) {
                        Image(nsImage: icon).resizable().interpolation(.none).frame(width: 150, height: 150).padding(-20)
                        (Text("Poxi").foregroundColor(Color(hex: 0xF4F6FB)) + Text("Drop").foregroundColor(mint))
                            .font(.system(size: 112, weight: .black, design: .rounded))
                            .shadow(color: hardShadow, radius: 0, x: 6, y: 6)
                    }
                    Text("Agita el ratón, suelta y llévalo a donde quieras")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0x9AA6BD))
                        .padding(.top, 26)
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 20) {
                            Chip(text: "AGITAR PARA ABRIR", color: mint)
                            Chip(text: "ACCIONES RÁPIDAS", color: Color(hex: 0x60A5FA))
                        }
                        HStack(spacing: 20) {
                            Chip(text: "GRATIS", color: Color(hex: 0xFFCE3A))
                            Chip(text: "SIN ANUNCIOS", color: Color(hex: 0xF472B6))
                            Chip(text: "OPEN SOURCE", color: Color(hex: 0xA78BFA))
                        }
                    }
                    .padding(.top, 44)
                }
                .padding(.horizontal, 54)
                .padding(.vertical, 50)
                .frame(width: 1110, alignment: .leading)
            }
            .offset(x: 82, y: 82)

            PixelBox(shadow: 10, fill: Color(hex: 0x0A0E1C)) {
                ZStack(alignment: .top) {
                    LinearGradient(colors: [Color(hex: 0x5C4DD9), Color(hex: 0xED739E)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 0) {
                        Image(nsImage: shelf).resizable().aspectRatio(contentMode: .fit).frame(height: 190)
                        Image(nsImage: detail).resizable().aspectRatio(contentMode: .fit).frame(height: 300).padding(.top, 14)
                    }
                    .padding(.top, 36)
                }
                .frame(width: 1080, height: 600)
                .clipped()
            }
            .offset(x: 1376, y: 70)

            PixelBox(shadow: 7, fill: mint) {
                Text("AGITA Y SUELTA")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Color(hex: 0x0A111F))
                    .padding(.horizontal, 30)
                    .frame(height: 82)
            }
            .offset(x: 2040, y: 610)
        }
        .frame(width: 2560, height: 760)
        .clipped()
    }
}

/// Quita el margen de fondo (40 puntos) que añaden las capturas de `PoxiDrop --snapshot`.
func trimmed(_ image: NSImage, margin: CGFloat = 40) -> NSImage {
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
    let scale = CGFloat(cg.width) / image.size.width
    let rect = CGRect(x: 0, y: 0, width: cg.width, height: cg.height).insetBy(dx: margin * scale, dy: margin * scale)
    guard let cropped = cg.cropping(to: rect) else { return image }
    return NSImage(cgImage: cropped, size: NSSize(width: rect.width / scale, height: rect.height / scale))
}

@main
enum Main {
    @MainActor static func main() {
        _ = NSApplication.shared
        let args = CommandLine.arguments
        guard args.count == 5, let icon = NSImage(contentsOfFile: args[1]),
              let shelf = NSImage(contentsOfFile: args[2]), let detail = NSImage(contentsOfFile: args[3]) else {
            print("Uso: make-banner <icono.png> <estanteria.png> <detalle.png> <salida.png>")
            exit(1)
        }
        let renderer = ImageRenderer(content: Banner(icon: icon, shelf: trimmed(shelf), detail: trimmed(detail)))
        renderer.scale = 1
        guard let tiff = renderer.nsImage?.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            print("No se pudo renderizar")
            exit(1)
        }
        try! png.write(to: URL(fileURLWithPath: args[4]))
        print("Banner: \(args[4])")
    }
}
