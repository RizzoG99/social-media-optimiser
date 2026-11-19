# Rilascio su GitHub Releases

`scripts/release.sh <X.Y.Z>` prepara `.build/release/SocialFrame-<X.Y.Z>.dmg`: app universale (arm64 + x86_64, macOS 14+), firmata **Developer ID** con hardened runtime, notarizzata da Apple e con il ticket applicato al DMG. Chi la scarica la apre senza avvisi di Gatekeeper, anche offline.

Una build ad hoc (`build-app.sh`) va bene solo sul Mac che l'ha compilata: scaricata da un altro Mac viene bloccata ("impossibile aprire") e da macOS 15 il clic destro › Apri non basta più. Non pubblicarla come release.

## Prerequisiti (una tantum)

1. **Certificato Developer ID Application.** Il certificato *Apple Distribution* serve solo per l'App Store: per la distribuzione esterna serve *Developer ID Application*. Lo crea il titolare dell'account su [developer.apple.com › Certificates](https://developer.apple.com/account/resources/certificates/list) (oppure Xcode › Settings › Accounts › Manage Certificates › +). Controllo: `security find-identity -v -p codesigning` deve elencare `Developer ID Application: …`.
2. **Credenziali di notarizzazione nel portachiavi.** Con una password specifica per app ([account.apple.com](https://account.apple.com) › Accesso e sicurezza) e il Team ID:

   ```sh
   xcrun notarytool store-credentials socialframe-notary --apple-id <email> --team-id <TEAM_ID>
   ```

   In alternativa una chiave API di App Store Connect (`--key`, `--key-id`, `--issuer`). Il nome del profilo si cambia con `SOCIALFRAME_NOTARY_PROFILE`.

## Procedura

1. Unire il lavoro su `main`, aggiornarlo e partire da un albero pulito (lo script avvisa se ci sono modifiche non committate).
2. `swift test --enable-code-coverage`.
3. `./scripts/release.sh 0.2.0`. Lo script:
   - compila universale con `SOCIALFRAME_UNIVERSAL=1 ./scripts/build-app.sh` (stesso bundle di sviluppo: SDK registrato con `vtool`, localizzazioni, solo le risorse dei target dell'app);
   - scrive nel bundle `CFBundleShortVersionString` = versione e `CFBundleVersion` = numero di commit (`git rev-list --count HEAD`); `Resources/Info.plist` nel repository non cambia;
   - firma con `--options runtime --timestamp` (nessun entitlement: l'app non usa sandbox, rete né JIT);
   - crea il DMG con il collegamento ad Applicazioni, lo firma, lo invia a `notarytool` e attende l'esito, applica e convalida il ticket, verifica con `spctl`;
   - stampa SHA-256 e i comandi di pubblicazione.
4. Aprire il DMG su un account o un Mac diverso e provare l'app (apri, modifica, esporta) prima di pubblicare.
5. Pubblicare:

   ```sh
   git tag v0.2.0 && git push origin v0.2.0
   gh release create v0.2.0 .build/release/SocialFrame-0.2.0.dmg --title "SocialFrame 0.2.0" --generate-notes
   ```

Se la notarizzazione fallisce: `xcrun notarytool log <submission-id> --keychain-profile socialframe-notary` mostra il motivo.

`./scripts/release.sh 0.2.0 --unsigned` produce lo stesso DMG con firma ad hoc e senza notarizzazione, per provare il pacchetto senza certificato.

## Verifica dello script — 19 novembre 2026

- `--unsigned`: DMG da 2,8 MB con `SocialFrame.app` e collegamento ad `Applications`; binario `x86_64 arm64`, `minos 14.0`, `sdk 27.0` su entrambe le architetture; versione 0.2.0 (build 27); risorse senza `SocialFrame_SocialCoreTests.bundle`; `codesign --verify --deep --strict` riuscito.
- Hardened runtime: una copia firmata ad hoc con `--options runtime` (identificatore distinto) si avvia e resta in esecuzione. Provato solo l'avvio, non modifica ed export.
- Percorso firmato: senza identità Developer ID lo script si ferma prima della build con il messaggio sui prerequisiti. **Firma Developer ID, notarizzazione e `spctl` non sono stati eseguiti**: sul Mac di sviluppo c'è solo il certificato Apple Distribution.
- `hdiutil` stampa un avviso di deprecazione (macOS 27 suggerisce `diskutil image`); il DMG viene creato correttamente.
- La build x86_64 non è stata avviata su un Mac Intel o con Rosetta.
