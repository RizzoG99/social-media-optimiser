import SwiftUI

/// Pellicola del set (F-12): miniature del risultato modificato, nel livello
/// contenuto come la striscia di Foto. Nessun vetro: solo controlli di sistema.
struct FilmstripView: View {
    @ObservedObject var model: EditorModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(model.items) { item in
                        FilmstripCell(item: item, status: model.photoStatus(of: item),
                                      selected: item.id == model.selectedItemID, focused: focused) {
                            focused = true
                            model.select(item.id)
                        }
                        .id(item.id)
                        .contextMenu {
                            Button(L10n.text("Rimuovi dal set"), systemImage: "minus.circle", role: .destructive) {
                                model.requestRemoval(of: item.id)
                            }
                            .disabled(model.isExporting)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(height: 92)
            // Come il canvas: niente miniature sotto l'inspector flottante.
            .clipped()
            .focusable()
            // L'anello di sistema seguirebbe la vista di scorrimento sotto
            // l'inspector: il focus si mostra sulla miniatura selezionata.
            .focusEffectDisabled()
            .focused($focused)
            .onMoveCommand { direction in
                switch direction {
                case .left: model.selectPrevious()
                case .right: model.selectNext()
                default: break
                }
            }
            .onDeleteCommand {
                if let id = model.selectedItemID { model.requestRemoval(of: id) }
            }
            .onChange(of: model.selectedItemID) { _, id in
                guard let id else { return }
                if reduceMotion { proxy.scrollTo(id, anchor: .center) }
                else { withAnimation(.easeInOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .center) } }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.text("Pellicola"))
            .accessibilityIdentifier("filmstrip")
        }
    }
}

private struct FilmstripCell: View {
    let item: PhotoItem
    let status: PhotoStatus
    let selected: Bool
    let focused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            thumbnail
                .frame(height: 64)
                .frame(minWidth: 48, maxWidth: 140)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(3)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25),
                                      lineWidth: selected ? 3 : 1)
                }
                .overlay(alignment: .topTrailing) { badge.padding(6) }
                .padding(3)
                .overlay {
                    if selected && focused {
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 3)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.url.lastPathComponent)
        .accessibilityLabel(item.url.lastPathComponent)
        .accessibilityValue(statusDescription)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("filmstrip-\(item.url.lastPathComponent)")
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = item.thumbnail {
            Image(nsImage: image).resizable().interpolation(.medium).aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .overlay { ProgressView().controlSize(.small) }
        }
    }

    @ViewBuilder private var badge: some View {
        switch status {
        case .edited:
            Image(systemName: "pencil.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .orange)
                .font(.system(size: 13))
                .shadow(color: .black.opacity(0.4), radius: 1)
                .help(L10n.text("Modificata, non esportata"))
        case .exported:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .font(.system(size: 13))
                .shadow(color: .black.opacity(0.4), radius: 1)
                .help(L10n.text("Esportata"))
        case .unedited:
            EmptyView()
        }
    }

    private var statusDescription: String {
        switch status {
        case .edited: return L10n.text("Modificata, non esportata")
        case .exported: return L10n.text("Esportata")
        case .unedited: return L10n.text("Nessuna modifica")
        }
    }
}
