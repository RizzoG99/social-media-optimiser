import XCTest
import AppKit
import SocialCore
@testable import SocialFrame

/// Stato di presentazione e testi della shell condivisi tra finestra e menu.
@MainActor
final class EditorShellTests: XCTestCase {
    func testViewZoomCommandsStepWithinRangeAndFitResetsOffset() {
        let view = EditorViewState()
        view.fittedViewScale = 0.37
        XCTAssertEqual(view.currentScale, 0.37)
        view.zoomIn()
        XCTAssertTrue(view.viewAt100)
        XCTAssertEqual(view.currentScale, 0.5)
        view.zoomOut(); view.zoomOut()
        XCTAssertEqual(view.currentScale, 0.1, "0,5 → 0,25 → 0,1")
        for _ in 0..<5 { view.zoomOut() }
        XCTAssertEqual(view.currentScale, 0.1)
        XCTAssertFalse(view.canZoomOut)
        for _ in 0..<20 { view.zoomIn() }
        XCTAssertEqual(view.currentScale, 4)
        XCTAssertFalse(view.canZoomIn)
        view.viewOffset = CGSize(width: 40, height: -12)
        view.fit()
        XCTAssertFalse(view.viewAt100)
        XCTAssertEqual(view.viewOffset, .zero)
        XCTAssertEqual(view.currentScale, 0.37, "Adatta torna alla scala calcolata dalla finestra")
        view.viewOffset = CGSize(width: 5, height: 5)
        view.actualSize()
        XCTAssertEqual(view.currentScale, 1)
        XCTAssertEqual(view.viewOffset, .zero)
        // A scale between steps moves to the neighbouring step, never stays put.
        XCTAssertEqual(EditorViewState.step(after: 1), 1.5)
        XCTAssertEqual(EditorViewState.step(before: 1), 0.75)
        XCTAssertEqual(EditorViewState.step(after: 1.2), 1.5)
        XCTAssertEqual(EditorViewState.step(before: 1.2), 1)
    }

    func testSidebarSymbolsMatchAspectAndExistInSystem() {
        for preset in Preset.all {
            XCTAssertNotNil(NSImage(systemSymbolName: preset.aspectSymbol, accessibilityDescription: nil), preset.id)
            let ratio = Double(preset.width) / Double(preset.height)
            switch preset.aspectSymbol {
            case "person.crop.circle": XCTAssertTrue(preset.id.hasSuffix("-profile"), preset.id)
            case "rectangle": XCTAssertGreaterThan(ratio, 1, preset.id)
            case "rectangle.portrait": XCTAssertLessThan(ratio, 1, preset.id)
            case "square": XCTAssertEqual(ratio, 1, preset.id)
            default: XCTFail("Simbolo inatteso per \(preset.id)")
            }
        }
    }

    func testWindowTitleIsTheDocumentAndSubtitleCarriesFormatAndPixels() async throws {
        let model = EditorModel()
        XCTAssertEqual(model.windowTitle, L10n.text("Nessuna foto"))
        XCTAssertNotEqual(model.windowTitle, "SocialFrame")
        let preset = try XCTUnwrap(Preset.all.first { $0.id == "instagram-portrait" })
        let subtitle = preset.windowSubtitle
        XCTAssertTrue(subtitle.hasPrefix(preset.localizedName + " · "), subtitle)
        XCTAssertTrue(subtitle.hasSuffix(" · 1080 × 1350"), subtitle)
        XCTAssertEqual(preset.sizeDescription, "1080 × 1350 px", "Niente separatore delle migliaia, in qualunque locale")

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        model.open(root.appendingPathComponent("SocialCoreTests/Fixtures/horizon-level.png"))
        for _ in 0..<500 where model.isLoading || model.document == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.windowTitle, "horizon-level.png")
    }

    /// `L10n.text` mostra la chiave italiana se manca la traduzione: ogni chiave
    /// dinamica usata nei sorgenti deve esistere in tutte le lingue incluse.
    func testEveryDynamicStringKeyExistsInEveryLanguage() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources/SocialFrame")
        let pattern = try NSRegularExpression(pattern: #"L10n\.(?:text|format)\("((?:[^"\\]|\\.)*)""#)
        var keys = Set<String>()
        for file in try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil) where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            let string = text as NSString
            for match in pattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
                keys.insert(string.substring(with: match.range(at: 1)))
            }
        }
        XCTAssertGreaterThan(keys.count, 40)
        for language in ["it", "en"] {
            let url = sources.appendingPathComponent("Resources/\(language).lproj/Localizable.strings")
            let strings = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
            for key in keys { XCTAssertNotNil(strings[key], "\(language): \(key)") }
        }
    }
}
