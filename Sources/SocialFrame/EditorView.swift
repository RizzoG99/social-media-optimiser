import SwiftUI
import SocialCore
import UniformTypeIdentifiers

/// Shell dell'editor secondo HIG macOS: titolo = file aperto, preset nel
/// sottotitolo, toolbar di sistema, sidebar `List`, inspector `Form`.
/// Il vetro arriva dai container di sistema; la foto resta nel livello contenuto.
struct EditorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: EditorModel
    @ObservedObject var viewState: EditorViewState
    @State private var dragOrigin: EditState?
    @State private var magnifyOrigin: Double?
    @AppStorage("canvasBackground") private var canvasBackground = "gray"
    @AppStorage("filmstripVisible") private var filmstripVisible = true
    @State private var expandedPlatforms: Set<Platform> = []
    @State private var viewDragOrigin: CGSize?
    @State private var cropping = false
    @State private var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
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
    private var editingDisabled: Bool { model.document == nil || model.isLoading }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                canvas
                    .disabled(model.isLoading)
                    .allowsHitTesting(!model.isLoading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(canvasColor)
                    .clipped()
                    .animation(interfaceAnimation, value: model.preview != nil)
                if filmstripVisible && !model.items.isEmpty {
                    Divider()
                    FilmstripView(model: model)
                }
                Divider()
                statusBar
            }
            .frame(minWidth: 460)
            .navigationTitle(model.windowTitle)
            .navigationSubtitle(model.preset.windowSubtitle)
            .inspector(isPresented: $viewState.inspectorVisible) {
                inspector.inspectorColumnWidth(min: 260, ideal: 300, max: 360)
            }
        }
        .toolbar { toolbarContent }
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            model.open(urls); return true
        }
        .alert("Impossibile completare l’operazione", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("Aggiungere le foto al set aperto?", isPresented: $model.showImportChoice, titleVisibility: .visible) {
            Button("Aggiungi al set", action: model.addPendingImport)
            Button("Sostituisci il set", action: model.replaceSetWithPendingImport)
            Button("Annulla", role: .cancel, action: model.cancelReplacement)
        } message: {
            Text("Puoi aggiungerle alle foto aperte oppure chiudere il set attuale e aprire solo le nuove.")
        }
        .confirmationDialog("Esportare le modifiche prima di sostituire il set?", isPresented: $model.showReplacementConfirmation, titleVisibility: .visible) {
            Button("Esporta e apri…", action: model.exportAndOpenPendingImage)
                .disabled(model.isExporting)
            Button("Scarta modifiche e apri", role: .destructive, action: model.discardAndOpenPendingImage)
            Button("Annulla", role: .cancel, action: model.cancelReplacement)
        } message: {
            Text("Alcune foto hanno modifiche non esportate. Sostituendo il set perderai le modifiche e la cronologia.")
        }
        .confirmationDialog("Rimuovere la foto dal set?", isPresented: $model.showRemovalConfirmation, titleVisibility: .visible) {
            Button("Rimuovi", role: .destructive, action: model.confirmRemoval)
            Button("Annulla", role: .cancel, action: model.cancelRemoval)
        } message: {
            Text("Le modifiche non esportate andranno perse. Il file sul Mac resta dov’è.")
        }
        .confirmationDialog(Text(L10n.format("%d file esistono già nella cartella.", model.pendingExportAll?.conflictCount ?? 0)), isPresented: $model.showExportConflicts, titleVisibility: .visible) {
            Button("Sostituisci", role: .destructive) { model.resolveExportConflicts(.replace) }
            Button("Mantieni entrambi") { model.resolveExportConflicts(.keepBoth) }
            Button("Annulla", role: .cancel, action: model.cancelExportAll)
        } message: {
            Text("Mantieni entrambi aggiunge un numero al nome delle nuove copie. Gli originali non vengono mai sostituiti.")
        }
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil; transaction.disablesAnimations = true }
        }
        .onChange(of: model.sourceURL) { _, _ in cloneSource = nil; hoverPoint = nil }
        .onChange(of: viewState.tool) { _, tool in
            if tool == .crop { startCropMode() }
            else { cropping = false; model.cancelCrop() }
            if tool != .tools { cloneMode = false }
        }
        .onChange(of: viewState.viewAt100) { _, value in model.fullResolutionPreview = value }
        .onChange(of: model.documentGeneration) { _, _ in cloneSource = nil; hoverPoint = nil; cloneTarget = CGPoint(x: 0.5, y: 0.5) }
        .onChange(of: cloneTarget) { _, _ in hoverPoint = nil }
        .onChange(of: model.preset) { _, _ in cloneSource = nil; resetView(); viewState.tool = .composition }
        .onChange(of: model.documentGeneration) { _, _ in resetView(); viewState.tool = .composition }
        .onChange(of: model.edit) { old, new in
            if viewState.tool == .crop {
                // Livella e Autolivella cambiano solo la rotazione: la selezione trascinata
                // resta, riportata nel nuovo contesto. Ogni altra modifica (annulla, ripristina)
                // riparte dall'inquadratura corrente.
                let onlyStraighten = old.straightenDegrees != new.straightenDegrees &&
                    old.zoom == new.zoom && old.quarterTurns == new.quarterTurns
                startCropMode(keeping: onlyStraighten ? model.cropTarget(for: bottomOriginCropRect) : nil)
            }
            if old.panX != new.panX || old.panY != new.panY || old.zoom != new.zoom ||
                old.straightenDegrees != new.straightenDegrees || old.quarterTurns != new.quarterTurns {
                cloneSource = nil
            }
        }
        .onChange(of: cloneMode) { _, enabled in
            hoverPoint = nil; NSCursor.arrow.set()
            if enabled && cropping { resetView() }
        }
        .onChange(of: model.isLoading) { _, loading in
            if loading { dragOrigin = nil; magnifyOrigin = nil; hoverPoint = nil }
            if loading { resetView(); viewState.tool = .composition }
        }
    }

    private var canvasColor: Color {
        switch canvasBackground {
        case "white": return .white
        case "black": return .black
        default: return Color(white: 0.45)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: Binding(get: { model.preset.id }, set: { id in
            if let p = Preset.all.first(where: { $0.id == id }) { model.selectPreset(p) }
        })) {
            ForEach(Platform.allCases, id: \.self) { platform in
                Section(isExpanded: expansion(for: platform)) {
                    ForEach(Preset.all.filter { $0.platform == platform }) { preset in
                        presetRow(preset)
                    }
                } header: {
                    Text(L10n.text(platform.rawValue))
                }
            }
        }
        .disabled(model.isLoading)
        // La selezione deve restare visibile: si apre il gruppo del formato attivo.
        .onAppear { expandedPlatforms.insert(model.preset.platform) }
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    }

    private func expansion(for platform: Platform) -> Binding<Bool> {
        Binding(get: { expandedPlatforms.contains(platform) },
                set: { if $0 { expandedPlatforms.insert(platform) } else { expandedPlatforms.remove(platform) } })
    }

    private func presetRow(_ preset: Preset) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.localizedName)
                Text(preset.sizeDescription).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
        } icon: {
            Image(systemName: preset.aspectSymbol)
        }
        .tag(preset.id)
        .accessibilityIdentifier("preset-\(preset.id)")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker(L10n.text("Strumento"), selection: $viewState.tool) {
                ForEach(EditorTool.allCases) { tool in Text(tool.title).tag(tool) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .disabled(editingDisabled)
            .help(L10n.text("Strumento"))
            .accessibilityIdentifier("editor-mode")
        }
        // Comandi frequenti e inspector in un gruppo; Esporta, unica azione
        // prominente, da sola sul bordo trailing (massimo tre gruppi).
        ToolbarItemGroup(placement: .primaryAction) {
            Button(L10n.text("Ruota 90°"), systemImage: "rotate.left", action: model.rotate)
                .help(L10n.text("Ruota 90° (⌘L)"))
                .accessibilityIdentifier("rotate-image")
                .disabled(editingDisabled)
            Button(L10n.text("Inspector"), systemImage: "sidebar.trailing") { viewState.inspectorVisible.toggle() }
                .help(L10n.text("Mostra o nascondi inspector"))
                .accessibilityIdentifier("toggle-inspector")
        }
        #if compiler(>=6.2)
        EditorToolbarSeparator()
        #endif
        ToolbarItem(placement: .primaryAction) {
            Button(L10n.text("Esporta…"), systemImage: "square.and.arrow.up", action: model.export)
                .editorPrimaryAction()
                .help(L10n.text("Esporta una copia (⇧⌘E)"))
                .accessibilityIdentifier("export-image")
                .disabled(model.document == nil || model.isExporting || model.isLoading)
        }
    }

    // MARK: - Barra di stato

    /// Solo stato breve, come la barra di stato del Finder: nessun controllo.
    private var statusBar: some View {
        HStack(spacing: 8) {
            if model.isLoading || model.isImporting || model.isExporting || model.isRendering {
                ProgressView().controlSize(.small)
            }
            Text(model.status).lineLimit(1).truncationMode(.middle)
                .contentTransition(.opacity)
                .animation(interfaceAnimation, value: model.status)
            Spacer(minLength: 12)
            if model.items.count > 1, let index = model.selectedIndex {
                Text(L10n.format("Foto %d di %d", index + 1, model.items.count)).monospacedDigit()
            }
            if model.document != nil {
                Text(L10n.format("Vista %d%%", Int((viewState.currentScale * 100).rounded()))).monospacedDigit()
            }
            Text("sRGB").monospaced()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder private var canvas: some View {
        if let image = model.preview {
            GeometryReader { proxy in
                let fitted = fittedCanvasSize(in: proxy.size)
                let backing = NSScreen.main?.backingScaleFactor ?? 2
                let fitScale = min(4, max(0.1, Double(fitted.width * backing / CGFloat(model.preset.width))))
                let size = viewState.viewAt100 ? CGSize(width: CGFloat(model.preset.width) * viewState.viewScale / backing, height: CGFloat(model.preset.height) * viewState.viewScale / backing) : fitted
                accessibleCanvas(image: cropping ? (model.cropPreview ?? image) : image, size: size, container: proxy.size)
                    .offset(viewState.viewOffset)
                    .overlay { if cropping, model.cropPreview != nil { CropOverlay(rect: $cropRect, minimum: model.minimumCropSide).frame(width: size.width, height: size.height).position(x: proxy.size.width / 2, y: proxy.size.height / 2) } }
                    .onAppear { viewState.fittedViewScale = fitScale }
                    .onChange(of: fitScale) { _, scale in viewState.fittedViewScale = scale }
            }
            .transition(reduceMotion ? .identity : .opacity)
        } else {
            ContentUnavailableView {
                Label("Dai spazio alle tue foto", systemImage: "crop.rotate")
            } description: {
                Text("Trascina qui una o più foto oppure aprile dal Mac.\nScegli un formato e trova la tua inquadratura.")
            } actions: {
                Button("Apri immagini…", action: model.chooseImage).controlSize(.large)
            }
            .transition(reduceMotion ? .identity : .opacity)
        }
    }

    // Opaque return types give the Swift 6.1 type checker a boundary between
    // rendering, decoration, gestures and accessibility, without AnyView.
    private func fittedCanvasSize(in container: CGSize) -> CGSize {
        let available = CGSize(width: max(1, container.width - 64), height: max(1, container.height - 64))
        let ratio = CGFloat(model.preset.width) / CGFloat(model.preset.height)
        let width = min(available.width, available.height * ratio)
        return CGSize(width: width, height: width / ratio)
    }

    private func canvasLayers(image: NSImage, size: CGSize) -> some View {
        ZStack {
            Image(nsImage: image).resizable().interpolation(.high)
            if model.showGrid { compositionGridOverlay }
            bannerGuide(size: size)
            if !cropping { cloneOverlay(size: size) }
            if model.showDestinationGuides && model.preset.id.hasSuffix("-profile") {
                Circle().stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .allowsHitTesting(false)
            }
        }
    }

    private var compositionGridOverlay: some View {
        Canvas { context, size in
            var path = Path()
            for line in model.gridStyle.lines {
                path.move(to: CGPoint(x: line.start.x * size.width, y: line.start.y * size.height))
                path.addLine(to: CGPoint(x: line.end.x * size.width, y: line.end.y * size.height))
            }
            context.stroke(path, with: .color(.black.opacity(model.gridOpacity * 0.65)), lineWidth: 1.8)
            context.stroke(path, with: .color(.white.opacity(model.gridOpacity)), lineWidth: 0.65)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    @ViewBuilder private func bannerGuide(size: CGSize) -> some View {
        if model.showDestinationGuides && model.preset.id == "youtube-banner" {
            Rectangle().stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .frame(width: size.width * 1235 / 2048, height: size.height * 338 / 1152)
                .overlay(alignment: .bottom) {
                    Text("Area sicura indicativa").font(.caption2).padding(3)
                        .background(.black.opacity(0.5)).foregroundStyle(.white)
                }
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder private func cloneOverlay(size: CGSize) -> some View {
        if cloneMode, let source = cloneSource {
            Image(systemName: "plus.circle")
                .font(.system(size: 22)).foregroundStyle(.white)
                .shadow(color: .black, radius: 2)
                .position(x: source.x * size.width, y: (1 - source.y) * size.height)
                .allowsHitTesting(false)
        }
        if cloneMode {
            let point = hoverPoint ?? cloneTarget
            let diameter = min(size.width, size.height) * CGFloat(cloneRadius * 2)
            Circle().stroke(.black, lineWidth: 3)
                .overlay(Circle().stroke(.white, lineWidth: 1))
                .frame(width: diameter, height: diameter)
                .position(x: point.x * size.width, y: (1 - point.y) * size.height)
                .allowsHitTesting(false)
        }
    }

    private func decoratedCanvas(image: NSImage, size: CGSize) -> some View {
        canvasLayers(image: image, size: size)
            .animation(interfaceAnimation, value: model.gridStyle)
            .frame(width: size.width, height: size.height)
            .clipped()
            .overlay(Rectangle().stroke(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .contentShape(Rectangle())
    }

    private func interactiveCanvas(image: NSImage, size: CGSize) -> some View {
        decoratedCanvas(image: image, size: size)
            .overlay { if !cropping { CanvasPointer(clone: cloneMode).allowsHitTesting(false) } }
            .gesture(panGesture(size: size))
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    if !cloneMode { NSCursor.openHand.set() }
                    if cloneMode {
                        NSCursor.crosshair.set()
                        hoverPoint = normalizedPoint(location, in: size)
                    }
                case .ended: hoverPoint = nil; NSCursor.arrow.set()
                }
            }
            .simultaneousGesture(cloneGesture(size: size))
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { tap in
                guard !cloneMode, !cropping else { return }
                let scale = CGFloat(model.preset.width) / (NSScreen.main?.backingScaleFactor ?? 2) / size.width
                viewState.viewOffset = viewState.viewAt100 ? .zero : CGSize(width: (size.width / 2 - tap.location.x) * scale, height: (size.height / 2 - tap.location.y) * scale)
                viewState.viewScale = 1
                viewState.viewAt100.toggle()
            })
    }

    private func panGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1).onChanged { value in
            guard !model.isLoading, !cloneMode, !cropping else { return }
            if viewState.viewAt100 && CGEventSource.keyState(.combinedSessionState, key: 49) {
                if viewDragOrigin == nil { viewDragOrigin = viewState.viewOffset }
                viewState.viewOffset = CGSize(width: viewDragOrigin!.width + value.translation.width, height: viewDragOrigin!.height + value.translation.height)
                return
            }
            NSCursor.closedHand.set()
            if dragOrigin == nil {
                model.checkpoint(); model.clearCloneStrokes(); cloneSource = nil; dragOrigin = model.edit
            }
            guard let origin = dragOrigin else { return }
            model.pan(from: origin, translationX: Double(value.translation.width / size.width),
                      translationY: -Double(value.translation.height / size.height))
        }.onEnded { _ in dragOrigin = nil; viewDragOrigin = nil; NSCursor.openHand.set() }
    }

    private func cloneGesture(size: CGSize) -> some Gesture {
        SpatialTapGesture().onEnded { value in
            guard !model.isLoading, cloneMode, !cropping else { return }
            canvasFocused = true
            let point = normalizedPoint(value.location, in: size)
            cloneTarget = point
            if NSEvent.modifierFlags.contains(.option) || cloneSource == nil {
                cloneSource = point
            } else if let source = cloneSource {
                model.addClone(source: source, target: point, radius: cloneRadius)
            }
        }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture().onChanged { value in
            guard !model.isLoading, !cropping, !cloneMode else { return }
            if magnifyOrigin == nil {
                model.checkpoint(); model.clearCloneStrokes(); cloneSource = nil; magnifyOrigin = model.edit.zoom
            }
            model.edit.zoom = min(8, max(1, (magnifyOrigin ?? 1) * value.magnification))
        }.onEnded { _ in magnifyOrigin = nil }
    }

    private func normalizedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(1, max(0, point.x / size.width)), y: min(1, max(0, 1 - point.y / size.height)))
    }

    private func accessibleCanvas(image: NSImage, size: CGSize, container: CGSize) -> some View {
        interactiveCanvas(image: image, size: size)
            .position(x: container.width / 2, y: container.height / 2)
            .focusable()
            .focusEffectDisabled()
            .focused($canvasFocused)
            .onMoveCommand(perform: moveCanvas)
            .onKeyPress(.space) {
                guard cloneMode else { return .ignored }
                applyCloneAtTarget()
                return .handled
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Anteprima dell’immagine")
            .accessibilityHint(canvasAccessibilityHint)
            .accessibilityAction(named: Text("Sposta a sinistra")) { move(horizontal: -0.01, vertical: 0) }
            .accessibilityAction(named: Text("Sposta a destra")) { move(horizontal: 0.01, vertical: 0) }
            .accessibilityAction(named: Text("Sposta in alto")) { move(horizontal: 0, vertical: 0.01) }
            .accessibilityAction(named: Text("Sposta in basso")) { move(horizontal: 0, vertical: -0.01) }
            .accessibilityAction(named: Text("Scegli sorgente o applica timbro")) { if cloneMode { applyCloneAtTarget() } }
            .accessibilityIdentifier("image-preview")
    }

    private var canvasAccessibilityHint: String {
        cloneMode
            ? L10n.text("Usa le frecce per spostare la destinazione e Spazio per scegliere la sorgente o applicare un timbro. Le coordinate sono disponibili nei controlli del clone.")
            : L10n.text("Usa le frecce o i pulsanti Sposta foto per spostare l’inquadratura. Usa Zoom per ingrandire.")
    }

    private func moveCanvas(_ direction: MoveCommandDirection) {
        switch direction {
        case .left: move(horizontal: -0.01, vertical: 0)
        case .right: move(horizontal: 0.01, vertical: 0)
        case .up: move(horizontal: 0, vertical: 0.01)
        case .down: move(horizontal: 0, vertical: -0.01)
        @unknown default: break
        }
    }

    private func resetView() { viewState.resetView(); cropping = false; model.cancelCrop() }

    private var bottomOriginCropRect: CGRect {
        CGRect(x: cropRect.minX, y: 1 - cropRect.maxY, width: cropRect.width, height: cropRect.height)
    }

    private func startCropMode(keeping target: EditState? = nil) {
        resetView(); cloneMode = false; model.beginCrop(keeping: target)
        cropRect = CGRect(x: model.cropSelection.minX, y: 1-model.cropSelection.maxY, width: model.cropSelection.width, height: model.cropSelection.height)
        cropping = true
    }

    // MARK: - Inspector

    private var inspector: some View {
        Form {
            formatSection
            switch viewState.tool {
            case .composition: compositionSection
            case .crop: cropSection
            case .tools: cloneSection
            }
            if viewState.tool != .tools { guidesSection }
            exportSection
        }
        .formStyle(.grouped)
        .animation(interfaceAnimation, value: cloneMode)
        .animation(interfaceAnimation, value: model.edit.cloneStrokes.isEmpty)
    }

    private var formatSection: some View {
        Section(L10n.text("Formato social")) {
            LabeledContent(L10n.text("Piattaforma"), value: L10n.text(model.preset.platform.rawValue))
            LabeledContent(L10n.text("Dimensioni"), value: model.preset.sizeDescription)
            DisclosureGroup(L10n.text("Fonte del formato"), isExpanded: $showSourceDetails) {
                Text(model.preset.referenceNote).font(.callout)
                Text(model.preset.verificationNote).font(.caption).foregroundStyle(.secondary)
                Link(L10n.text("Specifiche della piattaforma ↗"), destination: model.preset.referenceURL)
            }
        }
    }

    private var straightenAdjustment: some View {
        PrecisionAdjustment(title: L10n.text("Livella"), value: model.edit.straightenDegrees, range: -45...45, step: 0.1, initial: 0, digits: 1, unit: "°", update: model.setStraighten)
    }

    @ViewBuilder private var autoLevelControls: some View {
        Button(model.isAutoLeveling ? L10n.text("Analisi…") : L10n.text("Autolivella"), systemImage: "level", action: model.autoLevel)
            .disabled(model.isAutoLeveling || model.isLoading)
            .accessibilityIdentifier("auto-level")
            .help(L10n.text("Stima l’orizzonte sul Mac. Controlla il risultato; puoi annullare con ⌘Z."))
        if let message = model.autoLevelMessage {
            Text(message).font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("auto-level-result")
        }
    }

    private var compositionSection: some View {
        Section(L10n.text("Inquadratura")) {
            PrecisionAdjustment(title: L10n.text("Zoom"), value: model.edit.zoom, range: 1...8, step: 0.01, initial: 1, digits: 0, unit: "×", update: model.setZoom)
            straightenAdjustment
            autoLevelControls
            DisclosureGroup(L10n.text("Sposta foto")) {
                HStack {
                    Button(L10n.text("Sposta a sinistra"), systemImage: "arrow.left") { move(horizontal: -0.01, vertical: 0) }
                    Button(L10n.text("Sposta a destra"), systemImage: "arrow.right") { move(horizontal: 0.01, vertical: 0) }
                    Button(L10n.text("Sposta in alto"), systemImage: "arrow.up") { move(horizontal: 0, vertical: 0.01) }
                    Button(L10n.text("Sposta in basso"), systemImage: "arrow.down") { move(horizontal: 0, vertical: -0.01) }
                }
                .labelStyle(.iconOnly)
                Text("Passi dell’1% della tela. Puoi anche trascinare la foto o usare le frecce quando l’anteprima ha il focus.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(L10n.text("Azzera modifiche"), systemImage: "arrow.counterclockwise", action: model.reset)
                .help(L10n.text("Ripristina l’inquadratura iniziale ed elimina i timbri. Puoi annullare con ⌘Z."))
        }
        .disabled(editingDisabled)
    }

    private var cropSection: some View {
        Section(L10n.text("Ritaglia")) {
            straightenAdjustment
            autoLevelControls
            HStack {
                Spacer()
                Button(L10n.text("Annulla")) { cropping = false; model.cancelCrop(); viewState.tool = .composition }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.text("Applica")) {
                    model.applyCrop(bottomOriginCropRect)
                    cropping = false; viewState.tool = .composition
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.cropPreview == nil)
            }
        }
        .disabled(editingDisabled)
    }

    private var guidesSection: some View {
        Section(L10n.text("Guide")) {
            Picker(L10n.text("Griglia"), selection: $model.gridStyle) {
                ForEach(CompositionGrid.allCases) { grid in Text(grid.title).tag(grid) }
            }
            .accessibilityIdentifier("composition-grid")
            if model.showGrid {
                LabeledContent(L10n.text("Opacità griglia")) {
                    ResettableSlider(value: $model.gridOpacity, range: 0.2...1, initial: 0.75)
                        .accessibilityLabel(L10n.text("Opacità griglia"))
                }
            }
            if model.preset.id == "youtube-banner" || model.preset.id.hasSuffix("-profile") {
                Toggle(L10n.text("Guide della destinazione"), isOn: $model.showDestinationGuides)
                    .help(L10n.text("Mostra guide indicative del ritaglio. Non vengono esportate."))
            }
        }
        .disabled(editingDisabled)
    }

    private var cloneSection: some View {
        Section(L10n.text("Timbro clone")) {
            Toggle(isOn: $cloneMode) {
                Label { Text("Strumento clone") } icon: { CloneToolIcon().frame(width: 16, height: 16) }
            }
            .help(L10n.text("Strumento clone"))
            .accessibilityIdentifier("clone-mode")
            if cloneMode {
                Text(cloneSource == nil ? L10n.text("Fai clic nella foto per scegliere la sorgente.") : L10n.text("Fai clic sull’area da coprire. Tieni premuto Opzione e fai clic per cambiare sorgente."))
                    .font(.callout).foregroundStyle(.secondary)
                LabeledContent(L10n.text("Raggio del timbro")) {
                    HStack {
                        ResettableSlider(value: $cloneRadius, range: 0.005...0.15, initial: 0.035)
                            .accessibilityLabel(L10n.text("Raggio del timbro"))
                        Text(cloneRadius.formatted(.percent.precision(.fractionLength(1)))).monospacedDigit()
                    }
                }
                Text("Percentuale del lato corto dell’immagine.").font(.caption).foregroundStyle(.secondary)
                Button(L10n.text("Cambia sorgente")) { cloneSource = nil }
                    .disabled(cloneSource == nil)
                DisclosureGroup(L10n.text("Posizione del timbro")) {
                    Text("Coordinate in percentuale, dall’angolo in basso a sinistra.").font(.caption).foregroundStyle(.secondary)
                    coordinateFields(title: L10n.text("Destinazione"), point: $cloneTarget)
                    if let source = cloneSource {
                        coordinateFields(title: L10n.text("Sorgente"), point: Binding(get: { source }, set: { cloneSource = $0 }))
                    }
                    HStack {
                        Button(L10n.text("Usa destinazione come sorgente")) { cloneSource = cloneTarget }
                        Button(L10n.text("Applica timbro")) { applyCloneAtTarget() }.disabled(cloneSource == nil)
                    }
                }
            }
            if !model.edit.cloneStrokes.isEmpty {
                Button(L10n.format("Elimina timbri (%d)", model.edit.cloneStrokes.count)) { model.checkpoint(); model.clearCloneStrokes() }
            }
            Text("Cambiare inquadratura o formato elimina i timbri. Premi ⌘Z per annullare la modifica e recuperarli.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(editingDisabled)
    }

    private var exportSection: some View {
        Section {
            Picker(L10n.text("Nitidezza schermo"), selection: Binding(get: { model.edit.outputSharpening }, set: model.setSharpening)) {
                Text("Nessuna").tag(OutputSharpening.none)
                Text("Bassa").tag(OutputSharpening.low)
                Text("Standard").tag(OutputSharpening.standard)
                Text("Alta").tag(OutputSharpening.high)
            }
            .disabled(editingDisabled)
            Picker(L10n.text("Formato file"), selection: $model.png) {
                Text("JPEG").tag(false)
                Text("PNG").tag(true)
            }
            .pickerStyle(.segmented)
            if !model.png {
                LabeledContent(L10n.text("Qualità JPEG")) {
                    HStack {
                        ResettableSlider(value: $model.jpegQuality, range: 0.6...1, initial: 0.95)
                            .accessibilityLabel(L10n.text("Qualità JPEG"))
                        Text(model.jpegQuality.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit()
                    }
                }
            }
            DisclosureGroup(L10n.text("Dettagli esportazione"), isExpanded: $showExportDetails) {
                Text("Qualità JPEG iniziale: 95%. Colori sRGB; trasparenza su bianco, anche in PNG. Il JPEG usa compressione con perdita; PNG conserva i pixel del risultato. Ingrandire non aggiunge dettaglio. I social possono ricomprimere i file.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.text("Esportazione"))
        } footer: {
            Text("L’originale resta intatto. Le modifiche restano in memoria finché sostituisci il set o chiudi l’app.")
                .font(.caption).foregroundStyle(.secondary)
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
                    .labelsHidden()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                TextField(title, value: Binding(get: { unit == "×" ? value * 100 : value }, set: { _ = update(unit == "×" ? $0 / 100 : $0, true) }), format: .number.precision(.fractionLength(digits)))
                    .textFieldStyle(.roundedBorder).frame(width: 65).monospacedDigit().labelsHidden()
                    .accessibilityLabel(title)
                Text(unit == "×" ? "%" : unit).foregroundStyle(.secondary).padding(.trailing, 12)
                Button { _ = update(initial, true) } label: { Image(systemName: "arrow.counterclockwise") }
                    .help(L10n.format("Reimposta %@", title)).accessibilityLabel(L10n.format("Reimposta %@", title))
                    .disabled(value == initial)
            }
            HStack(spacing: 6) {
                Button { _ = update(value - step, true) } label: { Image(systemName: "minus") }
                    .accessibilityLabel(L10n.format("Riduci %@", title)).disabled(value <= range.lowerBound)
                ResettableSlider(value: Binding(get: { value }, set: { _ = update($0, false) }), range: range, initial: initial, begin: {}, checkpoint: { _ = update($0, true) })
                    .accessibilityLabel(title)
                Button { _ = update(value + step, true) } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L10n.format("Aumenta %@", title)).disabled(value >= range.upperBound)
            }.controlSize(.small)
        }
    }
}
