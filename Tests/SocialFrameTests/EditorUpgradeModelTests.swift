import XCTest
import SocialCore
@testable import SocialFrame

@MainActor
final class EditorUpgradeModelTests: XCTestCase {
    func testEnglishResourcesMatchItalianKeysAndFormatArguments() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let pattern = try NSRegularExpression(pattern: "%(@|[0-9.]*[df]|%)")
        func arguments(_ text: String) -> [String] {
            let string = text as NSString
            return pattern.matches(in: text, range: NSRange(location: 0, length: string.length)).map { string.substring(with: $0.range) }
        }
        for target in ["SocialFrame", "SocialCore"] {
            func strings(_ language: String) throws -> [String: String] {
                let url = root.appendingPathComponent("Sources/\(target)/Resources/\(language).lproj/Localizable.strings")
                return try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
            }
            let italian = try strings("it"), english = try strings("en")
            XCTAssertEqual(Set(italian.keys), Set(english.keys))
            for key in italian.keys { XCTAssertEqual(arguments(italian[key]!), arguments(english[key]!), key) }
        }
    }
    /// Regressione: un passo di Livella durante il ritaglio azzerava la selezione trascinata.
    func testStraightenDuringCropKeepsDraggedSelection() async throws {
        let model = EditorModel()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        model.open(root.appendingPathComponent("SocialCoreTests/Fixtures/horizon-level.png"))
        for _ in 0..<500 {
            if model.document != nil && !model.isLoading { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let document = try XCTUnwrap(model.document)
        model.setZoom(1.65)
        model.beginCrop()
        let initial = model.cropSelection
        // Selezione trascinata: angolo in basso a sinistra fermo, lato ridotto del 30%.
        let dragged = CGRect(x: initial.minX, y: initial.minY, width: initial.width * 0.7, height: initial.height * 0.7)
        let target = try XCTUnwrap(model.cropTarget(for: dragged))
        XCTAssertTrue(model.setStraighten(0.1))
        model.cancelCrop()
        model.beginCrop(keeping: target)
        XCTAssertLessThan(model.cropSelection.width, 0.99, "il contesto deve restare più ampio dell'inquadratura")
        model.applyCrop(model.cropSelection)
        let expected = try ImageRenderer().panned(document: document, preset: model.preset,
            edit: EditState(panX: target.panX, panY: target.panY, zoom: target.zoom, straightenDegrees: 0.1), translationX: 0, translationY: 0)
        XCTAssertEqual(model.edit.straightenDegrees, 0.1, accuracy: 1e-9)
        XCTAssertEqual(model.edit.zoom, expected.zoom, accuracy: 1e-6)
        XCTAssertEqual(model.edit.panX, expected.panX, accuracy: 1e-6)
        XCTAssertEqual(model.edit.panY, expected.panY, accuracy: 1e-6)
    }
    func testCropCancelAndUndoPreserveStampsAndSharpeningIsNonGeometric() async throws {
        let model = EditorModel()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        model.open(root.appendingPathComponent("SocialCoreTests/Fixtures/horizon-level.png"))
        for _ in 0..<500 {
            if model.document != nil && !model.isLoading { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(model.document)
        model.addClone(source: CGPoint(x: 0.3, y: 0.3), target: CGPoint(x: 0.6, y: 0.6), radius: 0.04)
        let stamped = model.edit
        model.beginCrop(); model.cancelCrop()
        XCTAssertEqual(model.edit, stamped)
        model.beginCrop()
        model.applyCrop(CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        XCTAssertTrue(model.edit.cloneStrokes.isEmpty)
        XCTAssertEqual(model.edit.zoom, 2)
        model.undo(); XCTAssertEqual(model.edit, stamped)
        model.redo(); XCTAssertEqual(model.edit.zoom, 2)
        model.undo()
        model.setSharpening(.standard)
        XCTAssertEqual(model.edit.cloneStrokes, stamped.cloneStrokes)
        XCTAssertEqual(model.edit.outputSharpening, .standard)
        model.undo(); XCTAssertEqual(model.edit, stamped)
        let dirty = model.hasUnexportedChanges
        model.fullResolutionPreview = true
        XCTAssertEqual(model.edit, stamped)
        XCTAssertEqual(model.hasUnexportedChanges, dirty)
    }
}
