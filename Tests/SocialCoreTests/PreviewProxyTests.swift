import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import SocialCore

/// Il proxy accelera l'anteprima delle foto grandi senza cambiare geometria né export (ADR-015).
final class PreviewProxyTests: XCTestCase {
    private enum Pattern { case gradient, stripes }

    private func document(width: Int, height: Int, _ pattern: Pattern, preparesForEditing: Bool = true) throws -> ImageDocument {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let pixels = context.data!.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
        for y in 0..<height { for x in 0..<width {
            let o = y * context.bytesPerRow + x * 4
            switch pattern {
            case .gradient:
                pixels[o] = UInt8(x * 255 / width); pixels[o + 1] = UInt8(y * 255 / height); pixels[o + 2] = 90
            case .stripes:
                let v: UInt8 = x % 2 == 0 ? 20 : 235
                pixels[o] = v; pixels[o + 1] = v; pixels[o + 2] = v
            }
            pixels[o + 3] = 255
        }}
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return try ImageDocument(data: data as Data, preparesForEditing: preparesForEditing)
    }

    private func bytes(_ image: CGImage) -> [UInt8] {
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Array(UnsafeBufferPointer(start: context.data!.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4),
                                         count: image.width * image.height * 4))
    }

    private func meanDifference(_ a: CGImage, _ b: CGImage) -> Double {
        let x = bytes(a), y = bytes(b)
        return zip(x, y).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(x.count)
    }

    private let portrait = Preset.all.first { $0.id == "instagram-portrait" } ?? Preset.all[0]

    func testProxyExistsOnlyAboveItsSide() throws {
        XCTAssertFalse(try document(width: 3000, height: 2000, .gradient).hasProxy, "Già entro il lato del proxy")
        let large = try document(width: 3200, height: 2400, .gradient)
        XCTAssertTrue(large.hasProxy)
        XCTAssertEqual(large.proxyDensity, 3072.0 / 3200, accuracy: 0.001)
        XCTAssertEqual(large.pixelWidth, 3200, "Le dimensioni dichiarate restano quelle dell'originale")
        // Le miniature del set non preparano l'editing: nessun proxy da costruire e scartare.
        let thumbnailOnly = try document(width: 3200, height: 2400, .gradient, preparesForEditing: false)
        XCTAssertFalse(thumbnailOnly.hasProxy)
        XCTAssertEqual(thumbnailOnly.pixelWidth, 3200)
    }

    func testPreviewUsesProxyWithSameGeometryAndOriginalWhenZoomed() throws {
        let document = try document(width: 3200, height: 2400, .gradient)
        let renderer = ImageRenderer()
        var edit = EditState(); edit.panX = 0.1
        // Zoom 1: servono circa 0,56 px per pixel sorgente, il proxy ne ha 0,96.
        XCTAssertTrue(ImageRenderer.source(for: document, density: 0.56) === document.proxy)
        let proxied = try renderer.render(document: document, preset: portrait, edit: edit, maxPixelSize: 1400, allowProxy: true)
        let original = try renderer.render(document: document, preset: portrait, edit: edit, maxPixelSize: 1400)
        XCTAssertEqual(proxied.width, original.width); XCTAssertEqual(proxied.height, original.height)
        XCTAssertLessThan(meanDifference(proxied, original), 1.5, "Stessa inquadratura: un errore di geometria sposterebbe il gradiente")
        // Zoom 4: la densità richiesta supera il proxy, l'anteprima torna all'originale.
        edit.zoom = 4
        XCTAssertTrue(ImageRenderer.source(for: document, density: 2.25) === document.image)
        let zoomedProxy = try renderer.render(document: document, preset: portrait, edit: edit, maxPixelSize: 1400, allowProxy: true)
        let zoomedOriginal = try renderer.render(document: document, preset: portrait, edit: edit, maxPixelSize: 1400)
        XCTAssertEqual(bytes(zoomedProxy), bytes(zoomedOriginal))
    }

    func testExportNeverUsesProxy() throws {
        // Righe di un pixel: il proxy le fonde in grigio, l'originale no.
        let document = try document(width: 3200, height: 2400, .stripes)
        let renderer = ImageRenderer()
        let edit = EditState()
        let proxied = try renderer.render(document: document, preset: portrait, edit: edit, allowProxy: true)
        let original = try renderer.render(document: document, preset: portrait, edit: edit)
        XCTAssertGreaterThan(meanDifference(proxied, original), 2, "Il campione deve distinguere proxy e originale")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        try renderer.export(document: document, preset: portrait, edit: edit, format: .png, to: url)
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let exported = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertLessThan(meanDifference(exported, original), 0.5)
        XCTAssertGreaterThan(meanDifference(exported, proxied), 2)
    }
}
