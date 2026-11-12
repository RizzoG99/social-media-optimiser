import CoreGraphics
import Foundation
import Vision

/// An absolute counterclockwise straighten setting and Vision's confidence (0...1).
public struct AutoLevelSuggestion: Equatable, Sendable {
    public let straightenDegrees: Double
    public let confidence: Double

    public init(straightenDegrees: Double, confidence: Double) {
        self.straightenDegrees = straightenDegrees
        self.confidence = confidence
    }
}

/// Estimates the horizon of the current rendered crop, entirely on device.
/// Rendering and Vision are synchronous; call this off the main actor.
public struct AutoLevelEstimator {
    public init() {}

    public func estimate(document: ImageDocument, preset: Preset, edit: EditState) throws -> AutoLevelSuggestion? {
        let renderer = ImageRenderer()
        var current = Self.analysisEdit(edit)
        var latest: AutoLevelSuggestion?
        // Horizon detection is approximate. Recheck the corrected crop up to
        // three times instead of trusting a single coarse ML estimate.
        for _ in 0..<3 {
            let image = try renderer.render(document: document, preset: preset, edit: current, maxPixelSize: 1024)
            let request = VNDetectHorizonRequest()
            try VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
            guard let observation = request.results?.first,
                  let next = Self.suggestion(observedTransform: observation.transform,
                      confidence: Double(observation.confidence), currentDegrees: current.straightenDegrees) else { break }
            latest = next
            let residual = abs(next.straightenDegrees - current.straightenDegrees)
            current.straightenDegrees = next.straightenDegrees
            if residual < 0.15 { break }
        }
        if let latest {
            let corrected = try renderer.render(document: document, preset: preset, edit: current, maxPixelSize: 1024)
            if let residual = HorizonRefinement.residualDegrees(in: corrected) {
                let refined = current.straightenDegrees + residual
                if (-45...45).contains(refined) {
                    return AutoLevelSuggestion(straightenDegrees: refined, confidence: latest.confidence)
                }
            }
        }
        return latest
    }

    static func analysisEdit(_ edit: EditState) -> EditState {
        var result = edit
        result.cloneStrokes = []
        return result
    }

    // Apple specifies the inverse horizon transform. Convert its image-space
    // Y convention before applying it to the renderer's bottom-up coordinates.
    // The signed rendered-pixel scenario protects this conversion end to end.
    static func suggestion(observedTransform: CGAffineTransform, confidence: Double,
                           currentDegrees: Double) -> AutoLevelSuggestion? {
        let a = Double(observedTransform.a), b = Double(observedTransform.b)
        let c = Double(observedTransform.c), d = Double(observedTransform.d)
        guard [a, b, c, d, Double(observedTransform.tx), Double(observedTransform.ty), confidence, currentDegrees]
            .allSatisfy(\.isFinite), (0.6...1).contains(confidence),
              (-45...45).contains(currentDegrees) else { return nil }
        // A rotation must be nondegenerate and orientation preserving.
        guard hypot(a, b) > 1e-9, hypot(c, d) > 1e-9, a * d - b * c > 1e-9 else { return nil }
        let imageSpace = CGAffineTransform(a: a, b: -b, c: -c, d: d, tx: 0, ty: 0)
        let correction = imageSpace.inverted()
        let degrees = currentDegrees + atan2(Double(correction.b), Double(correction.a)) * 180 / .pi
        guard degrees.isFinite, (-45...45).contains(degrees) else { return nil }
        return AutoLevelSuggestion(straightenDegrees: degrees, confidence: confidence)
    }
}
