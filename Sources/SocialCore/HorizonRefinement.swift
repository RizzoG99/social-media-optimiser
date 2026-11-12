import CoreGraphics
import Foundation

/// Refines a Vision-approved near-level crop using a strong, straight edge.
/// Does not invent an orientation for images with no consistent line support.
enum HorizonRefinement {
    static func residualDegrees(in image: CGImage) -> Double? {
        let w = image.width, h = image.height
        guard w >= 64, h >= 64 else { return nil }
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        guard let context = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        func luma(_ x: Int, _ y: Int) -> Double {
            let i = (y * w + x) * 4
            return (0.2126 * Double(bytes[i]) + 0.7152 * Double(bytes[i + 1]) + 0.0722 * Double(bytes[i + 2])) / 255
        }
        var points: [CGPoint] = []
        for sample in 0..<64 {
            let x = w / 20 + sample * (w * 9 / 10) / 63
            var best = 0.10, bestY: Int?
            for y in (h / 6)..<(h * 5 / 6) {
                let contrast = abs(luma(x, y + 2) - luma(x, y - 2))
                if contrast > best { best = contrast; bestY = y }
            }
            if let y = bestY { points.append(CGPoint(x: x, y: y)) }
        }
        guard points.count >= 48 else { return nil }
        var inliers: [CGPoint] = []
        // RANSAC rejects isolated details (sun, clouds, objects) and requires
        // broad support across the photograph rather than one local edge.
        for a in points.indices {
            for b in points.indices where b > a && points[b].x - points[a].x > Double(w) / 3 {
                let slope = (points[b].y - points[a].y) / (points[b].x - points[a].x)
                guard abs(atan(slope) * 180 / .pi) <= 4 else { continue }
                let intercept = points[a].y - slope * points[a].x
                let support = points.filter { abs($0.y - (slope * $0.x + intercept)) <= 2.5 }
                if support.count > inliers.count { inliers = support }
            }
        }
        guard inliers.count >= 44,
              let first = inliers.first, let last = inliers.last,
              last.x - first.x >= Double(w) * 0.65 else { return nil }
        let count = Double(inliers.count)
        // Keep the fit in Double: older SDKs expose both CGFloat and Double
        // math overloads, making an untyped reduce/pow expression ambiguous.
        let meanX = inliers.reduce(0.0) { $0 + Double($1.x) } / count
        let meanY = inliers.reduce(0.0) { $0 + Double($1.y) } / count
        let variance = inliers.reduce(0.0) { sum, point in
            let delta = Double(point.x) - meanX
            return sum + delta * delta
        }
        guard variance > 0 else { return nil }
        let slope = inliers.reduce(0.0) { $0 + (Double($1.x) - meanX) * (Double($1.y) - meanY) } / variance
        let squaredError = inliers.reduce(0.0) { sum, point in
            let residual = Double(point.y) - (meanY + slope * (Double(point.x) - meanX))
            return sum + residual * residual
        }
        let rms = sqrt(squaredError / count)
        let degrees = atan(slope) * 180 / .pi
        guard rms <= 1.5, abs(degrees) <= 4 else { return nil }
        return degrees
    }
}
