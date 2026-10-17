import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageIOHelper {
    /// Carga una imagen ya girada según su orientación EXIF.
    static func load(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw ActionError("No se puede leer la imagen «\(url.lastPathComponent)».")
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ActionError("No se puede leer la imagen «\(url.lastPathComponent)».")
        }
        return image
    }

    static func context(width: Int, height: Int) throws -> CGContext {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ActionError("La imagen es demasiado grande.")
        }
        context.interpolationQuality = .high
        return context
    }

    static func scaled(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
        let context = try context(width: width, height: height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let result = context.makeImage() else { throw ActionError("No se pudo redimensionar la imagen.") }
        return result
    }

    /// Guarda una imagen sin metadatos. Para JPEG rellena la transparencia de blanco.
    static func write(_ image: CGImage, to url: URL, type: UTType, quality: Double = 0.9) throws {
        var output = image
        if type == .jpeg {
            let context = try context(width: image.width, height: image.height)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            output = context.makeImage() ?? image
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw ActionError("Este Mac no puede guardar imágenes en formato \(fileExtension(for: type).uppercased()).")
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, output, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ActionError("No se pudo guardar «\(url.lastPathComponent)».")
        }
    }

    /// El tipo del original si se puede escribir; si no, PNG.
    static func writableType(for url: URL) -> UTType {
        let type = UTType(filenameExtension: url.pathExtension.lowercased()) ?? .png
        let writable = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return writable.contains(type.identifier) ? type : .png
    }

    static func fileExtension(for type: UTType) -> String {
        type == .jpeg ? "jpg" : (type.preferredFilenameExtension ?? "png")
    }

    /// «foto (50 %).png» en la carpeta de salida, sin pisar nada.
    static func outputURL(for source: URL, suffix: String?, type: UTType, in folder: URL) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let name = suffix.map { "\(base) (\($0))" } ?? base
        return UniqueName.url(for: "\(name).\(fileExtension(for: type))", in: folder)
    }
}

public enum ImageFormat: String, CaseIterable, Sendable {
    case png, jpeg, heic, tiff

    public var type: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .tiff: return .tiff
        }
    }

    public var label: String { rawValue.uppercased() }
}

public struct ResizeImagesAction: ShelfAction {
    public enum Mode: Sendable, Equatable {
        case percent(Int)
        case maxSide(Int)
    }

    public let mode: Mode
    public init(mode: Mode) { self.mode = mode }

    public var id: String {
        switch mode {
        case .percent(let percent): return "image.resize.percent.\(percent)"
        case .maxSide(let side): return "image.resize.side.\(side)"
        }
    }

    public var title: String {
        switch mode {
        case .percent(let percent): return "Redimensionar al \(percent) %"
        case .maxSide(let side): return "Redimensionar a \(side) px"
        }
    }

    public var symbol: String { "arrow.down.right.and.arrow.up.left" }
    public var group: ActionGroup { .image }

    public func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty && urls.allSatisfy(\.isImageFile) }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        var files: [URL] = []
        for url in urls {
            let image = try ImageIOHelper.load(url)
            let size = targetSize(width: image.width, height: image.height)
            let resized = try ImageIOHelper.scaled(image, width: size.width, height: size.height)
            let type = ImageIOHelper.writableType(for: url)
            let file = ImageIOHelper.outputURL(for: url, suffix: suffix, type: type, in: output)
            try ImageIOHelper.write(resized, to: file, type: type)
            files.append(file)
        }
        return ActionResult(files: files)
    }

    private var suffix: String {
        switch mode {
        case .percent(let percent): return "\(percent) %"
        case .maxSide(let side): return "\(side) px"
        }
    }

    func targetSize(width: Int, height: Int) -> (width: Int, height: Int) {
        switch mode {
        case .percent(let percent):
            return (max(1, width * percent / 100), max(1, height * percent / 100))
        case .maxSide(let side):
            let scale = min(1, Double(side) / Double(max(width, height)))
            return (max(1, Int((Double(width) * scale).rounded())), max(1, Int((Double(height) * scale).rounded())))
        }
    }
}

