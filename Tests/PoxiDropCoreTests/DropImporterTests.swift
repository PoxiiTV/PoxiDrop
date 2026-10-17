import Testing
import Foundation
@testable import PoxiDropCore

@Suite("Importador")
struct DropImporterTests {
    @Test func archivosSeGuardanComoReferencia() throws {
        let dir = try TempDir()
        let file = try dir.file("foto.png")
        let items = try DropImporter(itemsRoot: dir.url.appendingPathComponent("Items")).items(from: .files([file]))
        #expect(items.count == 1)
        #expect(items[0].url == file)
        #expect(items[0].isOwned == false)
        #expect(items[0].bookmark != nil)
        #expect(items[0].kind == .image)
    }

    @Test func propiosQuedanMarcados() throws {
        let dir = try TempDir()
        let file = try dir.file("resultado.txt")
        let items = try DropImporter(itemsRoot: dir.url).items(from: .ownedFiles([file]))
        #expect(items[0].isOwned)
        #expect(items[0].kind == .text)
    }

    @Test func textoCreaUnTxt() throws {
        let dir = try TempDir()
        let items = try DropImporter(itemsRoot: dir.url).items(from: .text("Lista de la compra\nleche\npan"))
        #expect(items[0].name == "Lista de la compra.txt")
        #expect(items[0].isOwned)
        #expect(try String(contentsOf: items[0].url, encoding: .utf8) == "Lista de la compra\nleche\npan")
    }

    @Test func nombreDeTextoLimpio() {
        #expect(DropImporter.fileName(forText: "a/b:c") == "a-b-c")
        #expect(DropImporter.fileName(forText: "   ") == "Texto")
        #expect(DropImporter.fileName(forText: ".oculto") == "oculto")
        #expect(DropImporter.fileName(forText: String(repeating: "x", count: 100)).count == 40)
    }

    @Test func enlaceCreaWebloc() throws {
        let dir = try TempDir()
        let link = URL(string: "https://tools.alexiis.dev/poxiiso/")!
        let items = try DropImporter(itemsRoot: dir.url).items(from: .webLink(link))
        #expect(items[0].name == "tools.alexiis.dev.webloc")
        #expect(items[0].kind == .link)
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: items[0].url), format: nil) as? [String: String]
        #expect(plist?["URL"] == link.absoluteString)
    }

    @Test func imagenSeGuarda() throws {
        let dir = try TempDir()
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let items = try DropImporter(itemsRoot: dir.url).items(from: .image(data, fileExtension: "png"), now: Date(timeIntervalSince1970: 0))
        #expect(items[0].kind == .image)
        #expect(items[0].url.pathExtension == "png")
        #expect(try Data(contentsOf: items[0].url) == data)
    }
}
