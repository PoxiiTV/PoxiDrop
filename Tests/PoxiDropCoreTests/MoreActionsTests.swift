import Testing
import Foundation
import AppKit
import PDFKit
@testable import PoxiDropCore

@Suite("OCR, PDF, texto, scripts y registro")
struct MoreActionsTests {
    @Test func ocrLeeElTexto() async throws {
        let dir = try TempDir()
        let image = try dir.textImage("cartel.png", text: "HOLA MUNDO")
        let result = try await ExtractTextAction().perform([image], output: dir.url)
        #expect(result.copiedText?.uppercased().contains("HOLA") == true)
        #expect(result.files[0].lastPathComponent == "Texto extraído.txt")
    }

    @Test func ocrSinTextoAvisa() async throws {
        let dir = try TempDir()
        let image = try dir.image("liso.png", width: 300, height: 300)
        await #expect(throws: ActionError.self) {
            try await ExtractTextAction().perform([image], output: dir.url)
        }
    }

    @Test func pdfConUnaPaginaPorImagen() async throws {
        let dir = try TempDir()
        let a = try dir.image("a.png", width: 100, height: 100)
        let b = try dir.image("b.png", width: 100, height: 100)
        let result = try await MakePDFAction().perform([a, b], output: dir.url)
        #expect(result.files[0].lastPathComponent == "Imágenes.pdf")
        #expect(PDFDocument(url: result.files[0])?.pageCount == 2)
    }

    @Test func textoPlanoDesdeRTF() async throws {
        let dir = try TempDir()
        let styled = NSAttributedString(string: "Hola mundo", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
        let rtf = try styled.data(from: NSRange(location: 0, length: styled.length),
                                  documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let file = dir.url.appendingPathComponent("nota.rtf")
        try rtf.write(to: file)
        let result = try await PlainTextAction().perform([file], output: dir.url.appendingPathComponent("."))
        #expect(try String(contentsOf: result.files[0], encoding: .utf8) == "Hola mundo")
        #expect(result.files[0].lastPathComponent == "nota.txt")
    }

    @Test func scriptRecibeRutasYDevuelveArchivos() async throws {
        let dir = try TempDir()
        let file = try dir.file("a.txt", "contenido")
        let script = try dir.file("copiar.sh", "cp \"$1\" \"$POXIDROP_OUTPUT/copia.txt\"")
        let output = dir.url.appendingPathComponent("salida")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let action = ScriptAction(script: CustomScript(name: "Copiar", path: script.path))
        let result = try await action.perform([file], output: output)
        #expect(result.files.map(\.lastPathComponent) == ["copia.txt"])
        #expect(try String(contentsOf: result.files[0], encoding: .utf8) == "contenido")
    }

    @Test func scriptQueFallaDaSuError() async throws {
        let dir = try TempDir()
        let script = try dir.file("falla.sh", "echo boom >&2\nexit 3")
        let action = ScriptAction(script: CustomScript(name: "Falla", path: script.path))
        await #expect(throws: ActionError("boom")) {
            try await action.perform([script], output: dir.url)
        }
    }

    @Test func registroFiltraPorTipo() throws {
        let dir = try TempDir()
        let image = try dir.image("a.png", width: 10, height: 10)
        let text = try dir.file("a.txt")
        let forImage = ActionRegistry.available(for: [image]).map(\.id)
        let forText = ActionRegistry.available(for: [text]).map(\.id)
        #expect(forImage.contains("image.resize.percent.50"))
        #expect(forImage.contains("file.zip"))
        #expect(!forText.contains("image.resize.percent.50"))
        #expect(forText.contains("file.zip"))
    }

    @Test func buscarSinAcentosNiMayusculas() {
        let found = ActionRegistry.search("REDIMENSION", in: ActionRegistry.builtIn).map(\.id)
        #expect(found.contains("image.resize.side.1920"))
        let texto = ActionRegistry.search("texto", in: ActionRegistry.builtIn).map(\.id)
        #expect(texto.contains("image.ocr"))
        #expect(texto.contains("text.plain"))
        #expect(ActionRegistry.search("", in: ActionRegistry.builtIn).count == ActionRegistry.builtIn.count)
    }
}
