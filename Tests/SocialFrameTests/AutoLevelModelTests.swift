import XCTest
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import SocialCore
@testable import SocialFrame

@MainActor
final class AutoLevelModelTests: XCTestCase {
    private func document() throws -> ImageDocument {
        let cg = CIContext().createCGImage(CIImage(color: .white), from: CGRect(x: 0, y: 0, width: 20, height: 20))!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, cg, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return try ImageDocument(data: data as Data)
    }
    private func finish(_ model: EditorModel) async throws {
        for _ in 0..<150 {
            if !model.isAutoLeveling && !model.isRendering { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Analysis did not finish")
    }
    func testAutoLevelIsOneUndoableEditAndRestoresCloneOnUndo() async throws {
        let model = EditorModel(estimateLevel: { _, _, _ in .init(straightenDegrees: -3, confidence: 0.9) })
        model.document = try document()
        model.edit = .init(zoom: 2, quarterTurns: 1, cloneStrokes: [.init(sourceX: 0.2, sourceY: 0.2, targetX: 0.7, targetY: 0.7, radius: 0.1)])
        let before = model.edit
        model.autoLevel()
        try await finish(model)
        XCTAssertEqual(model.edit.straightenDegrees, -3)
        XCTAssertEqual(model.edit.zoom, 2)
        XCTAssertEqual(model.edit.quarterTurns, 1)
        XCTAssertTrue(model.edit.cloneStrokes.isEmpty)
        model.undo()
        XCTAssertEqual(model.edit, before)
        model.redo()
        XCTAssertEqual(model.edit.straightenDegrees, -3)
    }
    func testNoReliableHorizonDoesNotChangeImageOrUndoHistory() async throws {
        for suggestion: AutoLevelSuggestion? in [nil, .init(straightenDegrees: 5, confidence: 0.1), .init(straightenDegrees: .nan, confidence: 1)] {
            let model = EditorModel(estimateLevel: { _, _, _ in suggestion })
            model.document = try document()
            let before = model.edit
            model.autoLevel()
            try await finish(model)
            XCTAssertEqual(model.edit, before)
            XCTAssertFalse(model.canUndo)
            XCTAssertNotNil(model.autoLevelMessage)
        }
    }
    func testAnalysisCannotOverwriteAnEditMadeWhileItRuns() async throws {
        let model = EditorModel(estimateLevel: { _, _, _ in
            try await Task.sleep(for: .milliseconds(40))
            return .init(straightenDegrees: 5, confidence: 0.9)
        })
        model.document = try document()
        model.autoLevel()
        model.edit.zoom = 2
        try await finish(model)
        XCTAssertEqual(model.edit.zoom, 2)
        XCTAssertEqual(model.edit.straightenDegrees, 0)
        XCTAssertFalse(model.canUndo)
    }
    func testGridChoiceDoesNotChangeImageOrUndoHistory() throws {
        let model = EditorModel()
        let before = model.edit
        model.gridStyle = .fine
        model.gridOpacity = 0.9
        XCTAssertEqual(model.edit, before)
        XCTAssertFalse(model.canUndo)
        model.gridStyle = .none
        XCTAssertFalse(model.showGrid)
    }
}
