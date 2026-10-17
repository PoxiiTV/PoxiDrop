import Testing
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import PoxiDropCore

@Suite("Acciones de imagen")
struct ImageActionsTests {
    @Test func redimensionarPorPorcentaje() async throws {
        let dir = try TempDir()
        let image = try dir.image("foto.png", width: 400, height: 200)
        let result = try await ResizeImagesAction(mode: .percent(50)).perform([image], output: dir.url)
        #expect(pixelSize(result.files[0])! == (200, 100))
        #expect(result.files[0].lastPathComponent == "foto (50 %).png")
        #expect(pixelSize(image)! == (400, 200))
    }

    @Test func ladoMaximoNoAgranda() async throws {
        let dir = try TempDir()
        let image = try dir.image("foto.png", width: 400, height: 200)
        let same = try await ResizeImagesAction(mode: .maxSide(1920)).perform([image], output: dir.url)
        #expect(pixelSize(same.files[0])! == (400, 200))
        let small = try await ResizeImagesAction(mode: .maxSide(100)).perform([image], output: dir.url)
        #expect(pixelSize(small.files[0])! == (100, 50))
    }

    @Test func convertirAJPEGyHEIC() async throws {
        let dir = try TempDir()
        let image = try dir.image("foto.png", width: 64, height: 64)
        let jpeg = try await ConvertImagesAction(format: .jpeg).perform([image], output: dir.url)
        #expect(jpeg.files[0].pathExtension == "jpg")
        #expect(imageType(jpeg.files[0]) == UTType.jpeg.identifier)
        let heic = try await ConvertImagesAction(format: .heic).perform([image], output: dir.url)
        #expect(imageType(heic.files[0]) == UTType.heic.identifier)
    }

    @Test func comprimirDaJPEG() async throws {
        let dir = try TempDir()
        let image = try dir.image("foto.png", width: 64, height: 64)
        let result = try await CompressImagesAction().perform([image], output: dir.url)
        #expect(result.files[0].lastPathComponent == "foto (comprimida).jpg")
        #expect(imageType(result.files[0]) == UTType.jpeg.identifier)
    }

    @Test func quitarMetadatos() async throws {
        let dir = try TempDir()
        let properties: [CFString: Any] = [
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFImageDescription: "secreto"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "secreto"],
        ]
        let image = try dir.image("foto.jpg", width: 64, height: 64, type: .jpeg, properties: properties)
        let result = try await StripMetadataAction().perform([image], output: dir.url)
        let source = CGImageSourceCreateWithURL(result.files[0] as CFURL, nil)!
        let read = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let tiff = read[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = read[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFImageDescription] == nil)
        #expect(exif?[kCGImagePropertyExifUserComment] == nil)
    }

    @Test func unirEnVerticalYHorizontal() async throws {
        let dir = try TempDir()
        let small = try dir.image("a.png", width: 100, height: 50)
        let big = try dir.image("b.png", width: 200, height: 100)
        let vertical = try await StitchImagesAction(direction: .vertical).perform([small, big], output: dir.url)
        #expect(pixelSize(vertical.files[0])! == (200, 200))
        let horizontal = try await StitchImagesAction(direction: .horizontal).perform([small, big], output: dir.url)
        #expect(pixelSize(horizontal.files[0])! == (400, 100))
    }

    @Test func soloAceptaImagenes() throws {
        let dir = try TempDir()
        let text = try dir.file("a.txt")
        let image = try dir.image("a.png", width: 10, height: 10)
        #expect(ResizeImagesAction(mode: .percent(50)).accepts([text]) == false)
        #expect(ResizeImagesAction(mode: .percent(50)).accepts([image]))
        #expect(StitchImagesAction(direction: .vertical).accepts([image]) == false)
    }
}
