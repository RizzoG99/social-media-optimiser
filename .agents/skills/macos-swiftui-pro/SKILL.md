---
name: macos-swiftui-pro
description: Design, implement, and review SocialFrame's macOS SwiftUI interface against the current Apple HIG and Liquid Glass (macOS 26/27): window title, toolbar, sidebar, inspector, canvas chrome, menus, controls, and availability fallbacks to macOS 14. Use before writing or reviewing any user-facing view, toolbar item, glass effect, or GlassChrome helper. Excludes pixel correctness and interaction testing.
---

# macOS SwiftUI Pro

Progetta e rivedi l'interfaccia di SocialFrame come una app Mac di sistema: componenti standard, vetro solo nel livello di navigazione, la foto protagonista. Il riferimento visivo è **Foto o Anteprima di macOS**, non una UI a capsule disegnata a mano.

Lavora dalla radice del repository. Leggi [AGENTS.md](../../../AGENTS.md), i requisiti in [docs/requisiti-prodotto.md](../../../docs/requisiti-prodotto.md) e la decisione Liquid Glass in [docs/adr.md](../../../docs/adr.md).

> **Shell superata:** la shell Liquid Glass di novembre 2026 (ADR-012: capsule `glassEffect` in toolbar, `sharedBackgroundVisibility(.hidden)`, `.glass` su ogni comando, titolo "SocialFrame") è stata sostituita da ADR-013 in `docs/adr.md`, che applica questa skill. La voce "Liquid Glass — 12 novembre 2026" di `docs/verifica.md` è il resoconto storico. Non reintrodurre quel pattern; la tabella degli anti-pattern in [editor-shell.md](references/editor-shell.md) resta come riferimento per le revisioni.

## Procedura

1. **Toolchain del ramo.** Leggi `Package.swift`, `Resources/Info.plist` e `.github/workflows/ci.yml`. Il deployment target resta macOS 14 e il linguaggio Swift 5 salvo richiesta esplicita. Se la CI compila con un SDK precedente a macOS 26 (runner `macos-15` senza Xcode fissato), ogni API 26+ richiede anche `#if compiler(>=6.2)`; con Xcode 27.1 fissato basta `#available`.
2. **Preflight.** Prima di scrivere una vista annota: compito principale, unica azione primaria, dove vive ogni comando (toolbar, menu, inspector, menu contestuale) e stati raggiungibili (nessuna foto, caricamento, analisi, errore, disabilitato, export riuscito). Confronta con la schermata equivalente di Foto o Anteprima.
3. **Riferimenti.** Carica solo quelli necessari:
   - [references/hig-macos.md](references/hig-macos.md) — regole HIG e Liquid Glass per finestra, toolbar, sidebar, inspector, materiali, colore, menu, accessibilità. Sempre, per UI nuova o modificata.
   - [references/liquid-glass-api.md](references/liquid-glass-api.md) — API e disponibilità verificate sull'SDK, fallback macOS 14/15, pattern di codice. Per ogni API successiva a macOS 14.
   - [references/editor-shell.md](references/editor-shell.md) — anatomia obiettivo della finestra editor e anti-pattern della shell attuale. Per modifiche a `EditorView`, `GlassChrome`, `SocialFrameApp` o ai comandi.
4. **Implementa** la modifica più piccola che rispetti le regole. Prima i container di sistema (`NavigationSplitView`, `.inspector`, `Form`, `List`, `toolbar`), poi gli stili di sistema, per ultimo un effetto personalizzato isolato in `GlassChrome.swift`.
5. **Quality gate** (sotto). Poi collauda l'app reale con [macos-interaction-validation](../macos-interaction-validation/SKILL.md) e annota esiti e limiti in [docs/verifica.md](../../../docs/verifica.md).

## Quality gate

Una modifica UI è completa solo quando ogni voce è verificata o dichiarata aperta:

- **Livelli:** nessun vetro nel livello contenuto (foto, campi, slider, righe dell'inspector); nessun vetro sopra vetro; nessuna superficie disegnata a mano dietro elementi della toolbar.
- **Toolbar:** al massimo tre gruppi; simboli di sistema senza bordo e senza dimensioni forzate; una sola azione prominente, sul lato trailing; ogni elemento è anche un comando del menu, con scorciatoia dove sensato.
- **Finestra:** titolo = nome del documento; preset e dimensioni nel sottotitolo; nessuna intestazione duplicata dentro il canvas; nessun comando in una barra inferiore.
- **Sidebar e inspector:** `List` con selezione persistente e `Label` con simbolo; inspector in `Form` `.grouped`, un'etichetta per ogni controllo, pulsanti di sistema a larghezza naturale.
- **Disponibilità:** ogni API recente ha un ramo macOS 14 funzionalmente completo.
- **Aspetto e accessibilità:** tema chiaro e scuro; Riduci trasparenza, Aumenta contrasto, Mostra bordi, Riduci movimento; VoiceOver con nomi distinti; flusso completo da tastiera.
- **Stress:** finestra alla larghezza minima (overflow della toolbar), testi italiani e inglesi lunghi, inspector aperto e chiuso.
- **Ingegneria:** `swift test --enable-code-coverage` e `./scripts/build-app.sh` passano.

Se non puoi eseguire la prova visiva, dichiaralo e lascia aperta la voce: una suite verde non dimostra conformità HIG.

## Output di revisione

Per una revisione elenca i rilievi per gravità, con file e riga, regola HIG o API violata, impatto e correzione concreta. Riassunto in coda. Per audit su screenshot usa [macos-ui-audit](../macos-ui-audit/SKILL.md).
