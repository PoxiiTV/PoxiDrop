import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

/// Carpeta temporal para un test; se borra sola al terminar.
final class TempDir {
    let url: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("poxidrop-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // realpath da la ruta canónica (/private/var/…), la misma que devuelven los marcadores de macOS.
        url = URL(fileURLWithPath: String(cString: realpath(base.path, nil)), isDirectory: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    /// Crea un archivo de texto (y sus carpetas) dentro de la carpeta temporal.
    @discardableResult
    func file(_ path: String, _ contents: String = "hola") throws -> URL {
        let file = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    /// Crea una imagen de un solo color.
    @discardableResult
    func image(_ path: String, width: Int, height: Int, type: UTType = .png, properties: [CFString: Any]? = nil) throws -> URL {
        let context = Self.context(width: width, height: height)
        context.setFillColor(CGColor(red: 0.9, green: 0.3, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try write(context.makeImage()!, path: path, type: type, properties: properties)
    }

    /// Imagen con texto negro grande sobre fondo blanco, para probar el OCR.
    func textImage(_ path: String, text: String) throws -> URL {
        let context = Self.context(width: 1000, height: 240)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1000, height: 240))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 96, nil)
        let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        context.textPosition = CGPoint(x: 40, y: 80)
        CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        return try write(context.makeImage()!, path: path, type: .png, properties: nil)
    }

    private func write(_ image: CGImage, path: String, type: UTType, properties: [CFString: Any]?) throws -> URL {
        let file = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(file as CFURL, type.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, properties.map { $0 as CFDictionary })
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return file
    }

    private static func context(width: Int, height: Int) -> CGContext {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
}

/// Tamaño en píxeles de una imagen en disco.
func pixelSize(_ url: URL) -> (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
    return (width, height)
}

/// Tipo (UTI) de una imagen en disco.
func imageType(_ url: URL) -> String? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceGetType(source) as String?
}
