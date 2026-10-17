import Testing
import Foundation
@testable import PoxiDropCore

@Suite("Nombres y tamaños")
struct NamingTests {
    func item(_ name: String, _ kind: ItemKind) -> ShelfItem {
        ShelfItem(url: URL(fileURLWithPath: "/tmp/\(name)"), isOwned: false, kind: kind)
    }

    @Test func vacia() {
        #expect(ShelfNaming.automaticName(for: []) == "Estantería vacía")
    }

    @Test func unoUsaSuNombre() {
        #expect(ShelfNaming.automaticName(for: [item("foto.jpg", .image)]) == "foto.jpg")
    }

    @Test func variasImagenes() {
        #expect(ShelfNaming.automaticName(for: [item("a.jpg", .image), item("b.png", .image)]) == "2 imágenes")
    }

    @Test func mezcla() {
        #expect(ShelfNaming.countLabel(for: [item("a.jpg", .image), item("Docs", .folder)]) == "2 elementos")
    }

    @Test func singular() {
        #expect(ShelfNaming.countLabel(for: [item("Docs", .folder)]) == "1 carpeta")
    }

    @Test func nombrePersonalizadoManda() {
        let shelf = Shelf(items: [item("a.jpg", .image), item("b.jpg", .image)], customName: "Vacaciones")
        #expect(shelf.name == "Vacaciones")
    }

    @Test func tipoPorArchivo() throws {
        let dir = try TempDir()
        let folder = dir.url.appendingPathComponent("Carpeta")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        #expect(ShelfItem.kind(of: folder) == .folder)
        #expect(ShelfItem.kind(of: dir.url.appendingPathComponent("a.PNG")) == .image)
        #expect(ShelfItem.kind(of: dir.url.appendingPathComponent("nota.txt")) == .text)
        #expect(ShelfItem.kind(of: dir.url.appendingPathComponent("web.webloc")) == .link)
        #expect(ShelfItem.kind(of: dir.url.appendingPathComponent("doc.pdf")) == .file)
    }

    @Test func tamanoDeCarpeta() throws {
        let dir = try TempDir()
        try Data(count: 1000).write(to: dir.url.appendingPathComponent("a.bin"))
        let sub = dir.url.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(count: 500).write(to: sub.appendingPathComponent("b.bin"))
        #expect(FileSizes.total(of: [dir.url]) == 1500)
        #expect(FileSizes.size(of: dir.url.appendingPathComponent("a.bin")) == 1000)
    }
}
