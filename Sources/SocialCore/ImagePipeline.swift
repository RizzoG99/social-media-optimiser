import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Errors produced when importing, rendering, or exporting an image.
public enum SocialCoreError: Error, Equatable, LocalizedError {
    case invalidImage, invalidDimensions, tooLarge, sideTooLong, invalidEdit, renderFailed, exportFailed, wouldOverwriteOriginal
    public var errorDescription: String? {
        switch self {
        case .invalidImage: return String(localized: "Impossibile leggere l’immagine.", bundle: .module)
        case .invalidDimensions: return String(localized: "Le dimensioni dell’immagine superano i limiti supportati o non sono valide.", bundle: .module)
        case .tooLarge: return String(localized: "Il file supera 512 MB oppure l’immagine supera 120 megapixel.", bundle: .module)
        case .sideTooLong: return String(localized: "L’immagine supera il limite di 32.768 pixel per lato. Riducine le dimensioni e riprova.", bundle: .module)
        case .invalidEdit: return String(localized: "Le modifiche contengono valori non validi.", bundle: .module)
        case .renderFailed: return String(localized: "Impossibile elaborare l’immagine.", bundle: .module)
        case .exportFailed: return String(localized: "Impossibile esportare l’immagine.", bundle: .module)
        case .wouldOverwriteOriginal: return String(localized: "Scegli un altro file per preservare l’originale.", bundle: .module)
        }
    }
}

/// An immutable, decoded original. EXIF orientation is applied once on import.
/// Imports are limited to 512 MB and 120 megapixels (and 32,768 pixels per side).
public final class ImageDocument {
    let image: CIImage
    let sourceURL: URL?
    /// Dimensions after EXIF orientation is applied.
    public let pixelWidth: Int
    public let pixelHeight: Int

    public convenience init(url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= 512_000_000 else { throw SocialCoreError.tooLarge }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        try self.init(data: data, sourceURL: url)
    }

    public convenience init(data: Data) throws {
        try self.init(data: data, sourceURL: nil)
    }

    private init(data: Data, sourceURL: URL?) throws {
        guard data.count <= 512_000_000 else { throw SocialCoreError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0 else { throw SocialCoreError.invalidImage }
        guard width <= 32768, height <= 32768 else { throw SocialCoreError.sideTooLong }
        guard width <= 120_000_000 / height else { throw SocialCoreError.tooLarge }
        guard let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw SocialCoreError.invalidImage }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.int32Value ?? 1
        let oriented = CIImage(cgImage: cg).oriented(forExifOrientation: (1...8).contains(orientation) ? orientation : 1)
        let extent = oriented.extent.integral
        guard extent.width > 0, extent.height > 0 else { throw SocialCoreError.invalidImage }
        image = oriented.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        pixelWidth = Int(extent.width); pixelHeight = Int(extent.height); self.sourceURL = sourceURL
    }
}

/// File formats supported by the exporter. JPEG quality must be between 0 and 1.
public enum ExportFormat: Equatable, Sendable {
    case jpeg(quality: Double)
    case png
}

/// Renders previews and exports through the same crop and color conversion.
/// All output is flattened onto white in sRGB; outputs are limited to 40 megapixels.
public final class ImageRenderer {
    private let context: CIContext
    private let colorSpace: CGColorSpace
    public init() {
        colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
    }

