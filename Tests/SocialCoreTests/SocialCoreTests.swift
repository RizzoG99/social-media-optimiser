import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import SocialCore

final class SocialCoreTests: XCTestCase {
    private func fixture(orientation: Int = 1) throws -> Data {
        let width = 8, height = 4
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let i = (y * width + x) * 4
            pixels[i] = x < width / 2 ? 255 : 0
            pixels[i + 1] = y < height / 2 ? 255 : 0
            pixels[i + 2] = 0
        }}
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                         bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let data = NSMutableData()
        let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cg, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return data as Data
    }

    private func preset(_ w: Int, _ h: Int) -> Preset {
        Preset(id: "test", platform: .instagram, name: "Test", width: w, height: h)
    }

    func testCatalogAndOrientation() throws {
        XCTAssertEqual(Set(Preset.all.map(\.platform)), Set(Platform.allCases))
        XCTAssertEqual(Set(Preset.all.map(\.id)).count, Preset.all.count)
        let document = try ImageDocument(data: fixture(orientation: 6))
        XCTAssertEqual(document.pixelWidth, 4)
        XCTAssertEqual(document.pixelHeight, 8)
    }

    func testRenderExportAndPreview() throws {
        let document = try ImageDocument(data: fixture())
        let renderer = ImageRenderer()
        let edit = EditState(panX: 20, panY: -20, zoom: 1.5, straightenDegrees: 23, quarterTurns: 1)
        let full = try renderer.render(document: document, preset: preset(120, 80), edit: edit)
        let preview = try renderer.render(document: document, preset: preset(120, 80), edit: edit, maxPixelSize: 30)
        XCTAssertEqual(full.width, 120); XCTAssertEqual(full.height, 80)
        XCTAssertEqual(preview.width, 30); XCTAssertEqual(preview.height, 20)
        let bytes = calloc(120 * 80 * 4, 1)!
        defer { free(bytes) }
        let ctx = CGContext(data: bytes, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 480,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(full, in: CGRect(x: 0, y: 0, width: 120, height: 80))
        let p = bytes.bindMemory(to: UInt8.self, capacity: 120 * 80 * 4)
        for i in [0, 119, 79 * 120, 80 * 120 - 1] { XCTAssertEqual(p[i * 4 + 3], 255) }
        for format in [ExportFormat.png, .jpeg(quality: 0.9)] {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: url) }
            try renderer.export(document: document, preset: preset(120, 80), edit: edit, format: format, to: url)
            let exported = try ImageDocument(url: url)
            XCTAssertEqual(exported.pixelWidth, 120); XCTAssertEqual(exported.pixelHeight, 80)
        }
    }

    func testErrorsAndOriginalPreservation() throws {
        XCTAssertThrowsError(try ImageDocument(data: Data()))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = try fixture(); try original.write(to: url)
        let doc = try ImageDocument(url: url), renderer = ImageRenderer()
        XCTAssertThrowsError(try renderer.render(document: doc, preset: preset(0, 10), edit: .init()))
        XCTAssertThrowsError(try renderer.render(document: doc, preset: preset(10, 10), edit: .init(zoom: .nan)))
        XCTAssertThrowsError(try renderer.export(document: doc, preset: preset(10, 10), edit: .init(), format: .png, to: url))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    private func rgba(_ image: CGImage) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
        result.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress!, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return result
    }

    func testAllOrientationsAndClonePixels() throws {
        for orientation in 1...8 {
            let doc = try ImageDocument(data: fixture(orientation: orientation))
            XCTAssertEqual(doc.pixelWidth, orientation >= 5 ? 4 : 8)
            XCTAssertEqual(doc.pixelHeight, orientation >= 5 ? 8 : 4)
        }
        let doc = try ImageDocument(data: fixture()), renderer = ImageRenderer()
        let size = preset(160, 80)
        let before = rgba(try renderer.render(document: doc, preset: size, edit: .init()))
        let stroke = CloneStroke(sourceX: 0.25, sourceY: 0.5, targetX: 0.75, targetY: 0.5, radius: 0.3)
        let after = rgba(try renderer.render(document: doc, preset: size, edit: .init(cloneStrokes: [stroke])))
        let target = (40 * 160 + 120) * 4
        XCTAssertGreaterThan(after[target], before[target] + 100)
        XCTAssertEqual(after[target + 3], 255)
        let preview = try renderer.render(document: doc, preset: size, edit: .init(cloneStrokes: [stroke]), maxPixelSize: 80)
        let previewPixels = rgba(preview)
        let previewTarget = (20 * 80 + 60) * 4
        XCTAssertEqual(Int(previewPixels[previewTarget]), Int(after[target]), accuracy: 8)
    }

    func testPanHelperRotationAndHardlinkProtection() throws {
        let doc = try ImageDocument(data: fixture()), renderer = ImageRenderer()
        let moved = try renderer.panned(document: doc, preset: preset(100, 100),
                                        edit: .init(zoom: 2, quarterTurns: 1), translationX: 0.1, translationY: 0)
        XCTAssertEqual(moved.panX, 0, accuracy: 0.00001)
        XCTAssertGreaterThan(moved.panY, 0)
        let original = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let alias = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: alias); try? FileManager.default.removeItem(at: original) }
        try fixture().write(to: original)
        try FileManager.default.linkItem(at: original, to: alias)
        let fileDoc = try ImageDocument(url: original)
        XCTAssertThrowsError(try renderer.export(document: fileDoc, preset: preset(10, 10), edit: .init(), format: .png, to: alias))
    }

    func testEveryPresetExportTypeSizeAndProfile() throws {
        let input = try fixture()
        let doc = try ImageDocument(data: input), renderer = ImageRenderer()
        for preset in Preset.all {
            for (format, type) in [(ExportFormat.png, UTType.png), (.jpeg(quality: 0.85), UTType.jpeg)] {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: url) }
                try renderer.export(document: doc, preset: preset, edit: .init(), format: format, to: url)
                let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
                XCTAssertEqual(CGImageSourceGetType(source) as String?, type.identifier, preset.id)
                let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
                XCTAssertEqual(image.width, preset.width, preset.id)
                XCTAssertEqual(image.height, preset.height, preset.id)
                XCTAssertEqual(image.colorSpace?.model, .rgb, preset.id)
                XCTAssertNotNil(image.colorSpace?.copyICCData(), preset.id)
            }
        }
        XCTAssertEqual(try fixture(), input)
    }

    func testExifOrientationPixelMapping() throws {
        let renderer = ImageRenderer()
        let base = rgba(try renderer.render(document: ImageDocument(data: fixture()), preset: preset(8, 4), edit: .init()))
        for orientation in 1...8 {
            let swapped = orientation >= 5
            let w = swapped ? 4 : 8, h = swapped ? 8 : 4
            let actual = rgba(try renderer.render(document: ImageDocument(data: fixture(orientation: orientation)), preset: preset(w, h), edit: .init()))
            for y in 0..<h { for x in 0..<w {
                let source: (Int, Int)
                switch orientation {
                case 2: source = (7-x, y)
                case 3: source = (7-x, 3-y)
                case 4: source = (x, 3-y)
                case 5: source = (y, x)
                case 6: source = (y, 3-x)
                case 7: source = (7-y, 3-x)
                case 8: source = (7-y, x)
                default: source = (x, y)
                }
                let a = (y*w+x)*4, b = (source.1*8+source.0)*4
                for channel in 0..<3 {
                    XCTAssertEqual(Int(actual[a+channel]), Int(base[b+channel]), accuracy: 2, "orientation \(orientation), (\(x),\(y))")
                }
            }}
        }
    }

    func testSolidColorCoversCornersAtRotationsAndExtremePan() throws {
        let width = 24, height = 16
        let rgbaBytes = Array(repeating: [UInt8](arrayLiteral: 35, 110, 200, 255), count: width * height).flatMap { $0 }
        let provider = CGDataProvider(data: Data(rgbaBytes) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let data = NSMutableData(), destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let doc = try ImageDocument(data: data as Data), renderer = ImageRenderer()
        for degrees in [0.0, -45, 45] { for turns in 0...3 { for pan in [-100.0, 100] {
            let pixels = rgba(try renderer.render(document: doc, preset: preset(80, 60), edit: .init(panX: pan, panY: -pan, zoom: 1.2, straightenDegrees: degrees, quarterTurns: turns)))
            for pixel in [0, 79, 59*80, 60*80-1] { for channel in 0..<3 {
                XCTAssertEqual(Int(pixels[pixel*4+channel]), Int(rgbaBytes[channel]), accuracy: 3,
                               "angle \(degrees), turns \(turns), pan \(pan)")
            }}
        }}}
    }

}
