import Foundation

/// Non-destructive crop adjustments. Pan is a fraction of the oriented source's
/// width and height, in Core Image coordinates (positive y is upwards).
/// Zoom is relative to the minimum scale needed to fill the output. Quarter turns
/// and straighten are counterclockwise; straighten is expressed in degrees.
/// A clone stamp in normalized output coordinates (origin at bottom left).
/// Radius is a fraction of the shorter output side. Stamps sample the result of
/// earlier stamps. Clear stamps when changing crop, pan, zoom or rotation.
public struct CloneStroke: Equatable, Sendable {
    public var sourceX, sourceY, targetX, targetY, radius: Double
    public init(sourceX: Double, sourceY: Double, targetX: Double, targetY: Double, radius: Double) {
        self.sourceX = sourceX; self.sourceY = sourceY; self.targetX = targetX
        self.targetY = targetY; self.radius = radius
    }
}

public struct EditState: Equatable, Sendable {
    public var panX: Double
    public var panY: Double
    public var zoom: Double
    public var straightenDegrees: Double
    public var quarterTurns: Int
    public var cloneStrokes: [CloneStroke]

    public init(panX: Double = 0, panY: Double = 0, zoom: Double = 1,
                straightenDegrees: Double = 0, quarterTurns: Int = 0, cloneStrokes: [CloneStroke] = []) {
        self.panX = panX; self.panY = panY; self.zoom = zoom
        self.straightenDegrees = straightenDegrees; self.quarterTurns = quarterTurns
        self.cloneStrokes = cloneStrokes
    }
}
