import SwiftUI
import SocialCore

/// Strumento attivo dell'editor, scelto dal selettore in toolbar o dal menu Immagine.
enum EditorTool: Int, CaseIterable, Identifiable {
    case composition, crop, tools
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .composition: return L10n.text("Inquadratura")
        case .crop: return L10n.text("Ritaglia")
        case .tools: return L10n.text("Strumenti")
        }
    }
}

/// Stato di presentazione condiviso tra finestra e barra dei menu.
/// Non fa parte di `EditState`: non entra in cronologia, snapshot o export.
@MainActor
final class EditorViewState: ObservableObject {
    @Published var tool: EditorTool = .composition
    /// `true` quando la vista usa una scala esplicita invece di Adatta.
    @Published var viewAt100 = false
    @Published var viewScale = 1.0
    @Published var fittedViewScale = 1.0
    @Published var viewOffset = CGSize.zero
    @Published var inspectorVisible = true

    /// Scale della vista rispetto ai pixel esportati, come i livelli di Anteprima.
    static let zoomSteps: [Double] = [0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4]

    var currentScale: Double { viewAt100 ? viewScale : fittedViewScale }
    var canZoomIn: Bool { currentScale < Self.zoomSteps.last! - 0.001 }
    var canZoomOut: Bool { currentScale > Self.zoomSteps.first! + 0.001 }

    func fit() { viewAt100 = false; viewOffset = .zero }
    func actualSize() { viewScale = 1; viewAt100 = true; viewOffset = .zero }
    func zoomIn() { setScale(Self.step(after: currentScale)) }
    func zoomOut() { setScale(Self.step(before: currentScale)) }
    func resetView() { viewAt100 = false; viewScale = 1; viewOffset = .zero }

    private func setScale(_ scale: Double) { viewScale = scale; viewAt100 = true }

    static func step(after scale: Double) -> Double {
        zoomSteps.first { $0 > scale + 0.001 } ?? zoomSteps.last!
    }
    static func step(before scale: Double) -> Double {
        zoomSteps.last { $0 < scale - 0.001 } ?? zoomSteps.first!
    }
}

extension EditorModel {
    /// Il titolo della finestra descrive il documento, non l'app.
    var windowTitle: String { sourceURL?.lastPathComponent ?? L10n.text("Nessuna foto") }
}

extension Preset {
    /// Pixel senza separatore delle migliaia, come Anteprima e il sottotitolo.
    var pixelSize: String { "\(width) × \(height)" }
    var sizeDescription: String { pixelSize + " px" }
    /// Contesto secondario della finestra: formato e pixel esportati. La piattaforma
    /// resta nella sidebar e nell'inspector: accanto al selettore centrale lo spazio
    /// del sottotitolo è stretto e i pixel non devono essere troncati.
    var windowSubtitle: String { localizedName + " · " + pixelSize }
    /// Simbolo SF che richiama il rapporto d'aspetto nella sidebar.
    var aspectSymbol: String {
        if id.hasSuffix("-profile") { return "person.crop.circle" }
        let ratio = Double(width) / Double(height)
        if ratio > 1.05 { return "rectangle" }
        if ratio < 0.95 { return "rectangle.portrait" }
        return "square"
    }
}
