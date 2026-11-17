---
name: macos-ui-audit
description: Audit SocialFrame screenshots or the running app against the current macOS HIG and Liquid Glass guidance, producing severity-ranked findings with native SwiftUI fixes. Use when the user shares a screenshot or asks to critique, audit, or compare the interface with system Mac apps.
---

# Audit UI macOS

Valuta l'interfaccia come un designer di prodotto Mac e un ingegnere SwiftUI: diretto, basato su ciò che si vede, con correzioni realizzabili.

Prima dell'audit leggi [hig-macos.md](../macos-swiftui-pro/references/hig-macos.md) e la tabella degli anti-pattern in [editor-shell.md](../macos-swiftui-pro/references/editor-shell.md). Ogni rilievo cita la regola HIG o la riga della tabella che lo sostiene; se non trovi una regola, dichiara che è un giudizio di gusto.

## Metodo

Per ogni schermata, nell'ordine:

1. **Livelli:** dove c'è vetro? Ogni superficie in vetro appartiene al livello funzionale? Ci sono vetro sopra vetro, capsule disegnate a mano o vetro su controlli del contenuto?
2. **Finestra e titolo:** il titolo descrive il documento? Il contesto è nel sottotitolo? Ci sono intestazioni duplicate o azioni nella barra inferiore?
3. **Toolbar:** zone leading/centro/trailing, numero di gruppi, simboli senza bordo, una sola azione prominente, testo e icone non mescolati, comportamento alla larghezza minima.
4. **Sidebar:** selezione visibile, simboli, colore d'accento, livelli di gerarchia, sezioni.
5. **Inspector:** form raggruppato, etichette per ogni controllo, gerarchia delle sezioni, pulsanti di sistema, contenuto non tagliato sotto la toolbar.
6. **Canvas:** la foto è protagonista, fondo neutro, guide leggibili, nessun effetto UI sui pixel.
7. **Tipografia e colore:** stili di testo di sistema, colore solo per stato o azione primaria, contrasto in chiaro e scuro.
8. **Accessibilità:** nomi accessibili, focus da tastiera, Riduci trasparenza, Aumenta contrasto, Mostra bordi, Riduci movimento (dichiara cosa non è verificabile dallo screenshot).
9. **Coerenza con il Mac:** confronto con Foto e Anteprima; comandi presenti anche nei menu.

Distingui ciò che lo screenshot mostra da ciò che deduci dal codice; per le deduzioni indica file e riga.

## Formato dei rilievi

```markdown
**[Gravità: Critica | Alta | Media | Bassa] — Titolo breve**
- **Problema:** cosa si vede.
- **Regola:** regola HIG o riga anti-pattern, con fonte.
- **Correzione:** API o componente nativo da usare, con fallback macOS 14 se serve.
```

Raggruppa per `## Schermata: <nome>`, in ordine di gravità.

## Sezioni finali obbligatorie

```markdown
## Sintesi
- Problemi principali di struttura (livelli, toolbar, finestra)
- Problemi principali di controlli e inspector
- Accessibilità
- Verifiche non possibili da screenshot

## Interventi rapidi
## Interventi strutturali
## Proposta di layout (anatomia della finestra in una tabella)
```

Per applicare le correzioni usa [macos-swiftui-pro](../macos-swiftui-pro/SKILL.md).
