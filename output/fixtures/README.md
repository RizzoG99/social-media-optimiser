# Campioni per autolivellamento

Fixture sintetica riproducibile cielo/mare con orizzonte inizialmente orizzontale, conservata in `Tests/SocialCoreTests/Fixtures/horizon-level.png`.

- `horizon-plus8-before.png` e `horizon-minus8-before.png`: inclinazioni note di +8° e −8°.
- `horizon-*-after.png`: risultato della correzione mentre l’angolo iniziale è parte dello stato di editing.
- `horizon-*-after-import.png`: risultato dopo aver aperto il file già storto come nuovo originale, senza alcuna conoscenza della rotazione usata per generarlo. È il flusso da provare nell’app.

Rigenerazione dal repository:

```sh
SOCIALFRAME_FIXTURE_OUTPUT="$PWD/output/fixtures" swift test --filter HorizonScenarioTests
```

I test misurano nei pixel la pendenza del bordo cielo/mare su colonne distanti e richiedono residuo inferiore a 1,5°. Esecuzione locale 12/11/2026: residuo 0° sui due casi di editing, circa 0,11° e 0° sui due casi di nuova importazione. Valori limitati dalla risoluzione e dal campionamento; non costituiscono una garanzia sulle fotografie reali. L’export non contiene le griglie di anteprima.
