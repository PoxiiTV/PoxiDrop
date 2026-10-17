import AppKit
import PoxiDropCore

enum PasteboardReader {
    static let dropTypes: [NSPasteboard.PasteboardType] =
        [.fileURL, .URL, .png, .tiff, .string] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

    /// Lee archivos, imágenes, enlaces o texto (en ese orden de preferencia).
    static func payloads(from pasteboard: NSPasteboard) -> [DropPayload] {
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !files.isEmpty {
            return [.files(files)]
        }
        if let png = pasteboard.data(forType: .png) {
            return [.image(png, fileExtension: "png")]
        }
        if let tiff = pasteboard.data(forType: .tiff),
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            return [.image(png, fileExtension: "png")]
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let link = urls.first(where: { $0.scheme == "http" || $0.scheme == "https" }) {
            return [.webLink(link)]
        }
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [.text(text)]
        }
        return []
    }
}
