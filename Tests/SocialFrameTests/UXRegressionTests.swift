import XCTest
import AppKit
import SocialCore
@testable import SocialFrame

@MainActor
final class UXRegressionTests: XCTestCase {
    private func sample() throws -> URL {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 30,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<300 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for asynchronous operation")
    }

    func testReplacingDirtyPhotoCanBeCancelledAndFailedReplacementPreservesUndo() async throws {
        let url = try sample()
        defer { try? FileManager.default.removeItem(at: url) }
        let model = EditorModel()
        model.open(url)
        try await waitUntil { !model.isLoading }
        XCTAssertFalse(model.hasUnexportedChanges)
        model.rotate()
        let originalDocument = model.document
        let edited = model.edit
        let missing = url.appendingPathExtension("missing")
        model.open(missing)
        XCTAssertEqual(model.pendingImageURL, missing)
        XCTAssertTrue(model.showReplacementConfirmation)
        XCTAssertFalse(model.isLoading)
        model.cancelReplacement()
        XCTAssertNil(model.pendingImageURL)
        XCTAssertEqual(model.edit, edited)
        XCTAssertTrue(model.document === originalDocument)
        model.open(missing)
        model.discardAndOpenPendingImage()
        try await waitUntil { !model.isLoading }
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.document === originalDocument)
        XCTAssertEqual(model.edit, edited)
        XCTAssertTrue(model.hasUnexportedChanges)
        model.undo()
        XCTAssertEqual(model.edit, EditState())
        XCTAssertFalse(model.hasUnexportedChanges)
    }

    func testExportOnlyPreservesTheSnapshotActuallyExported() async throws {
        let source = try sample()
        let output = source.deletingPathExtension().appendingPathExtension("jpg")
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: output) }
        let model = EditorModel()
        model.open(source)
        try await waitUntil { !model.isLoading }
        model.rotate()
        model.export(to: output)
        _ = model.setZoom(2)
        try await waitUntil { !model.isExporting }
        XCTAssertTrue(model.hasUnexportedChanges, "Later edits must still require protection")
        model.undo()
        XCTAssertFalse(model.hasUnexportedChanges)
        model.redo()
        model.export(to: source)
        XCTAssertTrue(model.hasUnexportedChanges, "Failed exports must not mark the session preserved")
        model.export(to: output)
        try await waitUntil { !model.isExporting }
        XCTAssertFalse(model.hasUnexportedChanges)
        model.open(source)
        XCTAssertNil(model.pendingImageURL)
        try await waitUntil { !model.isLoading }
        XCTAssertEqual(model.edit, EditState())
        XCTAssertFalse(model.canUndo)
    }

    func testPreciseAdjustmentsClearStampsOnlyForRealChangesAndUndoRestoresThem() {
        let model = EditorModel()
        model.addClone(source: .init(x: 0.2, y: 0.3), target: .init(x: 0.7, y: 0.6), radius: 0.005)
        let stamped = model.edit
        XCTAssertFalse(model.setZoom(.nan))
        XCTAssertFalse(model.setZoom(1))
        XCTAssertEqual(model.edit, stamped)
        XCTAssertTrue(model.setStraighten(0.3))
        XCTAssertTrue(model.edit.cloneStrokes.isEmpty)
        model.undo()
        XCTAssertEqual(model.edit, stamped)
        _ = model.setZoom(20)
        XCTAssertEqual(model.edit.zoom, 8)
        _ = model.setStraighten(-100)
        XCTAssertEqual(model.edit.straightenDegrees, -45)
        model.undo()
        XCTAssertEqual(model.edit.straightenDegrees, 0)
        XCTAssertEqual(model.edit.zoom, 8)
    }

    func testKeyboardPanIsUndoableWithRotationAndClone() async throws {
        let url = try sample()
        defer { try? FileManager.default.removeItem(at: url) }
        let model = EditorModel()
        model.open(url)
        try await waitUntil { !model.isLoading }
        model.rotate()
        _ = model.setZoom(2)
        model.addClone(source: .init(x: 0.2, y: 0.3), target: .init(x: 0.7, y: 0.6), radius: 0.02)
        let before = model.edit
        model.nudge(horizontal: 0.01, vertical: 0)
        XCTAssertNotEqual(model.edit.panY, before.panY)
        XCTAssertTrue(model.edit.cloneStrokes.isEmpty)
        model.undo()
        XCTAssertEqual(model.edit, before)
        model.gridStyle = .none
        XCTAssertTrue(model.showDestinationGuides, "Safe area visibility is independent from the grid")
    }

    func testSourceClassificationDoesNotImplyAllPresetsWereVerified() {
        for preset in Preset.all {
            XCTAssertFalse(preset.referenceNote.isEmpty)
            if preset.specificationStatus != .practical { XCTAssertNotNil(preset.verifiedOn) }
        }
        XCTAssertNil(Preset.all.first { $0.id == "facebook-post" }!.verifiedOn)
        XCTAssertEqual(Preset.all.first { $0.id == "youtube-profile" }!.specificationStatus, .practical)
        XCTAssertEqual(Preset.all.first { $0.id == "linkedin-profile" }!.specificationStatus, .officialRequirement)
    }

    func testImportBlocksEditingUntilReplacementFinishes() async throws {
        let first = try sample(), second = try sample()
        defer { try? FileManager.default.removeItem(at: first); try? FileManager.default.removeItem(at: second) }
        let model = EditorModel()
        model.open(first)
        try await waitUntil { !model.isLoading }
        model.rotate()
        model.open(second)
        model.discardAndOpenPendingImage()
        XCTAssertTrue(model.isLoading)
        let before = model.edit, previousPreset = model.preset
        XCTAssertFalse(model.canUndo)
        model.rotate(); model.reset(); model.undo(); model.redo()
        _ = model.setZoom(2); _ = model.setStraighten(4)
        model.selectPreset(Preset.all[1])
        model.nudge(horizontal: 0.1, vertical: 0)
        model.pan(from: before, translationX: 0.1, translationY: 0)
        model.addClone(source: .zero, target: .init(x: 0.5, y: 0.5), radius: 0.01)
        XCTAssertEqual(model.edit, before)
        XCTAssertEqual(model.preset, previousPreset)
        try await waitUntil { !model.isLoading }
        XCTAssertEqual(model.sourceURL, second)
        XCTAssertEqual(model.edit, EditState())
    }

    func testNoOpPanPreservesStampsAndUndoHistory() async throws {
        let url = try sample()
        defer { try? FileManager.default.removeItem(at: url) }
        let model = EditorModel()
        model.open(url)
        try await waitUntil { !model.isLoading }
        // Same source/output aspect at zoom 1 leaves no space to pan.
        model.selectPreset(Preset(id: "test", platform: .instagram, name: "Test", width: 40, height: 30))
        model.addClone(source: .init(x: 0.2, y: 0.3), target: .init(x: 0.7, y: 0.6), radius: 0.02)
        let before = model.edit
        model.nudge(horizontal: 0.01, vertical: 0)
        XCTAssertEqual(model.edit, before)
        model.undo()
        XCTAssertTrue(model.edit.cloneStrokes.isEmpty, "No-op pan must not insert a redundant undo step")
    }

    func testReopeningSameURLPublishesANewDocumentGeneration() async throws {
        let url = try sample()
        defer { try? FileManager.default.removeItem(at: url) }
        let model = EditorModel()
        model.open(url)
        try await waitUntil { !model.isLoading }
        let generation = model.documentGeneration
        model.addClone(source: .zero, target: .init(x: 0.5, y: 0.5), radius: 0.01)
        model.open(url)
        model.discardAndOpenPendingImage()
        try await waitUntil { !model.isLoading }
        XCTAssertGreaterThan(model.documentGeneration, generation)
        XCTAssertEqual(model.edit, EditState())
        XCTAssertEqual(model.sourceURL, url)
    }
}
