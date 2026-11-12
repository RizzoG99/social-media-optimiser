import Foundation

/// Preview-only guides in normalized coordinates, with origin at top left.
/// They never affect the image pipeline or exported pixels.
enum CompositionGrid: String, CaseIterable, Identifiable {
    case none, thirds, goldenRatio, center, diagonals, fine
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return L10n.text("Nessuna")
        case .thirds: return L10n.text("Regola dei terzi")
        case .goldenRatio: return L10n.text("Sezione aurea")
        case .center: return L10n.text("Centro")
        case .diagonals: return L10n.text("Diagonali")
        case .fine: return L10n.text("Griglia fitta")
        }
    }
    struct Line: Equatable {
        let start: CGPoint
        let end: CGPoint
    }
    var lines: [Line] {
        let fractions: [CGFloat]
        switch self {
        case .none: return []
        case .thirds: fractions = [1 / 3.0, 2 / 3.0]
        case .goldenRatio: fractions = [0.38196601125, 0.61803398875]
        case .center: fractions = [0.5]
        case .fine: fractions = (1..<8).map { CGFloat($0) / 8 }
        case .diagonals:
            return [.init(start: .zero, end: CGPoint(x: 1, y: 1)),
                    .init(start: CGPoint(x: 1, y: 0), end: CGPoint(x: 0, y: 1))]
        }
        return fractions.flatMap { value in
            [Line(start: CGPoint(x: value, y: 0), end: CGPoint(x: value, y: 1)),
             Line(start: CGPoint(x: 0, y: value), end: CGPoint(x: 1, y: value))]
        }
    }
}
