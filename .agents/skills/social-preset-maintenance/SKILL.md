---
name: social-preset-maintenance
description: Add or update SocialFrame social-image presets by checking official destination-specific dimensions, formats, file-size constraints, verification dates, UI notes, and catalog tests. Use for preset/specification maintenance, not general editor interactions or image-rendering changes.
---

# Mantenere i preset social

Lavora dalla radice del repository. Leggi [AGENTS.md](../../../AGENTS.md) e [docs/preset-e-fonti.md](../../../docs/preset-e-fonti.md). I preset sono target di esportazione; non tutti sono requisiti di caricamento.

## Fonti e destinazioni

- Identifica piattaforma e superficie precisa: post organico, pubblicità, profilo personale, pagina aziendale, banner, storia, miniatura video o Shorts. Non trasferire specifiche da una superficie all’altra.
- Cerca fonti ufficiali aggiornate e apri la pagina che sostiene il dato. Registra URL, data, pixel/rapporto, formati, peso e differenze desktop/mobile dichiarate. Se richiede login o non espone il dato, mantienilo “non verificato”.
- Distingui requisito obbligatorio, raccomandazione ufficiale e scelta pratica. Una nuova raccomandazione non invalida automaticamente il formato precedente: valuta l’impatto prima di rimuovere preset o cambiarne ID.
- Non copiare nella skill dimensioni o soglie destinate a cambiare: mantienile nel catalogo e nella documentazione delle fonti.

## Aggiornamenti collegati

Controlla e aggiorna quanto necessario:

1. `Sources/SocialCore/Preset.swift`: ID, piattaforma, destinazione e dimensioni.
2. `Sources/SocialFrame/PresetInfo.swift`: fonte e nota pertinenti alla destinazione; una fonte generica non sostiene automaticamente ogni formato della piattaforma.
3. `Sources/SocialFrame/EditorView.swift`: eventuali guide e data mostrata. Aggiorna la data soltanto per fonti ricontrollate; se il campo attuale è globale, rappresenta correttamente una verifica parziale senza dichiarare aggiornato l’intero catalogo.
4. [docs/preset-e-fonti.md](../../../docs/preset-e-fonti.md): catalogo, provenienza, affidabilità e limiti, collegando la fonte specifica alla destinazione interessata. Aggiorna requisiti/decisioni se cambia il comportamento di prodotto.

Per nuove safe area verifica che le guide restino indicative e non entrino nell’export. Le copertine video restano immagini statiche. Un limite in byte documentato non è automaticamente imposto dall’app: verifica il codice prima di promettere un file sempre caricabile. La manutenzione delle specifiche non richiede upload o accessi ad account.

## Verifica e consegna

Esegui i controlli pertinenti; per cambi di codice completa anche suite e build:

```sh
swift test --filter SocialCoreTests.testCatalogAndOrientation
swift test --filter SocialCoreTests.testEveryPresetExportTypeSizeAndProfile
swift test --enable-code-coverage
./scripts/build-app.sh
```

Aggiungi scenari solo se quelli esistenti non distinguono il comportamento nuovo da quello errato. Verifica ID unici, piattaforme e JPEG/PNG decodificati alle dimensioni attese. L’export corretto non dimostra l’accettazione lato social.

Riporta prima/dopo, fonti ufficiali aperte, data e dati ancora non verificati. Annota in [docs/verifica.md](../../../docs/verifica.md) solo i controlli eseguiti. Un caricamento reale richiede un compito esplicito e non garantisce il comportamento di altri account/client. Non promettere assenza di ricompressione.
