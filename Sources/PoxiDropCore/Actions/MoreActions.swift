import Foundation
import AppKit
import PDFKit
import Vision

public struct ExtractTextAction: ShelfAction {
    public init() {}

    public let id = "image.ocr"
    public let title = "Extraer texto (OCR)"
    public let symbol = "text.viewfinder"
    public let group = ActionGroup.image

    public func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty && urls.allSatisfy(\.isImageFile) }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        var texts: [String] = []
        for url in urls {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es-ES", "en-US"]
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: try ImageIOHelper.load(url)).perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            if !lines.isEmpty { texts.append(lines.joined(separator: "\n")) }
        }
        guard !texts.isEmpty else { throw ActionError("No se ha encontrado texto en la imagen.") }
        let text = texts.joined(separator: "\n\n")
        let file = UniqueName.url(for: "Texto extraído.txt", in: output)
        try text.write(to: file, atomically: true, encoding: .utf8)
        return ActionResult(files: [file], copiedText: text)
    }
}

public struct MakePDFAction: ShelfAction {
    public init() {}

    public let id = "image.pdf"
    public let title = "Crear PDF"
    public let symbol = "doc.richtext"
    public let group = ActionGroup.image

    public func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty && urls.allSatisfy(\.isImageFile) }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        let document = PDFDocument()
        for (index, url) in urls.enumerated() {
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else {
                throw ActionError("No se puede añadir «\(url.lastPathComponent)» al PDF.")
            }
            document.insert(page, at: index)
        }
        let name = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent + ".pdf" : "Imágenes.pdf"
        let file = UniqueName.url(for: name, in: output)
        guard document.write(to: file) else { throw ActionError("No se pudo crear el PDF.") }
        return ActionResult(files: [file])
    }
}

public struct PlainTextAction: ShelfAction {
    static let extensions: Set<String> = ["rtf", "rtfd", "html", "htm", "doc", "docx", "odt", "webarchive"]

    public init() {}

    public let id = "text.plain"
    public let title = "Convertir a texto plano"
    public let symbol = "textformat"
    public let group = ActionGroup.text

    public func accepts(_ urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy { Self.extensions.contains($0.pathExtension.lowercased()) }
    }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        var files: [URL] = []
        for url in urls {
            // Leer HTML usa WebKit, que solo funciona en el hilo principal.
            let text = try await MainActor.run {
                try NSAttributedString(url: url, options: [:], documentAttributes: nil).string
            }
            let file = UniqueName.url(for: url.deletingPathExtension().lastPathComponent + ".txt", in: output)
            try text.write(to: file, atomically: true, encoding: .utf8)
            files.append(file)
        }
        return ActionResult(files: files)
    }
}

/// Un script del usuario que aparece en «Mis acciones».
public struct CustomScript: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var path: String

    public init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}

/// Ejecuta un script con las rutas como argumentos. Lo que deje en `$POXIDROP_OUTPUT` vuelve a la estantería.
public struct ScriptAction: ShelfAction {
    public let script: CustomScript
    public init(script: CustomScript) { self.script = script }

    public var id: String { "custom.\(script.id.uuidString)" }
    public var title: String { script.name }
    public var symbol: String { "terminal" }
    public var group: ActionGroup { .custom }

    public func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        let paths = urls.map(\.path)
        let environment = ["POXIDROP_OUTPUT": output.path]
        if FileManager.default.isExecutableFile(atPath: script.path) {
            try ProcessRunner.run(script.path, paths, environment: environment)
        } else {
            try ProcessRunner.run("/bin/zsh", [script.path] + paths, environment: environment)
        }
        let produced = (try? FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)) ?? []
        return ActionResult(files: produced.sorted { $0.lastPathComponent < $1.lastPathComponent })
    }
}
