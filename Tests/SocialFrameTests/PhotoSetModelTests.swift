import XCTest
import AppKit
import SocialCore
@testable import SocialFrame

/// Set di foto e pellicola (F-11…F-13). Test del modello, non XCUITest.
@MainActor
final class PhotoSetModelTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("photoset-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    @discardableResult
    private func sample(_ name: String, width: Int = 40, height: Int = 30, in directory: URL? = nil) throws -> URL {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let url = (directory ?? folder).appendingPathComponent(name)
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for asynchronous operation")
    }

    private func settled(_ model: EditorModel) async throws {
        try await waitUntil { !model.isLoading && !model.isImporting && !model.isExporting }
    }

    private func loadedSet(_ names: [String]) async throws -> (EditorModel, [URL]) {
        let urls = try names.map { try sample($0) }
        let model = EditorModel()
        model.open(urls)
        try await settled(model)
        return (model, urls)
    }

    func testImportsSeveralPhotosWithThumbnailsAndSelectsTheFirst() async throws {
        let (model, urls) = try await loadedSet(["a.png", "b.png", "c.png"])
        XCTAssertEqual(model.items.map(\.url), urls)
        XCTAssertEqual(model.sourceURL, urls[0])
        XCTAssertEqual(model.selectedIndex, 0)
        XCTAssertTrue(model.items.allSatisfy { $0.thumbnail != nil })
        XCTAssertNil(model.errorMessage)
    }

    func testAddingSkipsDuplicatesAndSymlinksToFilesAlreadyInTheSet() async throws {
        let (model, urls) = try await loadedSet(["a.png", "b.png"])
        let link = folder.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: urls[1])
        let extra = try sample("c.png")
        model.open([urls[0], link, extra])
        XCTAssertTrue(model.showImportChoice)
        model.addPendingImport()
        try await settled(model)
        XCTAssertEqual(model.items.map(\.url), urls + [extra])
        XCTAssertEqual(model.sourceURL, extra, "The first new photo becomes active")
    }

    func testFolderImportIsNotRecursiveAndIgnoresOtherFiles() async throws {
        let library = folder.appendingPathComponent("library")
        let nested = library.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try sample("2.png", in: library)
        try sample("10.png", in: library)
        try sample("deep.png", in: nested)
        try Data("not an image".utf8).write(to: library.appendingPathComponent("notes.txt"))
        let model = EditorModel()
        model.open([library])
        try await settled(model)
        XCTAssertEqual(model.items.map(\.url.lastPathComponent), ["2.png", "10.png"], "Finder order, top level only")
    }

    func testReplacingTheSetAndUnreadableFilesInABatch() async throws {
        let (model, _) = try await loadedSet(["a.png", "b.png"])
        let replacement = try sample("c.png")
        let broken = folder.appendingPathComponent("broken.png")
        try Data("broken".utf8).write(to: broken)
        model.open([broken, replacement])
        model.replaceSetWithPendingImport()
        try await settled(model)
        XCTAssertEqual(model.items.map(\.url), [replacement])
        XCTAssertEqual(model.sourceURL, replacement)
        XCTAssertNotNil(model.errorMessage, "Skipped files are reported")
    }

    func testSwitchingPhotosKeepsEditsPresetAndHistoryOfEach() async throws {
        let (model, urls) = try await loadedSet(["a.png", "b.png", "c.png"])
        let story = Preset.all.first { $0.id != model.preset.id }!
        model.rotate()
        model.selectPreset(story)
        let firstEdit = model.edit
        model.select(model.items[2].id)
        try await settled(model)
        XCTAssertEqual(model.sourceURL, urls[2])
        XCTAssertEqual(model.edit, EditState())
        XCTAssertFalse(model.canUndo, "Each photo has its own history")
        XCTAssertNotEqual(model.preset, story, "New photos keep the preset chosen at import")
        _ = model.setZoom(2)
        model.selectPrevious()
        try await settled(model)
        XCTAssertEqual(model.sourceURL, urls[1])
        model.selectPrevious()
        try await settled(model)
        XCTAssertEqual(model.sourceURL, urls[0])
        XCTAssertEqual(model.edit, firstEdit)
        XCTAssertEqual(model.preset, story)
        model.undo()
        XCTAssertNotEqual(model.preset, story, "Undo restores the preset of this photo")
        model.undo()
        XCTAssertEqual(model.edit, EditState())
        model.redo()
        model.select(model.items[2].id)
        try await settled(model)
        XCTAssertEqual(model.edit.zoom, 2)
        model.undo()
        XCTAssertEqual(model.edit.zoom, 1)
    }

    func testRapidSelectionShowsOnlyTheLastRequestedPhoto() async throws {
        let (model, urls) = try await loadedSet(["a.png", "b.png", "c.png"])
        model.select(model.items[1].id)
        model.select(model.items[2].id)
        XCTAssertTrue(model.isLoading)
        model.rotate()
        XCTAssertEqual(model.edit, EditState(), "Editing waits for the photo to open")
        try await settled(model)
        XCTAssertEqual(model.sourceURL, urls[2])
        XCTAssertEqual(model.selectedIndex, 2)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.sourceURL, urls[2])
    }

    func testNavigationStopsAtTheEdges() async throws {
        let (model, _) = try await loadedSet(["a.png", "b.png"])
        XCTAssertFalse(model.canSelectPrevious)
        XCTAssertTrue(model.canSelectNext)
        model.selectPrevious()
        XCTAssertFalse(model.isLoading)
        model.selectNext()
        try await settled(model)
        XCTAssertEqual(model.selectedIndex, 1)
        XCTAssertFalse(model.canSelectNext)
    }

    func testStatusBadgesFollowEditsAndExports() async throws {
        let (model, _) = try await loadedSet(["a.png", "b.png"])
        let first = model.items[0].id
        func status() -> PhotoStatus { model.photoStatus(of: model.items.first { $0.id == first }!) }
        XCTAssertEqual(status(), .unedited)
        model.rotate()
        XCTAssertEqual(status(), .edited)
        XCTAssertTrue(model.hasUnexportedItems)
        let output = folder.appendingPathComponent("out.jpg")
        model.export(to: output)
        try await settled(model)
        XCTAssertEqual(status(), .exported)
        XCTAssertFalse(model.hasUnexportedItems)
        model.select(model.items[1].id)
        try await settled(model)
        XCTAssertEqual(status(), .exported, "Status survives switching photo")
        model.selectPrevious()
        try await settled(model)
        model.rotate()
        XCTAssertEqual(status(), .edited)
        model.undo()
        XCTAssertEqual(status(), .exported)
    }

    func testRemovingPhotosSelectsANeighbourAndConfirmsUnexportedEdits() async throws {
        let (model, urls) = try await loadedSet(["a.png", "b.png", "c.png"])
        model.rotate()
        model.requestRemoval(of: model.items[0].id)
        XCTAssertTrue(model.showRemovalConfirmation)
        model.cancelRemoval()
        XCTAssertEqual(model.items.count, 3)
        model.requestRemoval(of: model.items[0].id)
        model.confirmRemoval()
        try await settled(model)
        XCTAssertEqual(model.items.map(\.url), Array(urls[1...]))
        XCTAssertEqual(model.sourceURL, urls[1])
        XCTAssertEqual(model.edit, EditState())
        XCTAssertTrue(FileManager.default.fileExists(atPath: urls[0].path), "The file on disk is untouched")
        model.requestRemoval(of: model.items[1].id)
        XCTAssertFalse(model.showRemovalConfirmation, "Unedited photos are removed directly")
        XCTAssertEqual(model.sourceURL, urls[1])
        model.remove(model.items[0].id)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNil(model.document)
        XCTAssertNil(model.sourceURL)
    }

    func testExportPlanAddsSuffixesAndNeverTargetsOriginals() {
        let folder = URL(fileURLWithPath: "/tmp/out")
        let post = Preset.all[0]
        let a = ExportPlan.Request(itemID: UUID(), source: URL(fileURLWithPath: "/photos/a.png"), preset: post)
        let twin = ExportPlan.Request(itemID: UUID(), source: URL(fileURLWithPath: "/other/a.jpg"), preset: post)
        let b = ExportPlan.Request(itemID: UUID(), source: URL(fileURLWithPath: "/photos/b.png"), preset: post)
        let existing: Set<String> = ["/tmp/out/a-\(post.id).jpg", "/tmp/out/b-\(post.id).jpg"]
        let protected: Set<String> = ["/tmp/out/b-\(post.id).jpg"]
        let exists = { (url: URL) in existing.contains(url.path) }
        XCTAssertEqual(ExportPlan.conflictCount(for: [a, twin, b], in: folder, fileExtension: "jpg",
                                                protected: protected, fileExists: exists), 1)
        let replaced = ExportPlan.destinations(for: [a, twin, b], in: folder, fileExtension: "jpg",
                                               resolution: .replace, protected: protected, fileExists: exists)
        XCTAssertEqual(replaced.map(\.destination.lastPathComponent),
                       ["a-\(post.id).jpg", "a-\(post.id)-2.jpg", "b-\(post.id)-2.jpg"])
        let kept = ExportPlan.destinations(for: [a, twin, b], in: folder, fileExtension: "jpg",
                                           resolution: .keepBoth, protected: protected, fileExists: exists)
        XCTAssertEqual(kept.map(\.destination.lastPathComponent),
                       ["a-\(post.id)-2.jpg", "a-\(post.id)-3.jpg", "b-\(post.id)-2.jpg"])
        XCTAssertEqual(kept.map(\.itemID), [a.itemID, twin.itemID, b.itemID])
    }

    func testExportAllWritesEachPhotoWithItsOwnPresetAndAsksOnceForConflicts() async throws {
        let (model, urls) = try await loadedSet(["a.png", "b.png"])
        let square = try XCTUnwrap(Preset.all.first { $0.width == $0.height })
        let wide = try XCTUnwrap(Preset.all.first { $0.width > $0.height })
        model.selectPreset(square)
        model.select(model.items[1].id)
        try await settled(model)
        model.selectPreset(wide)
        let output = folder.appendingPathComponent("export")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let firstName = "a-\(square.id).jpg"
        try Data("old".utf8).write(to: output.appendingPathComponent(firstName))
        model.exportAll(to: output)
        XCTAssertTrue(model.showExportConflicts)
        XCTAssertEqual(model.pendingExportAll?.conflictCount, 1)
        model.resolveExportConflicts(.keepBoth)
        try await settled(model)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent(firstName)), Data("old".utf8))
        let first = try ImageDocument(url: output.appendingPathComponent("a-\(square.id)-2.jpg"))
        XCTAssertEqual([first.pixelWidth, first.pixelHeight], [square.width, square.height])
        let second = try ImageDocument(url: output.appendingPathComponent("b-\(wide.id).jpg"))
        XCTAssertEqual([second.pixelWidth, second.pixelHeight], [wide.width, wide.height])
        XCTAssertTrue(model.items.allSatisfy { model.photoStatus(of: $0) == .exported })
        XCTAssertFalse(model.hasUnexportedItems)
        for url in urls { XCTAssertNoThrow(try ImageDocument(url: url)) }

        model.exportAll(to: output)
        XCTAssertTrue(model.showExportConflicts)
        model.resolveExportConflicts(.replace)
        try await settled(model)
        let replaced = try ImageDocument(url: output.appendingPathComponent(firstName))
        XCTAssertEqual(replaced.pixelWidth, square.width)
    }

    func testExportAllNeverOverwritesAnOriginalOfTheSet() async throws {
        let post = Preset.all[0]
        // b.png esportata con il preset produrrebbe proprio il nome dell'originale di a.
        let collidingOriginal = try sample("b-\(post.id).png")
        let other = try sample("b.png")
        let model = EditorModel()
        model.preset = post
        model.png = true
        model.open([collidingOriginal, other])
        try await settled(model)
        let before = try Data(contentsOf: collidingOriginal)
        model.exportAll(to: folder, resolution: .replace)
        try await settled(model)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(try Data(contentsOf: collidingOriginal), before)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("b-\(post.id)-2.png").path))
    }
}