    /// Renders exactly the preset size, or fits inside `maxPixelSize` without upscaling
    /// when supplied. The crop is identical at either resolution.
    public func render(document: ImageDocument, preset: Preset, edit: EditState,
                       maxPixelSize: Int? = nil) throws -> CGImage {
        guard preset.width > 0, preset.height > 0, preset.width <= 32768, preset.height <= 32768, preset.width <= 40_000_000 / preset.height,
              maxPixelSize.map({ $0 > 0 }) ?? true else { throw SocialCoreError.invalidDimensions }
        guard edit.panX.isFinite, edit.panY.isFinite, edit.zoom.isFinite, edit.zoom >= 1,
              edit.zoom <= 1000, edit.straightenDegrees.isFinite else { throw SocialCoreError.invalidEdit }
        let ratio = min(1, Double(maxPixelSize ?? max(preset.width, preset.height)) / Double(max(preset.width, preset.height)))
        let w = max(1, Int((Double(preset.width) * ratio).rounded()))
        let h = max(1, Int((Double(preset.height) * ratio).rounded()))
        let sw = Double(document.pixelWidth), sh = Double(document.pixelHeight)
        // Calculate against the exact preset aspect; preview rounding is a final resize.
        let ow = Double(preset.width), oh = Double(preset.height)
        let angle = (Double(edit.quarterTurns % 4) * 90 + edit.straightenDegrees.truncatingRemainder(dividingBy: 360)) * .pi / 180
        let c = cos(angle), s = sin(angle)
        let halfW = (abs(c) * ow + abs(s) * oh) / 2
        let halfH = (abs(s) * ow + abs(c) * oh) / 2
        let scale = max(2 * halfW / sw, 2 * halfH / sh) * edit.zoom
        let limitX = max(0, sw / 2 - halfW / scale)
        let limitY = max(0, sh / 2 - halfH / scale)
        let dx = min(limitX, max(-limitX, edit.panX * sw))
        let dy = min(limitY, max(-limitY, edit.panY * sh))
        var image = document.image.clampedToExtent().transformed(by: CGAffineTransform(translationX: -sw / 2 - dx, y: -sh / 2 - dy))
        image = image.transformed(by: CGAffineTransform(rotationAngle: angle))
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        image = image.transformed(by: CGAffineTransform(translationX: ow / 2, y: oh / 2))
        image = image.cropped(to: CGRect(x: 0, y: 0, width: ow, height: oh))
        // Flatten before stamping so previews, PNG and JPEG agree on transparency.
        let rect = CGRect(x: 0, y: 0, width: ow, height: oh)
        image = image.composited(over: CIImage(color: .white).cropped(to: rect)).cropped(to: rect)
        guard edit.cloneStrokes.count <= 10_000 else { throw SocialCoreError.invalidEdit }
        for stroke in edit.cloneStrokes {
            guard [stroke.sourceX, stroke.sourceY, stroke.targetX, stroke.targetY, stroke.radius].allSatisfy({ $0.isFinite }),
                  (0...1).contains(stroke.sourceX), (0...1).contains(stroke.sourceY),
                  (0...1).contains(stroke.targetX), (0...1).contains(stroke.targetY),
                  stroke.radius > 0, stroke.radius <= 1 else { throw SocialCoreError.invalidEdit }
            let radius = stroke.radius * min(ow, oh)
            let center = CIVector(x: stroke.targetX * ow, y: stroke.targetY * oh)
            let mask = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": center, "inputRadius0": radius * 0.7, "inputRadius1": radius,
                "inputColor0": CIColor.white, "inputColor1": CIColor.clear
            ])!.outputImage!.cropped(to: rect)
            let shifted = image.clampedToExtent().transformed(by: CGAffineTransform(
                translationX: (stroke.targetX - stroke.sourceX) * ow,
                y: (stroke.targetY - stroke.sourceY) * oh)).cropped(to: rect)
            guard let blended = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: shifted, kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: mask
            ])?.outputImage else { throw SocialCoreError.renderFailed }
            image = blended.cropped(to: rect)
        }
        image = image.transformed(by: CGAffineTransform(scaleX: Double(w) / ow, y: Double(h) / oh))
        guard let result = context.createCGImage(image, from: CGRect(x: 0, y: 0, width: w, height: h), format: .RGBA8, colorSpace: colorSpace) else { throw SocialCoreError.renderFailed }
        return result
    }

    /// Applies an image drag measured as fractions of output width and height,
    /// with positive y upwards. Use the gesture-start state with total translation.
    /// The returned pan is clamped and existing clone strokes are cleared.
    public func panned(document: ImageDocument, preset: Preset, edit: EditState,
                       translationX: Double, translationY: Double) throws -> EditState {
        guard preset.width > 0, preset.height > 0, preset.width <= 32768, preset.height <= 32768,
              preset.width <= 40_000_000 / preset.height else { throw SocialCoreError.invalidDimensions }
        guard translationX.isFinite, translationY.isFinite, edit.panX.isFinite, edit.panY.isFinite,
              edit.zoom.isFinite, (1...1000).contains(edit.zoom), edit.straightenDegrees.isFinite else { throw SocialCoreError.invalidEdit }
        let ow = Double(preset.width), oh = Double(preset.height)
        let sw = Double(document.pixelWidth), sh = Double(document.pixelHeight)
        let angle = (Double(edit.quarterTurns % 4) * 90 + edit.straightenDegrees.truncatingRemainder(dividingBy: 360)) * .pi / 180
        let c = cos(angle), s = sin(angle)
        let hw = (abs(c) * ow + abs(s) * oh) / 2, hh = (abs(s) * ow + abs(c) * oh) / 2
        let scale = max(2 * hw / sw, 2 * hh / sh) * edit.zoom
        let lx = max(0, sw / 2 - hw / scale), ly = max(0, sh / 2 - hh / scale)
        var result = edit
        result.panX = min(lx, max(-lx, edit.panX * sw - (c * translationX * ow + s * translationY * oh) / scale)) / sw
        result.panY = min(ly, max(-ly, edit.panY * sh - (-s * translationX * ow + c * translationY * oh) / scale)) / sh
        result.cloneStrokes = []
        return result
    }

    /// Encodes a rendered image to a new URL. An imported file cannot be overwritten.
    public func export(document: ImageDocument, preset: Preset, edit: EditState,
                       format: ExportFormat, to url: URL) throws {
        if let original = document.sourceURL {
            let samePath = original.standardizedFileURL.resolvingSymlinksInPath() == url.standardizedFileURL.resolvingSymlinksInPath()
            let a = try? original.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject
            let b = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject
            if samePath || (a != nil && b != nil && a == b) { throw SocialCoreError.wouldOverwriteOriginal }
        }
        let type: CFString
        var options: [CFString: Any] = [:]
        switch format {
        case .png: type = UTType.png.identifier as CFString
        case .jpeg(let quality):
            guard quality.isFinite, (0...1).contains(quality) else { throw SocialCoreError.invalidEdit }
            type = UTType.jpeg.identifier as CFString
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }
        let image = try render(document: document, preset: preset, edit: edit)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else { throw SocialCoreError.exportFailed }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw SocialCoreError.exportFailed }
        try (data as Data).write(to: url, options: .atomic)
    }
}
