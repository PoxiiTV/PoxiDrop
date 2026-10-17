import Foundation

public enum FileSizes {
    /// Tamaño de un archivo, o la suma de todo lo que hay dentro si es una carpeta.
    public static func size(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else { return 0 }
        guard values.isDirectory == true else { return Int64(values.fileSize ?? 0) }
        var total: Int64 = 0
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        while let file = enumerator?.nextObject() as? URL {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    public static func total(of urls: [URL]) -> Int64 {
        urls.reduce(0) { $0 + size(of: $1) }
    }

    /// «3,1 MB», en el idioma del sistema.
    public static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
