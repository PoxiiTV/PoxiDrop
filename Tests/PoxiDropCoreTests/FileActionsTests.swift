import Testing
import Foundation
@testable import PoxiDropCore

@Suite("Acciones de archivo")
struct FileActionsTests {
    func zipNames(_ zip: URL) throws -> [String] {
        try ProcessRunner.run("/usr/bin/zipinfo", ["-1", zip.path]).split(separator: "\n").map(String.init)
    }

    @Test func zipDeUnArchivo() async throws {
        let dir = try TempDir()
        let file = try dir.file("notas.txt")
        let out = dir.url.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let result = try await ZipAction().perform([file], output: out)
        #expect(result.files.map(\.lastPathComponent) == ["notas.zip"])
        #expect(try zipNames(result.files[0]) == ["notas.txt"])
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func zipDeVariosConElMismoNombre() async throws {
        let dir = try TempDir()
        let a = try dir.file("uno/x.txt")
        let b = try dir.file("dos/x.txt")
        let result = try await ZipAction().perform([a, b], output: dir.url)
        #expect(result.files[0].lastPathComponent == "Archivos.zip")
        let names = try zipNames(result.files[0])
        #expect(names.contains("x.txt"))
        #expect(names.contains("x 2.txt"))
    }

    @Test func zipDeCarpeta() async throws {
        let dir = try TempDir()
        try dir.file("Carpeta/f.txt")
        let result = try await ZipAction().perform([dir.url.appendingPathComponent("Carpeta")], output: dir.url)
        let names = try zipNames(result.files[0])
        #expect(names.contains("Carpeta/f.txt"))
        #expect(!names.contains { $0.hasPrefix("__MACOSX") })
    }

    @Test func copiarSinPisar() throws {
        let dir = try TempDir()
        let file = try dir.file("a.txt", "nuevo")
        try dir.file("destino/a.txt", "viejo")
        let copied = try FileOps.copy([file], to: dir.url.appendingPathComponent("destino"))
        #expect(copied[0].lastPathComponent == "a 2.txt")
        #expect(try String(contentsOf: dir.url.appendingPathComponent("destino/a.txt"), encoding: .utf8) == "viejo")
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func mover() throws {
        let dir = try TempDir()
        let file = try dir.file("a.txt")
        let destination = dir.url.appendingPathComponent("destino")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let moved = try FileOps.move([file], to: destination)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(FileManager.default.fileExists(atPath: moved[0].path))
    }

    @Test func renombrarValidaElNombre() throws {
        let dir = try TempDir()
        let file = try dir.file("a.txt")
        try dir.file("ocupado.txt")
        #expect(throws: ActionError.self) { try FileOps.rename(file, to: "  ") }
        #expect(throws: ActionError.self) { try FileOps.rename(file, to: "a/b.txt") }
        #expect(throws: ActionError.self) { try FileOps.rename(file, to: "ocupado.txt") }
        let renamed = try FileOps.rename(file, to: "b.txt")
        #expect(renamed.lastPathComponent == "b.txt")
        #expect(FileManager.default.fileExists(atPath: renamed.path))
    }

    @Test func procesoQueFallaDaElError() {
        #expect(throws: ActionError("boom")) {
            try ProcessRunner.run("/bin/sh", ["-c", "echo boom >&2; exit 3"])
        }
    }
}
