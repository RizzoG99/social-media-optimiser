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
    /// Copia ridotta per l'anteprima, riportata all'estensione dell'originale: stessa geometria,
    /// solo meno pixel. `nil` quando l'originale non supera già il lato del proxy (ADR-014).
    let proxy: CIImage?
    /// Pixel del proxy per pixel dell'originale (1 senza proxy).
    let proxyDensity: Double
    let sourceURL: URL?
    /// Dimensions after EXIF orientation is applied.
    public let pixelWidth: Int
    public let pixelHeight: Int
    /// Lato lungo del proxy: con i preset attuali resta sufficiente fino a circa 1,8× di zoom.
    static let proxyMaxSide = 3072
    private static let proxyContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
    /// `true` se l'anteprima può usare il proxy.
    public var hasProxy: Bool { proxy != nil }

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
        guard var cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw SocialCoreError.invalidImage }
        // Un RAW restituito da ImageIO viene sviluppato di nuovo a ogni rendering (circa 0,8 s
        // per 26 MP): si sviluppa una volta qui, e anteprima ed export usano gli stessi pixel.
        if let type = CGImageSourceGetType(source).flatMap({ UTType($0 as String) }), type.conforms(to: .rawImage) {
            cg = try Self.developed(cg)
        }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.int32Value ?? 1
        let oriented = CIImage(cgImage: cg).oriented(forExifOrientation: (1...8).contains(orientation) ? orientation : 1)
        let extent = oriented.extent.integral
        guard extent.width > 0, extent.height > 0 else { throw SocialCoreError.invalidImage }
        image = oriented.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        pixelWidth = Int(extent.width); pixelHeight = Int(extent.height); self.sourceURL = sourceURL
        (proxy, proxyDensity) = try Self.makeProxy(of: image, width: pixelWidth, height: pixelHeight)
    }

    private static func developed(_ raw: CGImage) throws -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(data: nil, width: raw.width, height: raw.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw SocialCoreError.invalidImage }
        context.draw(raw, in: CGRect(x: 0, y: 0, width: raw.width, height: raw.height))
        guard let bitmap = context.makeImage() else { throw SocialCoreError.invalidImage }
        return bitmap
    }

    /// Riduce con Lanczos (filtrato, senza aliasing) e riporta la copia all'estensione
    /// dell'originale, così `render`, `panned` e ritaglio non cambiano.
    private static func makeProxy(of image: CIImage, width: Int, height: Int) throws -> (CIImage?, Double) {
        let longSide = max(width, height)
        guard longSide > proxyMaxSide else { return (nil, 1) }
        let factor = Double(proxyMaxSide) / Double(longSide)
        let pw = max(1, Int((Double(width) * factor).rounded())), ph = max(1, Int((Double(height) * factor).rounded()))
        let reduced = image.clampedToExtent().applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: Double(ph) / Double(height), kCIInputAspectRatioKey: (Double(pw) / Double(width)) / (Double(ph) / Double(height))
        ])
        guard let cg = proxyContext.createCGImage(reduced, from: CGRect(x: 0, y: 0, width: pw, height: ph),
                                                  format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else { throw SocialCoreError.renderFailed }
        let restored = CIImage(cgImage: cg).transformed(by: CGAffineTransform(scaleX: Double(width) / Double(pw), y: Double(height) / Double(ph)))
        return (restored, min(Double(pw) / Double(width), Double(ph) / Double(height)))
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
    /// With `allowProxy` the reduced copy is used when it has at least as many pixels as the
    /// frame needs; exports never pass it.
    public func render(document: ImageDocument, preset: Preset, edit: EditState,
                       maxPixelSize: Int? = nil, allowProxy: Bool = false) throws -> CGImage {
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
        // Pixel di output per pixel sorgente nel fotogramma richiesto.
        let density = scale * Double(w) / ow
        let source = allowProxy ? Self.source(for: document, density: density) : document.image
        var image = source.clampedToExtent().transformed(by: CGAffineTransform(translationX: -sw / 2 - dx, y: -sh / 2 - dy))
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
        if edit.outputSharpening != .none {
            image = image.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: ["inputRadius": 0.7, "inputIntensity": edit.outputSharpening.intensity]).cropped(to: rect)
        }
        image = image.transformed(by: CGAffineTransform(scaleX: Double(w) / ow, y: Double(h) / oh))
        guard let result = context.createCGImage(image, from: CGRect(x: 0, y: 0, width: w, height: h), format: .RGBA8, colorSpace: colorSpace) else { throw SocialCoreError.renderFailed }
        return result
    }

    /// Il proxy quando basta alla densità richiesta (con un margine per gli arrotondamenti),
    /// altrimenti l'originale: zoomando oltre il proxy l'anteprima torna alla piena risoluzione.
    static func source(for document: ImageDocument, density: Double) -> CIImage {
        guard let proxy = document.proxy, density <= document.proxyDensity * 1.001 else { return document.image }
        return proxy
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

    /// A wider, clone-free context for manipulating the existing crop.
    public func cropContext(document: ImageDocument, preset: Preset, edit: EditState) throws -> (edit: EditState, selection: CGRect) {
        let current = try panned(document: document, preset: preset, edit: edit, translationX: 0, translationY: 0)
        let sw = Double(document.pixelWidth), sh = Double(document.pixelHeight)
        let ow = Double(preset.width), oh = Double(preset.height)
        let angle = (Double(current.quarterTurns % 4) * 90 + current.straightenDegrees.truncatingRemainder(dividingBy: 360)) * .pi / 180
        let c = cos(angle), s = sin(angle)
        let fill = max((abs(c) * ow + abs(s) * oh) / sw, (abs(s) * ow + abs(c) * oh) / sh)
        // Per ogni zoom, dal più ampio: prima la vista centrata e limitata (come in origine);
        // se la selezione ne esce, l'inquadratura ingrandita attorno a un punto fisso. Contro
        // un bordo, con un raddrizzamento, il limite del pan (riquadro di ingombro ruotato)
        // ammette solo l'ingrandimento attorno all'angolo che tocca il bordo: si provano
        // punti fissi dal centro verso gli angoli.
        let stops = [0, 0.25, 0.5, 0.75, 1.0]
        let anchors = stops.flatMap { u in stops.map { v in (u, v) } }
            .sorted { hypot($0.0 - 0.5, $0.1 - 0.5) < hypot($1.0 - 0.5, $1.1 - 0.5) }
        for step in 0..<100 {
            let zoom = 1 + (current.zoom - 1) * Double(step) / 100
            let side = zoom / current.zoom
            let scale = fill * zoom
            // Prima la vista centrata sull'inquadratura e limitata: esatta quando contiene la selezione.
            var centered = current
            centered.zoom = zoom
            centered = try panned(document: document, preset: preset, edit: centered, translationX: 0, translationY: 0)
            let r = selection(document: document, preset: preset, of: current, in: centered)
            let t = 0.000001
            if r.minX >= -t, r.minY >= -t, r.maxX <= 1 + t, r.maxY <= 1 + t {
                return (centered, CGRect(x: max(0, r.minX), y: max(0, r.minY), width: r.width, height: r.height))
            }
            for (u, v) in anchors {
                let selection = CGRect(x: u * (1 - side), y: v * (1 - side), width: side, height: side)
                // Offset dell'inquadratura dal centro della vista, riportato nel sorgente.
                let ox = (selection.midX - 0.5) * ow / scale, oy = (selection.midY - 0.5) * oh / scale
                var base = current
                base.zoom = zoom
                base.panX = current.panX - (c * ox + s * oy) / sw
                base.panY = current.panY - (-s * ox + c * oy) / sh
                let limited = try panned(document: document, preset: preset, edit: base, translationX: 0, translationY: 0)
                guard abs(limited.panX - base.panX) < 1e-9, abs(limited.panY - base.panY) < 1e-9 else { continue }
                return (limited, selection)
            }
        }
        return (current, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    /// Posizione di `target` nel risultato di `base`, normalizzata con origine in basso a
    /// sinistra. Le due modifiche devono avere la stessa rotazione; il lato è il rapporto degli zoom.
    public func selection(document: ImageDocument, preset: Preset, of target: EditState, in base: EditState) -> CGRect {
        let sw = Double(document.pixelWidth), sh = Double(document.pixelHeight)
        let ow = Double(preset.width), oh = Double(preset.height)
        let angle = (Double(base.quarterTurns % 4) * 90 + base.straightenDegrees.truncatingRemainder(dividingBy: 360)) * .pi / 180
        let c = cos(angle), s = sin(angle)
        let fill = max((abs(c) * ow + abs(s) * oh) / sw, (abs(s) * ow + abs(c) * oh) / sh)
        let dx = (target.panX - base.panX) * sw, dy = (target.panY - base.panY) * sh
        let side = base.zoom / target.zoom
        let x = 0.5 + (c * dx - s * dy) * fill * base.zoom / ow - side / 2
        let y = 0.5 + (s * dx + c * dy) * fill * base.zoom / oh - side / 2
        return CGRect(x: x, y: y, width: side, height: side)
    }

    /// Selects a rectangle inside the current output, retaining its aspect ratio.
    public func cropped(document: ImageDocument, preset: Preset, edit: EditState, rect: CGRect) throws -> EditState {
        let values = [rect.minX, rect.minY, rect.width, rect.height]
        guard values.allSatisfy({ $0.isFinite }), rect.width > 0, rect.height > 0,
              rect.minX >= 0, rect.minY >= 0, rect.maxX <= 1.000001, rect.maxY <= 1.000001,
              abs(rect.width - rect.height) < 0.00001 else { throw SocialCoreError.invalidEdit }
        var enlarged = edit
        enlarged.zoom = edit.zoom / rect.width
        guard enlarged.zoom <= 8 else { throw SocialCoreError.invalidEdit }
        return try panned(document: document, preset: preset, edit: enlarged,
            translationX: (0.5 - rect.midX) / rect.width,
            translationY: (0.5 - rect.midY) / rect.height)
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
