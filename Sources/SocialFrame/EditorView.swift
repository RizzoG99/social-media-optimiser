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
    @State private var cloneTarget = CGPoint(x: 0.5, y: 0.5)
    @State private var hoverPoint: CGPoint?
    @State private var showSourceDetails = false
    @State private var showExportDetails = false
    @FocusState private var canvasFocused: Bool

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
                                Text(preset.localizedName).font(.body)
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
            .disabled(model.isLoading)
            .navigationSplitViewColumnWidth(min: 200, ideal: 225, max: 300)
        } detail: {
            HSplitView {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.sourceURL?.lastPathComponent ?? L10n.text("Una foto, tutti i formati."))
                                .font(.headline).lineLimit(1)
                            Text(model.document == nil ? L10n.text("Prepara le tue immagini per i social.") : L10n.format("%@ · originale", model.imageDescription))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isLoading || model.isExporting || model.isRendering { ProgressView().controlSize(.small) }
                    }
                    .padding(20)
                    Divider()
                    canvas
                        .disabled(model.isLoading)
                        .allowsHitTesting(!model.isLoading)
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
                inspector.frame(width: 300)
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
                    .disabled(model.document == nil || model.isExporting || model.isLoading).accessibilityIdentifier("export-image")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.open(url); return true
        }
        .alert("Impossibile completare l’operazione", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("Esportare le modifiche prima di aprire un’altra immagine?", isPresented: $model.showReplacementConfirmation, titleVisibility: .visible) {
            Button("Esporta e apri…", action: model.exportAndOpenPendingImage)
                .disabled(model.isExporting)
            Button("Scarta modifiche e apri", role: .destructive, action: model.discardAndOpenPendingImage)
            Button("Annulla", role: .cancel, action: model.cancelReplacement)
        } message: {
            Text("Le modifiche attuali non sono state esportate. Aprendo un’altra immagine perderai la sessione e la cronologia.")
        }
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil; transaction.disablesAnimations = true }
        }
        .onChange(of: model.sourceURL) { _, _ in cloneSource = nil; hoverPoint = nil }
        .onChange(of: model.documentGeneration) { _, _ in cloneSource = nil; hoverPoint = nil; cloneTarget = CGPoint(x: 0.5, y: 0.5) }
        .onChange(of: cloneTarget) { _, _ in hoverPoint = nil }
        .onChange(of: model.preset) { _, _ in cloneSource = nil }
        .onChange(of: model.edit) { old, new in
            if old.panX != new.panX || old.panY != new.panY || old.zoom != new.zoom ||
                old.straightenDegrees != new.straightenDegrees || old.quarterTurns != new.quarterTurns {
                cloneSource = nil
            }
        }
        .onChange(of: cloneMode) { _, _ in hoverPoint = nil; NSCursor.arrow.set() }
        .onChange(of: model.isLoading) { _, loading in
            if loading { dragOrigin = nil; magnifyOrigin = nil; hoverPoint = nil }
        }
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
                    if model.showDestinationGuides && model.preset.id == "youtube-banner" {
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
                    if cloneMode {
                        let point = hoverPoint ?? cloneTarget
                        Circle().stroke(.black, lineWidth: 3)
                            .overlay(Circle().stroke(.white, lineWidth: 1))
                            .frame(width: min(width, height) * cloneRadius * 2, height: min(width, height) * cloneRadius * 2)
                            .position(x: point.x * width, y: (1 - point.y) * height)
                            .allowsHitTesting(false)
                    }
                    if model.showDestinationGuides && model.preset.id.hasSuffix("-profile") {
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
                    guard !model.isLoading, !cloneMode else { return }
                    if dragOrigin == nil { model.checkpoint(); model.clearCloneStrokes(); cloneSource = nil; dragOrigin = model.edit }
                    guard let origin = dragOrigin else { return }
                    model.pan(from: origin, translationX: Double(value.translation.width / width), translationY: -Double(value.translation.height / height))
                }.onEnded { _ in dragOrigin = nil })
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        if cloneMode {
                            NSCursor.crosshair.set()
                            hoverPoint = CGPoint(x: min(1, max(0, location.x / width)), y: min(1, max(0, 1 - location.y / height)))
                        }
                    case .ended: hoverPoint = nil; NSCursor.arrow.set()
                    }
                }
                .simultaneousGesture(SpatialTapGesture().onEnded { value in
                    guard !model.isLoading, cloneMode else { return }
                    canvasFocused = true
                    let point = CGPoint(x: min(1, max(0, value.location.x / width)), y: min(1, max(0, 1 - value.location.y / height)))
                    cloneTarget = point
                    if NSEvent.modifierFlags.contains(.option) || cloneSource == nil {
                        cloneSource = point
                    } else if let source = cloneSource {
                        model.addClone(source: source, target: point, radius: cloneRadius)
                    }
                })
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    guard !model.isLoading else { return }
                    if magnifyOrigin == nil { model.checkpoint(); model.clearCloneStrokes(); cloneSource = nil; magnifyOrigin = model.edit.zoom }
                    model.edit.zoom = min(8, max(1, (magnifyOrigin ?? 1) * value.magnification))
                }.onEnded { _ in magnifyOrigin = nil })
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .focusable()
                .focused($canvasFocused)
                .onMoveCommand { direction in
                    switch direction {
                    case .left: move(horizontal: -0.01, vertical: 0)
                    case .right: move(horizontal: 0.01, vertical: 0)
                    case .up: move(horizontal: 0, vertical: 0.01)
                    case .down: move(horizontal: 0, vertical: -0.01)
                    @unknown default: break
                    }
                }
                .onKeyPress(.space) {
                    guard cloneMode else { return .ignored }
                    applyCloneAtTarget()
                    return .handled
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Anteprima dell’immagine")
                .accessibilityHint(cloneMode ? L10n.text("Usa le frecce per spostare la destinazione e Spazio per scegliere la sorgente o applicare un timbro. Le coordinate sono disponibili nei controlli del clone.") : L10n.text("Usa le frecce o i pulsanti Sposta foto per spostare l’inquadratura. Usa Zoom per ingrandire."))
                .accessibilityAction(named: Text("Sposta a sinistra")) { move(horizontal: -0.01, vertical: 0) }
                .accessibilityAction(named: Text("Sposta a destra")) { move(horizontal: 0.01, vertical: 0) }
                .accessibilityAction(named: Text("Sposta in alto")) { move(horizontal: 0, vertical: 0.01) }
                .accessibilityAction(named: Text("Sposta in basso")) { move(horizontal: 0, vertical: -0.01) }
                .accessibilityAction(named: Text("Scegli sorgente o applica timbro")) { if cloneMode { applyCloneAtTarget() } }
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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.preset.platform.rawValue).font(.caption).foregroundStyle(.secondary)
                        Text(model.preset.localizedName).font(.title3.bold())
                        Text("\(model.preset.width) × \(model.preset.height) px").monospacedDigit()
                        DisclosureGroup("Fonte del formato", isExpanded: $showSourceDetails) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(model.preset.referenceNote).font(.caption)
                                Text(model.preset.verificationNote).font(.caption2).foregroundStyle(.secondary)
                                Link("Specifiche della piattaforma ↗", destination: model.preset.referenceURL).font(.caption)
                            }.padding(.top, 4)
                        }.font(.caption)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Inquadratura").font(.headline)
                        PrecisionAdjustment(title: L10n.text("Zoom"), value: model.edit.zoom, range: 1...8, step: 0.01, initial: 1, digits: 2, unit: "×", update: model.setZoom)
                        PrecisionAdjustment(title: L10n.text("Livella"), value: model.edit.straightenDegrees, range: -45...45, step: 0.1, initial: 0, digits: 1, unit: "°", update: model.setStraighten)
                        HStack {
                            Button(action: model.rotate) { Label("Ruota 90°", systemImage: "rotate.left") }
                            Spacer()
                            Button("Azzera modifiche", action: model.reset)
                                .help("Ripristina l’inquadratura iniziale ed elimina i timbri. Puoi annullare con ⌘Z.")
                        }.controlSize(.small)
                        Button(action: model.autoLevel) {
                            Label(model.isAutoLeveling ? L10n.text("Analisi…") : L10n.text("Autolivella"), systemImage: "level")
                        }
                        .disabled(model.isAutoLeveling || model.isLoading)
                        .accessibilityIdentifier("auto-level")
                        .help("Stima l’orizzonte sul Mac. Controlla il risultato; puoi annullare con ⌘Z.")
                        if let message = model.autoLevelMessage {
                            Text(message).font(.caption).foregroundStyle(.secondary)
                                .accessibilityIdentifier("auto-level-result")
                        }
                        DisclosureGroup("Sposta foto") {
                            HStack {
                                Button { move(horizontal: -0.01, vertical: 0) } label: { Image(systemName: "arrow.left") }.accessibilityLabel("Sposta a sinistra")
                                Button { move(horizontal: 0.01, vertical: 0) } label: { Image(systemName: "arrow.right") }.accessibilityLabel("Sposta a destra")
                                Button { move(horizontal: 0, vertical: 0.01) } label: { Image(systemName: "arrow.up") }.accessibilityLabel("Sposta in alto")
                                Button { move(horizontal: 0, vertical: -0.01) } label: { Image(systemName: "arrow.down") }.accessibilityLabel("Sposta in basso")
                            }.disabled(cloneMode).padding(.top, 5)
                            Text("Passi dell’1% della tela. Puoi anche trascinare la foto o usare le frecce quando l’anteprima ha il focus.").font(.caption).foregroundStyle(.secondary)
                        }.font(.caption)
                        Picker("Griglia", selection: $model.gridStyle) {
                            ForEach(CompositionGrid.allCases) { grid in Text(grid.title).tag(grid) }
                        }.accessibilityIdentifier("composition-grid")
                        if model.showGrid {
                            Slider(value: $model.gridOpacity, in: 0.2...1) { Text("Visibilità griglia") }
                                .accessibilityLabel("Visibilità griglia")
                        }
                        if model.preset.id == "youtube-banner" || model.preset.id.hasSuffix("-profile") {
                            Toggle("Guide della destinazione", isOn: $model.showDestinationGuides)
                                .help("Mostra guide indicative del ritaglio. Non vengono esportate.")
                        }
                    }.disabled(model.document == nil || model.isLoading)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Timbro clone").font(.headline)
                        Toggle("Attiva timbro", isOn: $cloneMode).accessibilityIdentifier("clone-mode")
                        if cloneMode {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(cloneSource == nil ? L10n.text("Fai clic nella foto per scegliere la sorgente.") : L10n.text("Fai clic sull’area da coprire. Tieni premuto Opzione e fai clic per cambiare sorgente."))
                                    .font(.caption).foregroundStyle(.secondary)
                                Slider(value: $cloneRadius, in: 0.005...0.15) { Text("Raggio del timbro") }
                                HStack {
                                    Text(L10n.format("Raggio: %@%%", (cloneRadius * 100).formatted(.number.precision(.fractionLength(1)))))
                                    Spacer()
                                    Button("Cambia sorgente") { cloneSource = nil }
                                }.font(.caption)
                                Text("Percentuale del lato corto dell’immagine.").font(.caption2).foregroundStyle(.secondary)
                                DisclosureGroup("Posizione del timbro") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Coordinate in percentuale, dall’angolo in basso a sinistra.").font(.caption)
                                        coordinateFields(title: L10n.text("Destinazione"), point: $cloneTarget)
                                        Button("Usa destinazione come sorgente") { cloneSource = cloneTarget }
                                        if let source = cloneSource {
                                            coordinateFields(title: L10n.text("Sorgente"), point: Binding(get: { source }, set: { cloneSource = $0 }))
                                        }
                                        Button("Applica timbro") { applyCloneAtTarget() }.disabled(cloneSource == nil)
                                    }.padding(.top, 5)
                                }.font(.caption)
                            }.transition(disclosureTransition)
                        }
                        if !model.edit.cloneStrokes.isEmpty {
                            Button(L10n.format("Elimina timbri (%d)", model.edit.cloneStrokes.count)) { model.checkpoint(); model.clearCloneStrokes() }
                        }
                        Text("Cambiare inquadratura o formato elimina i timbri. Premi ⌘Z per annullare la modifica e recuperarli.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.disabled(model.document == nil || model.isLoading)
                }.padding(16)
                    .animation(interfaceAnimation, value: cloneMode)
                    .animation(interfaceAnimation, value: model.edit.cloneStrokes.isEmpty)
            }
            Divider()
            exportControls.padding(16)
        }.background(.regularMaterial)
    }

    private var exportControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Esportazione").font(.headline)
            Picker("Formato", selection: $model.png) {
                Text("JPEG").tag(false)
                Text("PNG").tag(true)
            }.pickerStyle(.segmented)
            if !model.png {
                HStack { Text("Qualità JPEG"); Spacer(); Text("\(Int(model.jpegQuality * 100))%").monospacedDigit() }.font(.caption)
                Slider(value: $model.jpegQuality, in: 0.6...1).accessibilityLabel("Qualità JPEG")
            }
            DisclosureGroup("Dettagli esportazione", isExpanded: $showExportDetails) {
                Text("Qualità JPEG iniziale: 95%. Colori sRGB; trasparenza su bianco, anche in PNG. Il JPEG usa compressione con perdita; PNG conserva i pixel del risultato. Ingrandire non aggiunge dettaglio. I social possono ricomprimere i file.")
                    .font(.caption).foregroundStyle(.secondary)
            }.font(.caption)
            Button(action: model.export) {
                Text(model.isExporting ? L10n.text("Esportazione…") : L10n.text("Esporta immagine…")).frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).disabled(model.document == nil || model.isExporting || model.isLoading)
            Text("L’originale resta intatto. La sessione si perde aprendo un’altra immagine o chiudendo l’app.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func move(horizontal: Double, vertical: Double) {
        guard !model.isLoading else { return }
        hoverPoint = nil
        if cloneMode {
            cloneTarget = CGPoint(x: min(1, max(0, cloneTarget.x + horizontal)), y: min(1, max(0, cloneTarget.y + vertical)))
        } else {
            model.nudge(horizontal: horizontal, vertical: vertical)
        }
    }

    private func applyCloneAtTarget() {
        guard !model.isLoading else { return }
        hoverPoint = nil
        if let source = cloneSource {
            model.addClone(source: source, target: cloneTarget, radius: cloneRadius)
        } else {
            cloneSource = cloneTarget
        }
    }

    private func coordinateFields(title: String, point: Binding<CGPoint>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold())
            HStack {
                ForEach([true, false], id: \.self) { isX in
                    let axis = isX ? "X" : "Y"
                    Text(axis)
                    TextField(axis, value: Binding(get: { (isX ? point.wrappedValue.x : point.wrappedValue.y) * 100 }, set: { value in
                        guard value.isFinite else { return }
                        var updated = point.wrappedValue
                        if isX { updated.x = min(100, max(0, value)) / 100 } else { updated.y = min(100, max(0, value)) / 100 }
                        point.wrappedValue = updated
                    }), format: .number.precision(.fractionLength(1)))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(L10n.format("%@, coordinata %@ in percentuale", title, axis))
                }
            }
        }
    }
}

