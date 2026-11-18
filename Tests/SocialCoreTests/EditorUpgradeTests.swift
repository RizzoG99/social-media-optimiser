import XCTest
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import SocialCore

final class EditorUpgradeTests: XCTestCase {
    private func document() throws -> ImageDocument {
        let rect = CGRect(x: 0, y: 0, width: 128, height: 128)
        let gradient = CIFilter(name: "CILinearGradient", parameters: ["inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 128, y: 128), "inputColor0": CIColor(red: 0.2, green: 0.2, blue: 0.2), "inputColor1": CIColor(red: 0.8, green: 0.8, blue: 0.8)])!.outputImage!.cropped(to: rect)
        let image = CIContext().createCGImage(gradient, from: rect)!
        let data = NSMutableData()
        let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil); XCTAssertTrue(CGImageDestinationFinalize(dest))
        return try ImageDocument(data: data as Data)
    }
    private let preset = Preset(id: "test", platform: .instagram, name: "Test", width: 128, height: 128)
    private func pixel(_ image: CGImage, x: Int, y: Int) -> Int {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { b in
            let c = CGContext(data: b.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return Int(bytes[(y * image.width + x) * 4])
    }
    func testOffCenterCropMatchesSelectedPixelsWithRotations() throws {
        let doc = try document(), renderer = ImageRenderer()
        for turns in 0..<4 {
            let original = EditState(straightenDegrees: 12, quarterTurns: turns)
            let full = try renderer.render(document: doc, preset: preset, edit: original)
            let edit = try renderer.cropped(document: doc, preset: preset, edit: original, rect: CGRect(x: 0.5, y: 0.25, width: 0.5, height: 0.5))
            let result = try renderer.render(document: doc, preset: preset, edit: edit)
            // Center of the selected region is at (96,64), not image center.
            XCTAssertEqual(pixel(result, x: 64, y: 64), pixel(full, x: 96, y: 64), accuracy: 2)
        }
    }
    func testCropRejectsInvalidSelections() throws {
        let doc = try document(), renderer = ImageRenderer()
        for rect in [CGRect(x: -0.1, y: 0, width: 0.5, height: 0.5), CGRect(x: 0, y: 0, width: 0, height: 0), CGRect(x: 0, y: 0, width: 0.5, height: 0.4), CGRect(x: 0, y: 0, width: 0.01, height: 0.01)] {
            XCTAssertThrowsError(try renderer.cropped(document: doc, preset: preset, edit: .init(), rect: rect))
        }
    }
    func testWiderCropContextRoundTripsExistingComposition() throws {
        let doc = try document(), renderer = ImageRenderer()
        for turns in 0..<4 {
            let edit = EditState(panX: 0.12, panY: -0.07, zoom: 2.5, straightenDegrees: 17, quarterTurns: turns)
            let context = try renderer.cropContext(document: doc, preset: preset, edit: edit)
            XCTAssertLessThan(context.edit.zoom, edit.zoom)
            let restored = try renderer.cropped(document: doc, preset: preset, edit: context.edit, rect: context.selection)
            let before = try renderer.render(document: doc, preset: preset, edit: edit)
            let after = try renderer.render(document: doc, preset: preset, edit: restored)
            for x in [10, 64, 110] { for y in [10, 64, 110] {
                XCTAssertEqual(pixel(before, x: x, y: y), pixel(after, x: x, y: y), accuracy: 1)
            } }
        }
    }
    /// Regressione: con un raddrizzamento anche minimo e l'inquadratura contro un bordo,
    /// il contesto del ritaglio ripiegava sull'inquadratura stessa senza margini attorno.
    func testCropContextStaysWiderWithSmallStraightenAgainstEdges() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/horizon-level.png")
        let doc = try ImageDocument(url: url), renderer = ImageRenderer()
        let portrait = Preset(id: "portrait", platform: .instagram, name: "Portrait", width: 1080, height: 1350)
        for degrees in [0.1, 1, 5] { for (px, py) in [(0.0, 1.0), (0.0, -1.0), (1.0, 0.0), (-1.0, 0.0), (0.0, 0.0)] {
            let edit = try renderer.panned(document: doc, preset: portrait, edit: EditState(panX: px, panY: py, zoom: 1.65, straightenDegrees: degrees), translationX: 0, translationY: 0)
            let context = try renderer.cropContext(document: doc, preset: portrait, edit: edit)
            let label = "\(degrees)° pan (\(px), \(py))"
            XCTAssertLessThan(context.edit.zoom, edit.zoom * 0.9, label)
            let restored = try renderer.cropped(document: doc, preset: portrait, edit: context.edit, rect: context.selection)
            XCTAssertEqual(restored.zoom, edit.zoom, accuracy: 1e-6, label)
            XCTAssertEqual(restored.panX, edit.panX, accuracy: 1e-6, label)
            XCTAssertEqual(restored.panY, edit.panY, accuracy: 1e-6, label)
        } }
        // Inquadrature interne: il contesto resta l'intera vista a zoom 1, come prima della correzione.
        for degrees in [0.0, 0.1, 1, 5] { for (px, py) in [(0.05, 0.05), (0.0, 0.1), (-0.05, 0.08)] {
            let edit = EditState(panX: px, panY: py, zoom: 1.65, straightenDegrees: degrees)
            let context = try renderer.cropContext(document: doc, preset: portrait, edit: edit)
            XCTAssertEqual(context.edit.zoom, 1, accuracy: 1e-9, "\(degrees)° pan (\(px), \(py))")
        } }
    }
    func testSharpeningPreservesGeometryAndChangesEdgePixels() throws {
        let doc = try document(), renderer = ImageRenderer()
        let original = try renderer.render(document: doc, preset: preset, edit: .init())
        var edit = EditState(); edit.outputSharpening = .high
        let sharp = try renderer.render(document: doc, preset: preset, edit: edit)
        XCTAssertEqual(original.width, sharp.width); XCTAssertEqual(original.height, sharp.height)
        XCTAssertNotEqual(original.dataProvider!.data! as Data, sharp.dataProvider!.data! as Data)
        XCTAssertEqual(pixel(original, x: 64, y: 64), pixel(sharp, x: 64, y: 64), accuracy: 2)
    }
}