public struct ConvertImagesAction: ShelfAction {
    public let format: ImageFormat
    public init(format: ImageFormat) { self.format = format }

    public var id: String { "image.convert.\(format.rawValue)" }
    public var title: String { "Convertir a \(format.label)" }
    public var symbol: String { "arrow.triangle.2.circlepath" }
    public var group: ActionGroup { .image }

    public func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty && urls.allSatisfy(\.isImageFile) }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        var files: [URL] = []
        for url in urls {
            let file = ImageIOHelper.outputURL(for: url, suffix: nil, type: format.type, in: output)
            try ImageIOHelper.write(try ImageIOHelper.load(url), to: file, type: format.type)
            files.append(file)
        }
        return ActionResult(files: files)
    }
}

public struct CompressImagesAction: ShelfAction {
    public let quality: Double
    public init(quality: Double = 0.7) { self.quality = quality }

    public let id = "image.compress"
    public let title = "Comprimir imágenes (JPEG)"
    public let symbol = "arrow.down.to.line.compact"
    public let group = ActionGroup.image

    public func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty && urls.allSatisfy(\.isImageFile) }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        var files: [URL] = []
        for url in urls {
            let file = ImageIOHelper.outputURL(for: url, suffix: "comprimida", type: .jpeg, in: output)
            try ImageIOHelper.write(try ImageIOHelper.load(url), to: file, type: .jpeg, quality: quality)
            files.append(file)
        }
        return ActionResult(files: files)
    }
}

public struct StripMetadataAction: ShelfAction {
    public init() {}

    public let id = "image.strip-metadata"
    public let title = "Quitar metadatos"
    public let symbol = "eye.slash"
    public let group = ActionGroup.image

    public func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty && urls.allSatisfy(\.isImageFile) }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        var files: [URL] = []
        for url in urls {
            let type = ImageIOHelper.writableType(for: url)
            let file = ImageIOHelper.outputURL(for: url, suffix: "sin metadatos", type: type, in: output)
            try ImageIOHelper.write(try ImageIOHelper.load(url), to: file, type: type, quality: 0.95)
            files.append(file)
        }
        return ActionResult(files: files)
    }
}

public struct StitchImagesAction: ShelfAction {
    public enum Direction: String, Sendable {
        case vertical, horizontal
    }

    public let direction: Direction
    public init(direction: Direction) { self.direction = direction }

    public var id: String { "image.stitch.\(direction.rawValue)" }
    public var title: String { direction == .vertical ? "Unir en vertical" : "Unir en horizontal" }
    public var symbol: String { direction == .vertical ? "rectangle.split.1x2" : "rectangle.split.2x1" }
    public var group: ActionGroup { .image }

    public func accepts(_ urls: [URL]) -> Bool { urls.count >= 2 && urls.allSatisfy(\.isImageFile) }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        let images = try urls.map(ImageIOHelper.load)
        let result: CGImage
        switch direction {
        case .vertical:
            let width = images.map(\.width).max() ?? 1
            let heights = images.map { Int((Double($0.height) * Double(width) / Double($0.width)).rounded()) }
            let context = try ImageIOHelper.context(width: width, height: heights.reduce(0, +))
            var top = heights.reduce(0, +)
            for (image, height) in zip(images, heights) {
                top -= height
                context.draw(image, in: CGRect(x: 0, y: top, width: width, height: height))
            }
            guard let made = context.makeImage() else { throw ActionError("No se pudieron unir las imágenes.") }
            result = made
        case .horizontal:
            let height = images.map(\.height).max() ?? 1
            let widths = images.map { Int((Double($0.width) * Double(height) / Double($0.height)).rounded()) }
            let context = try ImageIOHelper.context(width: widths.reduce(0, +), height: height)
            var left = 0
            for (image, width) in zip(images, widths) {
                context.draw(image, in: CGRect(x: left, y: 0, width: width, height: height))
                left += width
            }
            guard let made = context.makeImage() else { throw ActionError("No se pudieron unir las imágenes.") }
            result = made
        }
        let file = UniqueName.url(for: "Imágenes unidas.png", in: output)
        try ImageIOHelper.write(result, to: file, type: .png)
        return ActionResult(files: [file])
    }
}
