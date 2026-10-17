import Foundation
import UniformTypeIdentifiers

public enum ActionGroup: String, CaseIterable, Sendable {
    case file = "Archivo"
    case image = "Imagen"
    case text = "Texto"
    case custom = "Mis acciones"
}

public struct ActionResult: Sendable {
    /// Archivos nuevos que se añaden a la estantería.
    public var files: [URL]
    /// Texto que la app copia al portapapeles (OCR).
    public var copiedText: String?

    public init(files: [URL] = [], copiedText: String? = nil) {
        self.files = files
        self.copiedText = copiedText
    }
}

public struct ActionError: LocalizedError, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// Una acción sobre los archivos de una estantería. Nunca modifica los originales:
/// los resultados se crean en `output`.
public protocol ShelfAction: Sendable {
    var id: String { get }
    var title: String { get }
    var symbol: String { get }
    var group: ActionGroup { get }
    func accepts(_ urls: [URL]) -> Bool
    func perform(_ urls: [URL], output: URL) async throws -> ActionResult
}

extension URL {
    var isImageFile: Bool {
        UTType(filenameExtension: pathExtension.lowercased())?.conforms(to: .image) == true
    }
}

enum UniqueName {
    /// Ruta libre en `folder`: «foto.png», «foto 2.png», «foto 3.png»…
    static func url(for name: String, in folder: URL) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)")
            number += 1
        }
        return candidate
    }
}

enum ProcessRunner {
    /// Ejecuta un programa y devuelve su salida. Si falla, lanza `ActionError` con lo que escribió en stderr.
    @discardableResult
    static func run(_ executable: String, _ arguments: [String], environment: [String: String] = [:]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if !environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
        }
        let errorFile = FileManager.default.temporaryDirectory.appendingPathComponent("poxidrop-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: errorFile.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: errorFile) }
        let errorHandle = try FileHandle(forWritingTo: errorFile)
        let output = Pipe()
        process.standardOutput = output
        process.standardError = errorHandle
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try? errorHandle.close()
        guard process.terminationStatus == 0 else {
            let message = (try? String(contentsOf: errorFile, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw ActionError(message.isEmpty ? "El proceso terminó con el código \(process.terminationStatus)." : message)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
