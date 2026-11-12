import XCTest
import SocialCore
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import SocialFrame

@MainActor
final class EditorModelTests: XCTestCase {
    func testImportPreviewEditExportAndFailedImportPreservesPhoto() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: output) }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 24, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        let pixels = bitmap.bitmapData!
        for y in 0..<24 { for x in 0..<32 {
            let offset = y * bitmap.bytesPerRow + x * 4
            pixels[offset] = 30; pixels[offset + 1] = 150
            pixels[offset + 2] = 180; pixels[offset + 3] = 255
        }}
        let data = bitmap.representation(using: .png, properties: [:])!
        try data.write(to: source)
        let model = EditorModel()
        model.open(source)
        for _ in 0..<150 {
            if !model.isLoading && model.preview != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(model.isLoading)
        XCTAssertNotNil(model.preview)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.document?.pixelWidth, 32)
        model.rotate()
        model.export(to: output)
        for _ in 0..<150 {
            if !model.isExporting { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNil(model.errorMessage)
        let exported = try ImageDocument(url: output)
        XCTAssertEqual(exported.pixelWidth, model.preset.width)
        XCTAssertEqual(exported.pixelHeight, model.preset.height)
        XCTAssertEqual(try Data(contentsOf: source), data)
        model.open(source.appendingPathExtension("missing"))
        for _ in 0..<150 {
            if !model.isLoading { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.sourceURL, source)
        XCTAssertEqual(model.document?.pixelWidth, 32)
    }

    func testCropUndoRedoAndNewEditInvalidatesRedo() {
        let model = EditorModel()
        let original = model.edit
        model.checkpoint()
        model.edit.zoom = 2
        model.checkpoint()
        model.edit.straightenDegrees = 7
        model.undo()
        XCTAssertEqual(model.edit.zoom, 2)
        XCTAssertEqual(model.edit.straightenDegrees, 0)
        model.undo()
        XCTAssertEqual(model.edit, original)
        XCTAssertFalse(model.canUndo)
        model.redo()
        XCTAssertEqual(model.edit.zoom, 2)
        model.rotate()
        XCTAssertFalse(model.canRedo)
        XCTAssertEqual(model.edit.quarterTurns, 1)
    }

    func testCloneCanBeUndoneAndRotationClearsClones() {
        let model = EditorModel()
        model.addClone(source: .init(x: 0.2, y: 0.3), target: .init(x: 0.7, y: 0.6), radius: 0.05)
        XCTAssertEqual(model.edit.cloneStrokes.count, 1)
        model.rotate()
        XCTAssertTrue(model.edit.cloneStrokes.isEmpty)
        model.undo()
        XCTAssertEqual(model.edit.cloneStrokes.count, 1)
        XCTAssertEqual(model.edit.quarterTurns, 0)
        model.undo()
        XCTAssertTrue(model.edit.cloneStrokes.isEmpty)
        model.redo()
        XCTAssertEqual(model.edit.cloneStrokes.count, 1)
    }

    func testResetRestoresAllAdjustmentsAndCanBeUndone() {
        let model = EditorModel()
        model.checkpoint()
        model.edit.zoom = 3
        model.edit.panX = 0.2
        model.edit.straightenDegrees = -12
        model.rotate()
        let edited = model.edit
        model.reset()
        XCTAssertEqual(model.edit, EditState())
        model.undo()
        XCTAssertEqual(model.edit, edited)
    }

    func testPresetChangeClearsCloneAndUndoRestoresBoth() {
        let model = EditorModel()
        let previous = model.preset
        model.addClone(source: .init(x: 0.2, y: 0.3), target: .init(x: 0.7, y: 0.6), radius: 0.05)
        model.selectPreset(Preset.all[1])
        XCTAssertTrue(model.edit.cloneStrokes.isEmpty)
        XCTAssertEqual(model.preset, Preset.all[1])
        model.undo()
        XCTAssertEqual(model.preset, previous)
        XCTAssertEqual(model.edit.cloneStrokes.count, 1)
        model.redo()
        XCTAssertEqual(model.preset, Preset.all[1])
        XCTAssertTrue(model.edit.cloneStrokes.isEmpty)
    }

    func testRepeatedCheckpointDoesNotCreateDuplicateUndoSteps() {
        let model = EditorModel()
        model.checkpoint(); model.checkpoint()
        model.edit.zoom = 1.5
        model.undo()
        XCTAssertEqual(model.edit.zoom, 1)
        XCTAssertFalse(model.canUndo)
    }
}
