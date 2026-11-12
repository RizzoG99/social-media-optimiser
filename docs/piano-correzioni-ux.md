# Piano delle correzioni UX/UI e testi

12 novembre 2026. Ambito: rilievi dei due audit dell'interfaccia e dei testi.

1. Proteggere le modifiche non esportate prima di sostituire l'immagine, con possibilità di esportare, scartare o annullare; conservare la sessione se import/export falliscono.
2. Offrire comandi da tastiera e controlli accessibili per pan e clone; istruzioni dell'anteprima coerenti con lo strumento attivo.
3. Aggiungere valori numerici e ripristino separato per zoom/livellamento; mostrare il raggio reale del timbro e coordinate inseribili senza clic sul canvas.
4. Separare guide della destinazione e griglia; mantenere impostazioni essenziali e comando di esportazione visibili, con dettagli secondari espandibili.
5. Correggere etichette, istruzioni undo e messaggi sui limiti; rendere esplicita l'affidabilità delle fonti per destinazione.
6. Predisporre risorse italiane localizzabili, lingua del bundle e copia delle risorse nella build. Nessuna traduzione aggiuntiva in questo intervento.
7. Aggiungere test per protezione della sessione, modifiche geometriche e metadati delle fonti; eseguire suite con coverage e build release.
8. Collaudare una copia isolata dell'app reale, registrando prove e limiti in `verifica.md`.
9. Lanciare un nuovo agent per la revisione indipendente; applicare i rilievi fondati e ripetere i controlli pertinenti.

Le dimensioni dei preset e la pipeline di rendering restano quelle esistenti. Le fonti non accessibili non vengono promosse a requisiti ufficiali.

## Esito

Implementazione completata. Revisione indipendente eseguita da un nuovo agent e tutti i rilievi concreti applicati, inclusa la protezione dei callback dei gesti durante l'import. Suite finale: 38 test passati; build release riuscita. Collaudo reale di import, modifica numerica, annulla/ripristina, clone via coordinate ed export; verificata la conferma prima della sostituzione e il suo annullamento. Esiti e limiti, compreso il ramo UI completo “Esporta e apri” ancora da completare, sono riportati in `verifica.md`. Italiano predisposto come risorsa di sviluppo; nessuna traduzione aggiuntiva inclusa.
