# Localizzazione

L'app include risorse complete in **italiano e inglese**, anche per menu e dialoghi AppKit. La lingua di sviluppo e fallback è `it`; macOS sceglie la lingua dalle preferenze dell’utente. Non è previsto un selettore interno. I numeri seguono la locale di sistema anche quando la lingua dell’app è inglese.

- `Sources/SocialFrame/Resources/it.lproj/Localizable.strings`: etichette SwiftUI, nomi dei formati, messaggi dinamici, aiuti e accessibilità.
- `Sources/SocialCore/Resources/it.lproj/Localizable.strings`: descrizioni degli errori, senza dipendenza dalla UI.
- `Sources/SocialFrame/Resources/<lingua>.lproj/Localizable.stringsdict`: regole plurali per i conteggi del set (per esempio "Un file esiste già" contro "%d file esistono già"). Prevale su `.strings` per le stesse chiavi; le voci di `.strings` restano come ripiego e per il test di parità delle chiavi (`EditorShellTests`). Una chiave con conteggio va aggiunta in entrambi i file e in tutte le lingue.
- `L10n.text` e `L10n.format` risolvono i testi dinamici nel bundle del target. File utente, ID dei preset e nomi dei simboli restano dati.
- Le etichette SwiftUI letterali fanno lookup nel bundle principale: `build-app.sh` copia **tutte** le cartelle linguistiche UI, oltre ai due bundle SwiftPM, e aggiorna `CFBundleLocalizations` dall'elenco delle risorse UI.

Per aggiungere una lingua, creare `<codice>.lproj/Localizable.strings` in entrambi i target, traducendo le chiavi italiane e preservando placeholder (`%@`, `%d`, `%.1f`, `%%`). Ricompilare e verificare testi dinamici, menu, pannelli, numeri, scorciatoie, accessibilità e layout nella lingua scelta. Non dichiarare supportata una lingua con risorse incomplete.

Quando si aggiunge un testo aggiornare le risorse del target e quelle UI per le etichette SwiftUI. L'aggiunta di file `.strings` non implica una traduzione automatica. I numeri dei campi usano la locale di sistema.

Riferimenti Apple: [LocalizedStringKey](https://developer.apple.com/documentation/swiftui/localizedstringkey), [CFBundleDevelopmentRegion](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledevelopmentregion).
