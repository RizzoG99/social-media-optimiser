import XCTest
import AppKit
import SocialCore
@testable import SocialFrame

/// Aprire più file insieme dal Finder consegna un `open` per file in rapida successione.
/// Prima del worker unico ogni richiesta avviava una decodifica completa (con foto da
/// 40 MP lette da scheda SD), che la cancellazione del task non fermava.
@MainActor
final class ImportBurstTests: XCTestCase {
    private final class DecodeLog: @unchecked Sendable {
        private let lock = NSLock()
        private var urls: [URL] = []
        func record(_ url: URL) { lock.lock(); urls.append(url); lock.unlock() }
        var all: [URL] { lock.lock(); defer { lock.unlock() }; return urls }
    }

    private func png(width: Int) -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: 24, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 200, bitmap.bytesPerRow * 24)
        return bitmap.representation(using: .png, properties: [:])!
    }

    func testBurstOfOpensDecodesOnlyLatestFile() async throws {
        let log = DecodeLog()
        let urls = (1...20).map { URL(fileURLWithPath: "/burst/photo-\($0).png") }
        let images = Dictionary(uniqueKeysWithValues: urls.enumerated().map { ($1, png(width: 30 + $0)) })
        let model = EditorModel(loadDocument: { url in
            log.record(url)
            Thread.sleep(forTimeInterval: 0.05) // decodifica lenta, come da scheda SD
            return try ImageDocument(data: images[url]!)
        })
        for url in urls { model.open(url) }
        for _ in 0..<250 {
            if !model.isLoading && model.preview != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.sourceURL, urls.last, "L'ultima richiesta vince")
        XCTAssertEqual(model.document?.pixelWidth, 30 + 19)
        XCTAssertEqual(model.documentGeneration, 1, "Nessun documento intermedio mostrato")
        XCTAssertLessThanOrEqual(log.all.count, 2, "Al più la decodifica già avviata più l'ultima: \(log.all.count)")
        XCTAssertEqual(log.all.last, urls.last)
    }

    func testFailedSupersededImportDoesNotReportError() async throws {
        let good = URL(fileURLWithPath: "/burst/good.png")
        let data = png(width: 40)
        let model = EditorModel(loadDocument: { url in
            Thread.sleep(forTimeInterval: 0.05)
            guard url == good else { throw SocialCoreError.invalidImage }
            return try ImageDocument(data: data)
        })
        model.open(URL(fileURLWithPath: "/burst/broken.raf"))
        model.open(good)
        for _ in 0..<250 {
            if !model.isLoading { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNil(model.errorMessage, "L'errore di un file già sostituito non va mostrato")
        XCTAssertEqual(model.sourceURL, good)
    }
}
