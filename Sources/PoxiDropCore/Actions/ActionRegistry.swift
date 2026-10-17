import Foundation

public enum ActionRegistry {
    public static let builtIn: [any ShelfAction] = [
        ZipAction(),
        ResizeImagesAction(mode: .percent(50)),
        ResizeImagesAction(mode: .percent(25)),
        ResizeImagesAction(mode: .maxSide(1920)),
        ResizeImagesAction(mode: .maxSide(1280)),
        ResizeImagesAction(mode: .maxSide(800)),
        ConvertImagesAction(format: .png),
        ConvertImagesAction(format: .jpeg),
        ConvertImagesAction(format: .heic),
        ConvertImagesAction(format: .tiff),
        CompressImagesAction(),
        StripMetadataAction(),
        StitchImagesAction(direction: .vertical),
        StitchImagesAction(direction: .horizontal),
        ExtractTextAction(),
        MakePDFAction(),
        PlainTextAction(),
    ]

    /// Acciones que se pueden hacer con estos archivos.
    public static func available(for urls: [URL], custom: [any ShelfAction] = []) -> [any ShelfAction] {
        (builtIn + custom).filter { $0.accepts(urls) }
    }

    /// Filtra por título sin tener en cuenta mayúsculas ni acentos.
    public static func search(_ query: String, in actions: [any ShelfAction]) -> [any ShelfAction] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return actions }
        return actions.filter { normalized($0.title).contains(needle) }
    }

    public static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
            .trimmingCharacters(in: .whitespaces)
    }
}
