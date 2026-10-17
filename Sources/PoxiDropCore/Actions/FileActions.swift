import Foundation

public struct ZipAction: ShelfAction {
    public let id = "file.zip"
    public let title = "Comprimir en ZIP"
    public let symbol = "doc.zipper"
    public let group = ActionGroup.file

    public init() {}

    public func accepts(_ urls: [URL]) -> Bool { !urls.isEmpty }

    public func perform(_ urls: [URL], output: URL) async throws -> ActionResult {
        let name = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Archivos"
        let zip = UniqueName.url(for: "\(name).zip", in: output)
        // Sin recursos ni atributos de macOS: así no aparece la carpeta «__MACOSX» al abrirlo en Windows.
        let flags = ["-c", "-k", "--norsrc", "--noextattr", "--noqtn", "--noacl"]
        if urls.count == 1 {
            let isFolder = (try? urls[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            try ProcessRunner.run("/usr/bin/ditto", flags + (isFolder ? ["--keepParent"] : []) + [urls[0].path, zip.path])
        } else {
            let staging = FileManager.default.temporaryDirectory.appendingPathComponent("poxidrop-zip-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: staging) }
            for url in urls {
                try FileManager.default.copyItem(at: url, to: UniqueName.url(for: url.lastPathComponent, in: staging))
            }
            try ProcessRunner.run("/usr/bin/ditto", flags + [staging.path, zip.path])
        }
        return ActionResult(files: [zip])
    }
}

public enum FileOps {
    /// Copia a una carpeta sin pisar nada. Devuelve las rutas nuevas.
    public static func copy(_ urls: [URL], to folder: URL) throws -> [URL] {
        try urls.map { url in
            let target = UniqueName.url(for: url.lastPathComponent, in: folder)
            try FileManager.default.copyItem(at: url, to: target)
            return target
        }
    }

    /// Mueve a una carpeta sin pisar nada. Devuelve las rutas nuevas.
    public static func move(_ urls: [URL], to folder: URL) throws -> [URL] {
        try urls.map { url in
            let target = UniqueName.url(for: url.lastPathComponent, in: folder)
            try FileManager.default.moveItem(at: url, to: target)
            return target
        }
    }

    /// Cambia el nombre de un archivo en su misma carpeta.
    public static func rename(_ url: URL, to newName: String) throws -> URL {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ActionError("Escribe un nombre.") }
        guard !name.contains("/"), !name.contains(":") else { throw ActionError("El nombre no puede llevar «/» ni «:».") }
        guard name.utf8.count <= 255 else { throw ActionError("El nombre es demasiado largo.") }
        let target = url.deletingLastPathComponent().appendingPathComponent(name)
        if target.path == url.path { return url }
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw ActionError("Ya existe un archivo llamado «\(name)».")
        }
        try FileManager.default.moveItem(at: url, to: target)
        return target
    }
}
