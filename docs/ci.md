# Toolchain della CI

La CI seleziona **Xcode 27.1, build 27A9275**, come l'ambiente locale usato per lo sviluppo e le verifiche del 12 novembre 2026. Il runner è `xcode-27` (Apple Silicon, macOS 27), attualmente in anteprima pubblica su GitHub Actions.

Il workflow imposta `DEVELOPER_DIR=/Applications/Xcode_27.1.app/Contents/Developer` per tutto il job: test e build usano lo stesso Xcode. Lo step iniziale controlla che il percorso esista, verifica versione e build esatte e stampa anche la versione Swift. Se GitHub rimuove quella toolchain, il job fallisce subito con un messaggio esplicito, invece di usare un'altra versione predefinita.

Prima la CI sceglieva soltanto `macos-15` e stampava `swift --version`: nei job della PR #1 il compilatore effettivo era quello di Xcode 16.4. La scelta attuale rende intenzionale la toolchain e documenta il disallineamento corretto. Non è previsto un secondo job con un compilatore precedente.

Il deployment target del prodotto resta **macOS 14** e il linguaggio resta Swift 5 con toolchain Swift 6. La versione del sistema usato per compilare non costituisce una prova del funzionamento su macOS 14 o su Intel, che richiedono verifiche separate.

Per aggiornare Xcode:

1. Verificare le versioni e i percorsi disponibili nell'immagine ufficiale del runner.
2. Allineare la toolchain locale scelta per il progetto, `DEVELOPER_DIR` e il controllo versione/build nello step Toolchain.
3. Eseguire `swift test --enable-code-coverage` e `./scripts/build-app.sh` con la nuova toolchain; verificare poi l'esito della CI remota.
4. Aggiornare questo documento con versione, build ed eventuale nuovo runner. L'aggiornamento dell'immagine GitHub resta indipendente dal pin di Xcode: non si tratta di un ambiente interamente congelato.

Fonti ufficiali consultate il 12 novembre 2026: [immagini disponibili](https://github.com/actions/runner-images#available-images), [software dell'immagine Xcode 27](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md#xcode). L'immagine `macos-26` elenca toolchain 26.x: per la 27.1 si usa l'immagine dedicata, senza installazioni o download di Xcode nel job.

## Verifica della configurazione

Il workflow è stato letto con Ruby/Psych e il suo step Toolchain estratto e verificato con `bash -n`. Lo step è riuscito sulla toolchain locale Xcode 27.1/build 27A9275, usando il percorso locale equivalente `/Applications/Xcode.app/Contents/Developer`. Due prove negative, percorso assente e risposta di una versione diversa, hanno prodotto l'errore atteso.

Nel branch CI basato su `main` sono passati tutti i 38 test con coverage ed è riuscita la build release dell'app. Queste prove non attestano l'assegnazione del runner GitHub in anteprima né l'esecuzione remota, il cui risultato è nei check della PR. Nessuna modifica al comportamento dell'app e nessun nuovo collaudo UI richiesto da questo intervento.
