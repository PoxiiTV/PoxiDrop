import Testing
import Foundation
import CoreGraphics
@testable import PoxiDropCore

@MainActor
@Suite("Almacén de estanterías")
struct ShelfStoreTests {
    func external(_ url: URL) throws -> ShelfItem {
        ShelfItem(url: url, bookmark: try url.bookmarkData(), isOwned: false, kind: ShelfItem.kind(of: url))
    }

    func owned(in store: ShelfStore, name: String = "t.txt") throws -> ShelfItem {
        let file = try store.makeOwnedFolder().appendingPathComponent(name)
        try "x".write(to: file, atomically: true, encoding: .utf8)
        return ShelfItem(url: file, isOwned: true, kind: .text)
    }

    @Test func crearAnadirYRecargar() throws {
        let dir = try TempDir()
        let file = try dir.file("docs/a.txt")
        let data = dir.url.appendingPathComponent("datos")
        let store = ShelfStore(directory: data)
        let id = store.createShelf(origin: CGPoint(x: 10, y: 20))
        store.add([try external(file)], to: id)

        let again = ShelfStore(directory: data)
        #expect(again.shelves.count == 1)
        #expect(again.shelves[0].items.map(\.url.path) == [file.path])
        #expect(again.shelves[0].origin == CGPoint(x: 10, y: 20))
    }

    @Test func noAnadeDuplicados() throws {
        let dir = try TempDir()
        let file = try dir.file("a.txt")
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        let id = store.createShelf()
        store.add([try external(file)], to: id)
        store.add([try external(file)], to: id)
        #expect(store.shelf(id)?.items.count == 1)
    }

    @Test func cerrarPasaARecientes() throws {
        let dir = try TempDir()
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        let full = store.createShelf()
        store.add([try external(try dir.file("a.txt"))], to: full)
        let empty = store.createShelf()
        store.close(full)
        store.close(empty)
        #expect(store.shelves.isEmpty)
        #expect(store.recents.map(\.id) == [full])
    }

    @Test func favoritaNoSeCierraYSoloHayUna() throws {
        let dir = try TempDir()
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        let a = store.createShelf()
        let b = store.createShelf()
        store.setFavorite(a, true)
        store.setFavorite(b, true)
        #expect(store.shelf(a)?.isFavorite == false)
        #expect(store.favorite?.id == b)
        store.close(b)
        #expect(store.shelf(b) != nil)
    }

    @Test func reabrirReciente() throws {
        let dir = try TempDir()
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        let id = store.createShelf()
        store.add([try external(try dir.file("a.txt"))], to: id)
        store.close(id)
        #expect(store.reopen(recent: id) == id)
        #expect(store.recents.isEmpty)
        #expect(store.shelf(id)?.items.count == 1)
    }

    @Test func quitarPropioBorraSuArchivo() throws {
        let dir = try TempDir()
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        let id = store.createShelf()
        let item = try owned(in: store)
        store.add([item], to: id)
        store.remove([item.id], from: id)
        #expect(!FileManager.default.fileExists(atPath: item.url.path))
        #expect(!FileManager.default.fileExists(atPath: item.url.deletingLastPathComponent().path))
        #expect(store.shelf(id)?.items.isEmpty == true)
    }

    @Test func quitarSinBorrarConservaElArchivo() throws {
        let dir = try TempDir()
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        let id = store.createShelf()
        let item = try owned(in: store)
        store.add([item], to: id)
        store.remove([item.id], from: id, deleteOwnedFiles: false)
        #expect(FileManager.default.fileExists(atPath: item.url.path))
    }

    @Test func nuncaBorraArchivosDelUsuario() throws {
        let dir = try TempDir()
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        let id = store.createShelf()
        let mine = try dir.file("importante.txt")
        let markedWrong = ShelfItem(url: try dir.file("otro.txt"), isOwned: true, kind: .text)
        store.add([try external(mine), markedWrong], to: id)
        store.clear(id)
        #expect(FileManager.default.fileExists(atPath: mine.path))
        #expect(FileManager.default.fileExists(atPath: markedWrong.url.path))
    }

    @Test func recientesLimitadasA10() throws {
        let dir = try TempDir()
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        var firstFile: URL?
        for index in 0..<11 {
            let id = store.createShelf()
            let item = try owned(in: store, name: "\(index).txt")
            if index == 0 { firstFile = item.url }
            store.add([item], to: id)
            store.close(id)
        }
        #expect(store.recents.count == ShelfStore.recentLimit)
        #expect(!FileManager.default.fileExists(atPath: firstFile!.path))
    }

    @Test func marcadorSigueAlArchivoMovido() throws {
        let dir = try TempDir()
        let file = try dir.file("a.txt")
        let data = dir.url.appendingPathComponent("datos")
        let store = ShelfStore(directory: data)
        let id = store.createShelf()
        store.add([try external(file)], to: id)
        let moved = dir.url.appendingPathComponent("b/c.txt")
        try FileManager.default.createDirectory(at: moved.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: file, to: moved)

        let again = ShelfStore(directory: data)
        #expect(again.shelves[0].items[0].url.path == moved.path)
    }

    @Test func renombrarEstanteria() throws {
        let dir = try TempDir()
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        let id = store.createShelf()
        store.rename(id, to: "  Mis fotos ")
        #expect(store.shelf(id)?.name == "Mis fotos")
        store.rename(id, to: "")
        #expect(store.shelf(id)?.customName == nil)
    }

    @Test func cambiarRutaDeUnElemento() throws {
        let dir = try TempDir()
        let store = ShelfStore(directory: dir.url.appendingPathComponent("datos"))
        let id = store.createShelf()
        let item = try external(try dir.file("a.txt"))
        store.add([item], to: id)
        let renamed = dir.url.appendingPathComponent("b.txt")
        try FileManager.default.moveItem(at: item.url, to: renamed)
        store.replaceURL(of: item.id, in: id, with: renamed)
        #expect(store.shelf(id)?.items[0].url == renamed)
    }
}
