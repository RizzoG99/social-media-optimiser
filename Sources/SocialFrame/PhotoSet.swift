import AppKit
import CoreGraphics
import SocialCore
import UniformTypeIdentifiers

/// Stato annullabile di una foto: modifica e formato social. Fa parte della
/// cronologia e decide se una foto ha modifiche non esportate.
struct EditorSnapshot: Equatable {
    let edit: EditState
    let preset: Preset
}

/// Una foto del set in memoria (F-11). Finché è attiva, lo stato vive nelle
/// proprietà di `EditorModel`; questi campi si aggiornano al cambio foto.
struct PhotoItem: Identifiable {
    let id = UUID()
    let url: URL
    var edit = EditState()
    var preset: Preset
    var undoStack: [EditorSnapshot] = []
    var redoStack: [EditorSnapshot] = []
    /// Ultimo stato che non richiede protezione: iniziale o esportato.
    var preservedSnapshot: EditorSnapshot
    /// Ultimo stato esportato con successo, se c'è.
    var exportedSnapshot: EditorSnapshot?
    /// Miniatura del risultato modificato, mai esportata.
    var thumbnail: NSImage?

    init(url: URL, preset: Preset) {
        self.url = url
        self.preset = preset
        preservedSnapshot = EditorSnapshot(edit: EditState(), preset: preset)
    }

    var snapshot: EditorSnapshot { EditorSnapshot(edit: edit, preset: preset) }
}

/// Stato mostrato dal badge della pellicola.
enum PhotoStatus: Equatable {
    case unedited, edited, exported

    static func of(current: EditorSnapshot, preserved: EditorSnapshot?, exported: EditorSnapshot?) -> PhotoStatus {
        if current == exported { return .exported }
        return current == preserved ? .unedited : .edited
    }
}

enum ImportMode { case append, replace }

enum ExportConflictResolution { case replace, keepBoth }

/// Pianificazione dei nomi di Esporta tutto (F-13), separata dall'I/O per i test.
enum ExportPlan {
    struct Request {
        let itemID: PhotoItem.ID
        let source: URL
        let preset: Preset
    }

    struct Entry: Equatable {
        let itemID: PhotoItem.ID
        let destination: URL
    }

    /// Chiave di identità di un file: percorso standardizzato e collegamenti risolti.
    static func fileKey(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func fileName(for source: URL, preset: Preset, fileExtension: String, index: Int = 1) -> String {
        let stem = source.deletingPathExtension().lastPathComponent + "-" + preset.id
        return index == 1 ? "\(stem).\(fileExtension)" : "\(stem)-\(index).\(fileExtension)"
    }

    /// Nomi base che esistono già nella cartella e che l'utente può scegliere di
    /// sostituire. Gli originali del set non contano: non si sostituiscono mai.
    static func conflictCount(for requests: [Request], in folder: URL, fileExtension: String,
                              protected: Set<String>, fileExists: (URL) -> Bool) -> Int {
        var seen = Set<String>()
        return requests.reduce(0) { count, request in
            let url = folder.appendingPathComponent(fileName(for: request.source, preset: request.preset, fileExtension: fileExtension))
            let key = fileKey(url)
            guard seen.insert(key).inserted, !protected.contains(key), fileExists(url) else { return count }
            return count + 1
        }
    }

    /// Destinazioni definitive. Due foto con lo stesso nome nel set e gli originali
    /// ricevono sempre un suffisso numerico; i file esistenti solo con `.keepBoth`.
    static func destinations(for requests: [Request], in folder: URL, fileExtension: String,
                             resolution: ExportConflictResolution, protected: Set<String>,
                             fileExists: (URL) -> Bool) -> [Entry] {
        var claimed = Set<String>()
        return requests.map { request in
            var index = 1
            while true {
                let url = folder.appendingPathComponent(fileName(for: request.source, preset: request.preset,
                                                                 fileExtension: fileExtension, index: index))
                let key = fileKey(url)
                let blocked = claimed.contains(key) || protected.contains(key) ||
                    (resolution == .keepBoth && fileExists(url))
                if !blocked {
                    claimed.insert(key)
                    return Entry(itemID: request.itemID, destination: url)
                }
                index += 1
            }
        }
    }
}

enum PhotoImport {
    /// Espande le cartelle (solo primo livello, file immagine visibili, ordine del Finder)
    /// e conserva l'ordine dei file scelti. Non decodifica nulla.
    static func expand(_ urls: [URL]) -> [URL] {
        let manager = FileManager.default
        var result: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            if manager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let keys: [URLResourceKey] = [.isRegularFileKey, .contentTypeKey]
                let children = (try? manager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys,
                                                                 options: [.skipsHiddenFiles])) ?? []
                let images = children.filter { child in
                    guard let values = try? child.resourceValues(forKeys: Set(keys)),
                          values.isRegularFile == true, let type = values.contentType else { return false }
                    return type.conforms(to: .image)
                }
                result += images.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            } else {
                result.append(url)
            }
        }
        return result
    }

    /// Riduce un'immagine renderizzata al lato massimo indicato, per la pellicola.
    static func thumbnail(from image: CGImage, maxSide: Int = 160) -> CGImage? {
        let scale = min(1, Double(maxSide) / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

extension NSImage {
    convenience init(thumbnail image: CGImage) {
        self.init(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
