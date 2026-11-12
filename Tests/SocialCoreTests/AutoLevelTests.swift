import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import SocialCore

final class AutoLevelTests: XCTestCase {
    func testVisionDoesNotLevelAUniformImage() throws {
        let image = CIContext().createCGImage(CIImage(color: .white), from: CGRect(x: 0, y: 0, width: 256, height: 256))!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let doc = try ImageDocument(data: data as Data)
        let preset = Preset(id: "test", platform: .instagram, name: "Test", width: 256, height: 256)
        XCTAssertNil(try AutoLevelEstimator().estimate(document: doc, preset: preset, edit: .init()))
    }

    func testObservedHorizonIsConvertedToRendererCoordinates() throws {
        let positive = try XCTUnwrap(AutoLevelEstimator.suggestion(
            observedTransform: CGAffineTransform(rotationAngle: .pi / 18), confidence: 0.8, currentDegrees: 7))
        XCTAssertEqual(positive.straightenDegrees, 17, accuracy: 1e-10)
        XCTAssertEqual(positive.confidence, 0.8)
        let negative = try XCTUnwrap(AutoLevelEstimator.suggestion(
            observedTransform: CGAffineTransform(rotationAngle: -.pi / 18), confidence: 1, currentDegrees: 7))
        XCTAssertEqual(negative.straightenDegrees, -3, accuracy: 1e-10)
    }

    func testRejectsUnreliableAndUnrepresentableResults() {
        let identity = CGAffineTransform.identity
        for confidence in [0.0, 0.5, 0.59, 1.01, .nan, .infinity] {
            XCTAssertNil(AutoLevelEstimator.suggestion(observedTransform: identity, confidence: confidence, currentDegrees: 0))
        }
        XCTAssertNil(AutoLevelEstimator.suggestion(observedTransform: identity, confidence: 1, currentDegrees: .nan))
        XCTAssertNil(AutoLevelEstimator.suggestion(observedTransform: CGAffineTransform(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0), confidence: 1, currentDegrees: 0))
        XCTAssertNil(AutoLevelEstimator.suggestion(observedTransform: CGAffineTransform(scaleX: -1, y: 1), confidence: 1, currentDegrees: 0))
        XCTAssertNil(AutoLevelEstimator.suggestion(observedTransform: CGAffineTransform(rotationAngle: .pi / 9), confidence: 1, currentDegrees: 30))
        XCTAssertNotNil(AutoLevelEstimator.suggestion(observedTransform: identity, confidence: 0.6, currentDegrees: 45))
    }

    func testPublicSuggestionInitializer() {
        let suggestion = AutoLevelSuggestion(straightenDegrees: -7, confidence: 0.8)
        XCTAssertEqual(suggestion.straightenDegrees, -7)
        XCTAssertEqual(suggestion.confidence, 0.8)
    }

    func testAnalysisEditRemovesOnlyCloneStrokes() {
        let stroke = CloneStroke(sourceX: 0.1, sourceY: 0.2, targetX: 0.3, targetY: 0.4, radius: 0.1)
        let edit = EditState(panX: 0.2, panY: -0.1, zoom: 2, straightenDegrees: 12, quarterTurns: 1, cloneStrokes: [stroke])
        var expected = edit
        expected.cloneStrokes = []
        XCTAssertEqual(AutoLevelEstimator.analysisEdit(edit), expected)
        XCTAssertEqual(edit.cloneStrokes, [stroke])
    }
}
