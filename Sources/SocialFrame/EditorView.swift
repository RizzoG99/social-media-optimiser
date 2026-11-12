import SwiftUI
import SocialCore
import UniformTypeIdentifiers

struct EditorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: EditorModel
    @State private var dragOrigin: EditState?
    @State private var magnifyOrigin: Double?
    @State private var cloneMode = false
    @State private var cloneSource: CGPoint?
    @State private var cloneRadius = 0.035

    // Scope animations to interface state; rendered pixels and gesture geometry
    // must always represent the current edit immediately.
    private var interfaceAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }
    private var disclosureTransition: AnyTransition {
        reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top))
    }

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { model.preset.id }, set: { id in
                if let p = Preset.all.first(where: { $0.id == id }) { model.selectPreset(p) }
            })) {
                ForEach(Platform.allCases, id: \.self) { platform in
                    Section(platform.rawValue) {
                        ForEach(Preset.all.filter { $0.platform == platform }) { preset in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.name).font(.body)
                                Text("\(preset.width) × \(preset.height)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                            .padding(.vertical, 3)
                            .tag(preset.id)
                            .accessibilityIdentifier("preset-\(preset.id)")
                        }
                    }
                }
            }
            .navigationTitle("Formati social")
            .navigationSplitViewColumnWidth(min: 200, ideal: 225, max: 300)
        } detail: {
            HSplitView {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.sourceURL?.lastPathComponent ?? "Una foto, tutti i formati.")
                                .font(.headline).lineLimit(1)
                            Text(model.document == nil ? "Prepara le tue immagini per i social." : "\(model.imageDescription) · originale")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isLoading || model.isExporting || model.isRendering { ProgressView().controlSize(.small) }
                    }
                    .padding(20)
                    Divider()
                    canvas
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .underPageBackgroundColor))
                        .animation(interfaceAnimation, value: model.preview != nil)
                    Divider()
                    HStack {
                        Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            .contentTransition(.opacity)
                            .animation(interfaceAnimation, value: model.status)
                        Spacer()
                        Text("sRGB").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }.padding(12)
                }.frame(minWidth: 460)
                inspector.frame(width: 265)
            }
            .navigationTitle("SocialFrame")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: model.chooseImage) { Label("Apri", systemImage: "photo.on.rectangle") }
                    .help("Apri un’immagine (⌘O)").accessibilityIdentifier("open-image")
                Button(action: model.undo) { Label("Annulla", systemImage: "arrow.uturn.backward") }.disabled(!model.canUndo)
                Button(action: model.redo) { Label("Ripristina", systemImage: "arrow.uturn.forward") }.disabled(!model.canRedo)
                Button(action: model.export) { Label("Esporta…", systemImage: "square.and.arrow.up") }
                    .disabled(model.document == nil || model.isExporting).accessibilityIdentifier("export-image")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.open(url); return true
        }
        .alert("Impossibile completare l’operazione", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil; transaction.disablesAnimations = true }
        }
        .onChange(of: model.sourceURL) { _, _ in cloneSource = nil }
        .onChange(of: model.preset) { _, _ in cloneSource = nil }
        .onChange(of: model.edit.straightenDegrees) { _, _ in cloneSource = nil }
    }

    @ViewBuilder private var canvas: some View {
        if let image = model.preview {
            GeometryReader { proxy in
                let available = CGSize(width: max(1, proxy.size.width - 64), height: max(1, proxy.size.height - 64))
                let ratio = CGFloat(model.preset.width) / CGFloat(model.preset.height)
                let width = min(available.width, available.height * ratio)
                let height = width / ratio
                ZStack {
                    Image(nsImage: image).resizable().interpolation(.high)
                    if model.showGrid {
                        Canvas { context, size in
                            var path = Path()
                            for line in model.gridStyle.lines {
                                path.move(to: CGPoint(x: line.start.x * size.width, y: line.start.y * size.height))
                                path.addLine(to: CGPoint(x: line.end.x * size.width, y: line.end.y * size.height))
                            }
                            context.stroke(path, with: .color(.black.opacity(model.gridOpacity * 0.65)), lineWidth: 1.8)
                            context.stroke(path, with: .color(.white.opacity(model.gridOpacity)), lineWidth: 0.65)
                        }.allowsHitTesting(false)
                            .transition(.opacity)
                    }
                    if model.showGrid && model.preset.id == "youtube-banner" {
                        Rectangle().stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .frame(width: width * 1235 / 2048, height: height * 338 / 1152)
                            .overlay(alignment: .bottom) {
                                Text("Area sicura indicativa").font(.caption2).padding(3)
                                    .background(.black.opacity(0.5)).foregroundStyle(.white)
                            }
                            .allowsHitTesting(false)
                    }
                    if cloneMode, let source = cloneSource {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22)).foregroundStyle(.white)
                            .shadow(color: .black, radius: 2)
                            .position(x: source.x * width, y: (1 - source.y) * height)
                            .allowsHitTesting(false)
                    }
                    if model.preset.name.localizedCaseInsensitiveContains("profil") {
                        Circle().stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [5, 4])).allowsHitTesting(false)
                    }
                }
                .animation(interfaceAnimation, value: model.gridStyle)
                .frame(width: width, height: height)
                .clipped()
                .overlay(Rectangle().stroke(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                    guard !cloneMode else { return }
                    if dragOrigin == nil { model.checkpoint(); model.clearCloneStrokes(); cloneSource = nil; dragOrigin = model.edit }
                    guard let origin = dragOrigin else { return }
                    model.pan(from: origin, translationX: Double(value.translation.width / width), translationY: -Double(value.translation.height / height))
                }.onEnded { _ in dragOrigin = nil })
                .onContinuousHover { phase in
                    switch phase {
                    case .active: if cloneMode { NSCursor.crosshair.set() }
                    case .ended: NSCursor.arrow.set()
                    }
                }
                .simultaneousGesture(SpatialTapGesture().onEnded { value in
                    guard cloneMode else { return }
                    let point = CGPoint(x: min(1, max(0, value.location.x / width)), y: min(1, max(0, 1 - value.location.y / height)))
                    if NSEvent.modifierFlags.contains(.option) || cloneSource == nil {
                        cloneSource = point
                    } else if let source = cloneSource {
                        model.addClone(source: source, target: point, radius: cloneRadius)
                    }
                })
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    if magnifyOrigin == nil { model.checkpoint(); model.clearCloneStrokes(); cloneSource = nil; magnifyOrigin = model.edit.zoom }
                    model.edit.zoom = min(8, max(1, (magnifyOrigin ?? 1) * value.magnification))
                }.onEnded { _ in magnifyOrigin = nil })
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Anteprima ritagliata. Trascina per spostare la foto, pizzica per ingrandire.")
                .accessibilityIdentifier("image-preview")
            }
            .transition(reduceMotion ? .identity : .opacity)
        } else {
            ContentUnavailableView {
                Label("Dai spazio alle tue foto", systemImage: "crop.rotate")
            } description: {
                Text("Trascina qui una foto oppure aprila dal Mac.\nScegli un formato e trova la tua inquadratura.")
            } actions: {
                Button("Apri immagine…", action: model.chooseImage).buttonStyle(.borderedProminent)
            }
            .transition(reduceMotion ? .identity : .opacity)
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.preset.platform == .x ? "X (Twitter)" : model.preset.platform.rawValue).font(.caption).foregroundStyle(.secondary)
                    Text(model.preset.name).font(.title3.bold())
                    Text("\(model.preset.width) × \(model.preset.height) px").font(.body.monospacedDigit())
                    Text(model.preset.referenceNote).font(.caption).foregroundStyle(.secondary)
                    Text("Fonti controllate il 12/11/2026").font(.caption2).foregroundStyle(.secondary)
                    Link("Specifiche della piattaforma ↗", destination: model.preset.referenceURL).font(.caption)
                }
                .id(model.preset.id)
                .transition(reduceMotion ? .identity : .opacity)
                }
                .animation(interfaceAnimation, value: model.preset.id)
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Inquadratura").font(.headline)
                    slider("Zoom", value: $model.edit.zoom, range: 1...8, text: String(format: "%.2f×", model.edit.zoom))
                    slider("Livella", value: $model.edit.straightenDegrees, range: -45...45, text: String(format: "%.1f°", model.edit.straightenDegrees))
                    HStack {
                        Button(action: model.rotate) { Label("Ruota 90°", systemImage: "rotate.left") }
                        Spacer()
                        Button("Azzera", action: model.reset)
                    }
                    Button(action: model.autoLevel) {
                        Label(model.isAutoLeveling ? "Analisi…" : "Autolivella", systemImage: "level")
                    }
                    .disabled(model.isAutoLeveling || model.isLoading)
                    .accessibilityIdentifier("auto-level")
                    .help("Stima l’orizzonte sul Mac. Controlla il risultato; puoi annullare con ⌘Z.")
                    if let message = model.autoLevelMessage {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("auto-level-result")
                    }
                    Picker("Griglia", selection: $model.gridStyle) {
                        ForEach(CompositionGrid.allCases) { grid in Text(grid.title).tag(grid) }
                    }
                    .accessibilityIdentifier("composition-grid")
                    if model.showGrid {
                        Slider(value: $model.gridOpacity, in: 0.2...1) { Text("Visibilità griglia") }
                            .accessibilityLabel("Visibilità griglia")
                    }
                    Text("Trascina per spostare la foto. Usa il gesto a pizzico o lo slider per ingrandire.")
                        .font(.caption).foregroundStyle(.secondary)
                }.disabled(model.document == nil)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timbro clone").font(.headline)
                    Toggle("Attiva timbro", isOn: $cloneMode)
                        .accessibilityIdentifier("clone-mode")
                    if cloneMode {
                        VStack(alignment: .leading, spacing: 12) {
                        Text(cloneSource == nil ? "Clicca nella foto per scegliere la sorgente." : "Clicca sul disturbo per coprirlo. ⌥ clic per cambiare sorgente.")
                            .font(.caption).foregroundStyle(.secondary)
                        Slider(value: $cloneRadius, in: 0.005...0.15) { Text("Raggio del timbro") }
                        HStack {
                            Text("Raggio: \(Int(cloneRadius * 100))%")
                            Spacer()
                            Button("Sorgente") { cloneSource = nil }
                        }.font(.caption)
                        }
                        .transition(disclosureTransition)
                    }
                    if !model.edit.cloneStrokes.isEmpty {
                        Button("Elimina ritocchi (\(model.edit.cloneStrokes.count))") { model.checkpoint(); model.clearCloneStrokes() }
                            .transition(reduceMotion ? .identity : .opacity)
                    }
                    Text("I ritocchi si azzerano cambiando inquadratura o preset. Puoi annullarli con ⌘Z.")
                        .font(.caption).foregroundStyle(.secondary)
                }.disabled(model.document == nil)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Esportazione").font(.headline)
                    Picker("Formato", selection: $model.png) {
                        Text("JPEG").tag(false)
                        Text("PNG").tag(true)
                    }.pickerStyle(.segmented)
                    if !model.png {
                        VStack(alignment: .leading) {
                            HStack { Text("Qualità JPEG"); Spacer(); Text("\(Int(model.jpegQuality * 100))%").monospacedDigit() }
                            Slider(value: $model.jpegQuality, in: 0.6...1)
                                .accessibilityLabel("Qualità JPEG")
                        }
                        .transition(disclosureTransition)
                    }
                    Text("Trasparenza su fondo bianco, anche in PNG. Ingrandire non aggiunge dettaglio alla foto.").font(.caption).foregroundStyle(.secondary)
                    Text("Colori sRGB per il web. Il JPEG usa compressione con perdita; PNG conserva i pixel del risultato. I social possono ricomprimere i file.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(action: model.export) { Text(model.isExporting ? "Esportazione…" : "Esporta immagine…").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).disabled(model.document == nil || model.isExporting)
                }
                Divider()
                Text("Modifiche non distruttive\nL’originale non viene sovrascritto. Le modifiche della sessione si perdono chiudendo l’app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
            .animation(interfaceAnimation, value: cloneMode)
            .animation(interfaceAnimation, value: model.edit.cloneStrokes.isEmpty)
            .animation(interfaceAnimation, value: model.png)
        }.background(.regularMaterial)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text(text).foregroundStyle(.secondary).monospacedDigit() }
            Slider(value: value, in: range, onEditingChanged: { editing in if editing { model.checkpoint(); model.clearCloneStrokes(); cloneSource = nil } })
                .accessibilityLabel(title)
        }
    }
}