/// Sliders keep one undo step per drag; typed values and buttons are discrete edits.
private struct PrecisionAdjustment: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let initial: Double
    let digits: Int
    let unit: String
    let update: (Double, Bool) -> Bool
    @State private var isSliding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                TextField(title, value: Binding(get: { value }, set: { _ = update($0, true) }), format: .number.precision(.fractionLength(digits)))
                    .textFieldStyle(.roundedBorder).frame(width: 65).monospacedDigit()
                    .accessibilityLabel(title)
                Text(unit).foregroundStyle(.secondary)
                Button { _ = update(initial, true) } label: { Image(systemName: "arrow.counterclockwise") }
                    .help(L10n.format("Reimposta %@", title)).accessibilityLabel(L10n.format("Reimposta %@", title))
                    .disabled(value == initial)
            }
            HStack(spacing: 6) {
                Button { _ = update(value - step, true) } label: { Image(systemName: "minus") }
                    .accessibilityLabel(L10n.format("Riduci %@", title)).disabled(value <= range.lowerBound)
                Slider(value: Binding(get: { value }, set: { if update($0, !isSliding) { isSliding = true } }), in: range, onEditingChanged: { if !$0 { isSliding = false } })
                    .accessibilityLabel(title)
                Button { _ = update(value + step, true) } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L10n.format("Aumenta %@", title)).disabled(value >= range.upperBound)
            }.controlSize(.small)
        }
    }
}
