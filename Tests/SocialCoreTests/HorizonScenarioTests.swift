import XCTest
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import SocialCore

final class HorizonScenarioTests: XCTestCase {
    /// Measures the actual sky/sea edge in rendered pixels, independently of Vision.
    private func measuredTilt(_ image: CGImage) throws -> Double {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        func edge(at x: Int) -> Int {
            let range = (height / 4)..<(height * 3 / 4)
            return range.max { a, b in
                func contrast(_ y: Int) -> Int {
                    let lower = ((y - 2) * width + x) * 4
                    let upper = ((y + 2) * width + x) * 4
                    return abs(Int(pixels[upper]) - Int(pixels[lower]))
                }
                return contrast(a) < contrast(b)
            }!
        }
        let x1 = width / 4, x2 = width * 3 / 4
        return atan2(Double(edge(at: x2) - edge(at: x1)), Double(x2 - x1)) * 180 / .pi
    }

    func testOpeningAnAlreadyTiltedImageThenAutoLeveling() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "horizon-level", withExtension: "png", subdirectory: "Fixtures"))
        let original = try ImageDocument(url: url)
        let preset = Preset(id: "horizon", platform: .instagram, name: "Test", width: 1024, height: 768)
        let renderer = ImageRenderer()
        for angle in [-8.0, 8.0] {
            let tilted = try renderer.render(document: original, preset: preset, edit: .init(straightenDegrees: angle))
            let data = NSMutableData()
            let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, tilted, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
            // A fresh import has no knowledge of the rotation used to create it.
            let imported = try ImageDocument(data: data as Data)
            let suggestion = try XCTUnwrap(try AutoLevelEstimator().estimate(document: imported, preset: preset, edit: .init()))
            let corrected = EditState(straightenDegrees: suggestion.straightenDegrees)
            let after = try renderer.render(document: imported, preset: preset, edit: corrected)
            let measured = abs(try measuredTilt(after))
            XCTAssertLessThan(measured, 1.5)
            XCTAssertGreaterThan(abs(try measuredTilt(tilted)), 6)
            if let folder = ProcessInfo.processInfo.environment["SOCIALFRAME_FIXTURE_OUTPUT"] {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: folder), withIntermediateDirectories: true)
                let suffix = angle < 0 ? "minus8" : "plus8"
                try renderer.export(document: imported, preset: preset, edit: corrected, format: .png,
                    to: URL(fileURLWithPath: folder).appendingPathComponent("horizon-\(suffix)-after-import.png"))
            }
            print("Imported tilted image \(angle)°: corrected residual \(measured)°")
        }
    }

    func testRefinementRequiresAStrongNearHorizontalEdge() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "horizon-level", withExtension: "png", subdirectory: "Fixtures"))
        let doc = try ImageDocument(url: url)
        let preset = Preset(id: "horizon", platform: .instagram, name: "Test", width: 1024, height: 768)
        let renderer = ImageRenderer()
        let level = try renderer.render(document: doc, preset: preset, edit: .init())
        XCTAssertEqual(try XCTUnwrap(HorizonRefinement.residualDegrees(in: level)), 0, accuracy: 0.2)
        let steep = try renderer.render(document: doc, preset: preset, edit: .init(straightenDegrees: 10))
        XCTAssertNil(HorizonRefinement.residualDegrees(in: steep))
        let blank = CIContext().createCGImage(CIImage(color: .white), from: CGRect(x: 0, y: 0, width: 256, height: 256))!
        XCTAssertNil(HorizonRefinement.residualDegrees(in: blank))
    }

    func testAutoLevelReducesKnownTiltInBothDirections() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "horizon-level", withExtension: "png", subdirectory: "Fixtures"))
        let doc = try ImageDocument(url: url)
        let preset = Preset(id: "horizon", platform: .instagram, name: "Test orizzonte", width: 1024, height: 768)
        let renderer = ImageRenderer()
        let estimator = AutoLevelEstimator()
        for angle in [-8.0, 8.0] {
            let initial = EditState(straightenDegrees: angle)
            let before = try renderer.render(document: doc, preset: preset, edit: initial)
            let measuredBefore = abs(try measuredTilt(before))
            XCTAssertGreaterThan(measuredBefore, 6, "Fixture must actually be tilted")
            let suggestion = try XCTUnwrap(try estimator.estimate(document: doc, preset: preset, edit: initial), "Known tilted horizon should be recognized")
            var corrected = initial
            corrected.straightenDegrees = suggestion.straightenDegrees
            let after = try renderer.render(document: doc, preset: preset, edit: corrected)
            let measuredAfter = abs(try measuredTilt(after))
            print("AutoLevel fixture \(angle)°: before \(measuredBefore)°, after \(measuredAfter)°")
            XCTAssertLessThan(measuredAfter, 1.5, "Rendered horizon should become level (initial \(angle)°, suggested \(suggestion.straightenDegrees)°)")
            XCTAssertLessThan(measuredAfter, measuredBefore / 2)
            if let folder = ProcessInfo.processInfo.environment["SOCIALFRAME_FIXTURE_OUTPUT"] {
                let target = URL(fileURLWithPath: folder, isDirectory: true)
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                let suffix = angle < 0 ? "minus8" : "plus8"
                try renderer.export(document: doc, preset: preset, edit: initial, format: .png, to: target.appendingPathComponent("horizon-\(suffix)-before.png"))
                try renderer.export(document: doc, preset: preset, edit: corrected, format: .png, to: target.appendingPathComponent("horizon-\(suffix)-after.png"))
            }
        }
    }
}
