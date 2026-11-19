import XCTest
import Combine
import AppKit
import SocialCore
@testable import SocialFrame

/// Durante un trascinamento la finestra non deve ricalcolare ciò che non cambia:
/// l'indicatore di rendering spostava il layout a ogni fotogramma e i menu osservavano
/// ogni modifica del model.
@MainActor
final class PanResponsivenessTests: XCTestCase {
    private func loadedModel() async throws -> EditorModel {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 300, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 120, bitmap.bytesPerRow * 300)
        let data = bitmap.representation(using: .png, properties: [:])!
        let model = EditorModel(loadDocument: { _ in try ImageDocument(data: data) })
        model.open(URL(fileURLWithPath: "/pan/photo.png"))
        for _ in 0..<250 {
            if !model.isLoading && model.preview != nil && !model.isRendering { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNotNil(model.preview)
        model.setZoom(2)
        return model
    }

    private func drag(_ model: EditorModel) async throws {
        model.checkpoint()
        let origin = model.edit
        for step in 1...60 {
            model.pan(from: origin, translationX: Double(step) * 0.003, translationY: 0)
            try await Task.sleep(for: .milliseconds(8))
        }
        for _ in 0..<250 {
            if !model.isRendering { break }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func testFastRendersDuringPanDoNotShowProgressIndicator() async throws {
        let model = try await loadedModel()
        var shown = 0
        let observation = model.$showsRenderProgress.dropFirst().sink { if $0 { shown += 1 } }
        defer { observation.cancel() }
        var frames = 0
        let frameObservation = model.$preview.dropFirst().sink { _ in frames += 1 }
        defer { frameObservation.cancel() }
        try await drag(model)
        XCTAssertGreaterThan(frames, 5, "Il trascinamento deve produrre fotogrammi intermedi")
        XCTAssertEqual(shown, 0, "Rendering da pochi millisecondi: l'indicatore non deve lampeggiare")
        XCTAssertFalse(model.showsRenderProgress)
    }

    func testMenuStateIgnoresPanAndPreviewButTracksUndo() async throws {
        let model = try await loadedModel()
        let menu = EditorMenuState(model: model)
        try await Task.sleep(for: .milliseconds(50))
        var published: [EditorMenuState.Values] = []
        let observation = menu.$values.dropFirst().sink { published.append($0) }
        defer { observation.cancel() }
        let before = menu.values
        try await drag(model)
        try await Task.sleep(for: .milliseconds(50))
        // Il trascinamento crea un passo di annullamento: un solo cambio, non uno per evento.
        XCTAssertLessThanOrEqual(published.count, 1, "Pubblicazioni dei menu durante il trascinamento: \(published.count)")
        XCTAssertEqual(menu.values.canUndo, true)
        XCTAssertEqual(menu.values.hasDocument, before.hasDocument)
        model.undo(); model.undo()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(menu.values.canRedo, true, "I menu seguono comunque annulla/ripristina")
    }
}
