# Scelta Architetturale: Migrazioni del Database

## 1. Contesto e problema

Il database di *Diario di Pesca* vive solo sul telefono dell'utente, in un file SQLite. Lo **schema** (tabelle, colonne, vincoli, indici) è scritto in `DatabaseHelper.onCreate`, che SQLite esegue una volta sola: quando il file non esiste ancora.

Durante lo sviluppo lo schema è cambiato spesso (per esempio sono state tolte la temperatura dell'aria della pescata e l'esposizione al sole dello spot) e ogni volta il database del telefono è stato cancellato e ricreato. Con i dati reali questo non è più possibile: cancellare il database vorrebbe dire perdere pescate, spot e foto.

Serve quindi un modo per **portare un database esistente allo schema nuovo senza perdere i dati**, ogni volta che una nuova versione dell'app cambia lo schema. Il meccanismo deve:

1. funzionare sia per chi installa l'app da zero sia per chi la aggiorna, anche saltando più versioni;
2. non lasciare mai il database a metà: un aggiornamento riesce del tutto o non cambia nulla;
3. non violare i vincoli di integrità (chiavi esterne, CHECK) che il database garantisce;
4. essere verificabile con test automatici, senza dover installare versioni vecchie dell'app su un telefono.

---

## 2. Alternative considerate

| Soluzione | Come funziona | Vantaggi | Svantaggi per questo progetto |
| :--- | :--- | :--- | :--- |
| **Ricreare il database** | A ogni cambio di schema si cancella il file e lo si ricrea. | Nessun codice da scrivere. | Cancella tutti i dati: accettabile solo in sviluppo. |
| **Esportare e reimportare** | Si salvano i dati (per esempio con il backup), si ricrea il database e si reimportano. | Riusa il backup. | Il formato del backup cambia con lo schema: ogni versione dovrebbe saper leggere tutte le precedenti, cioè le migrazioni si spostano nel backup. Più lento e con più punti di errore. |
| **Libreria ORM con migrazioni** (es. `drift`) | Lo schema è scritto in Dart; la libreria confronta le versioni e genera parte del codice di aggiornamento. | Strumenti di verifica dello schema già pronti. | Richiede di riscrivere tutto il livello dati (24 tabelle, query, test) e un generatore di codice. Sproporzionato rispetto al guadagno. |
| **Migrazioni versionate con `onUpgrade`** *(scelta)* | Il database ha un numero di versione; per ogni versione nuova si scrive un passaggio che aggiorna lo schema della precedente. `sqflite` esegue i passaggi mancanti all'apertura. | Integrato in `sqflite`, nessuna dipendenza nuova; ogni modifica è esplicita, piccola e provata da un test. | Ogni passaggio va scritto a mano, e alcune modifiche in SQLite richiedono di ricostruire la tabella. |

---

## 3. Soluzione adottata

### 3.1 Versione dello schema

SQLite conserva nel file un numero intero, `user_version`, che `sqflite` usa come **versione dello schema**. L'app dichiara la versione che si aspetta in `DatabaseHelper.versioneSchema`. All'apertura:

* se il file non esiste, `onCreate` crea lo schema completo dell'ultima versione;
* se il file è a una versione precedente, `onUpgrade` esegue i passaggi mancanti, in ordine;
* se il file è a una versione **più recente** dell'app (per esempio dopo aver reinstallato un'app vecchia), l'apertura fallisce senza toccare nulla (`onDowngrade`).

La versione 1 è lo schema descritto in `schema_logico_relazionale.md`.

### 3.2 Passaggi di aggiornamento

I passaggi stanno in `lib/data/migrazioni.dart`, in una mappa indicizzata per **versione di arrivo**: il passaggio `2` porta un database dalla versione 1 alla 2. Aggiornando dalla versione 1 alla 4 si eseguono, in ordine, i passaggi 2, 3 e 4. Ogni cambio di schema richiede quindi tre cose:

1. modificare `onCreate`, per chi installa da zero;
2. alzare `versioneSchema` di 1;
3. aggiungere il passaggio, che fa sul database esistente le stesse modifiche.

Un passaggio può anche **correggere i dati**, per esempio riempire una colonna nuova calcolandola da quelle esistenti.

### 3.3 Cosa sa fare SQLite e cosa no

SQLite modifica uno schema esistente con `ALTER TABLE` solo in pochi casi: aggiungere una colonna, rinominare una colonna o una tabella, eliminare una colonna senza vincoli. Per tutto il resto (cambiare un CHECK, una chiave esterna, un `NOT NULL`, eliminare una colonna con vincoli) va **ricostruita la tabella** con la procedura raccomandata da SQLite:

1. creare la tabella nuova con un nome provvisorio;
2. copiarvi i dati;
3. eliminare la tabella vecchia;
4. rinominare la nuova con il nome originale;
5. ricreare gli indici.

La procedura è nella funzione `ricostruisciTabella` di `migrazioni.dart`.

Una colonna aggiunta con `ALTER TABLE ADD COLUMN` finisce in fondo alla definizione della tabella. In `onCreate` va scritta quindi **come ultima riga del `CREATE TABLE`**, dopo i vincoli; altrimenti il database aggiornato e quello nuovo avrebbero le colonne in ordine diverso, e il test della §4 lo segnala.

### 3.4 Chiavi esterne spente durante l'aggiornamento

È il punto più delicato. Con le chiavi esterne attive, eliminare la tabella vecchia (punto 3) equivale a eliminarne tutte le righe e fa partire le **azioni a cascata**: ricostruendo `Spot`, per esempio, verrebbero cancellate le coordinate e le pianificazioni di tutti gli spot, e le pescate perderebbero lo spot.

Le chiavi esterne si possono spegnere solo fuori da una transazione, mentre `sqflite` esegue creazione e aggiornamento dentro una transazione. Per questo:

* in `onConfigure`, prima della transazione, le chiavi esterne vengono **spente**;
* creazione o aggiornamento avvengono nella transazione;
* alla fine dell'aggiornamento, `PRAGMA foreign_key_check` controlla che nessuna riga sia rimasta senza la riga a cui punta: se ce n'è anche una sola, l'aggiornamento fallisce;
* in `onOpen`, a transazione conclusa, le chiavi esterne vengono **accese** per tutto il resto dell'uso dell'app.

### 3.5 Tutto o niente

Tutti i passaggi di un aggiornamento avvengono nella stessa transazione. Se un passaggio fallisce, o se il controllo delle chiavi esterne trova un problema, la transazione viene annullata: il database resta alla versione di partenza con i dati intatti, e l'app segnala l'errore invece di lavorare su un database a metà.

---

## 4. Verifica con i test

I test (`test/migrazioni_test.dart`) usano le **fotografie dello schema**: file `test/schemi/schema_vN.json` con le istruzioni `CREATE` di tabelle e indici della versione N e i dati iniziali (ambienti e condizioni di base). Da una fotografia si ricrea un database "installato con la versione N", senza bisogno della vecchia versione dell'app.

* **Schema attuale protetto.** `onCreate` deve creare esattamente lo schema della fotografia della versione attuale. Se qualcuno modifica `onCreate` senza alzare la versione, il test fallisce e ricorda di scrivere la migrazione. Quando la versione viene alzata, la prima esecuzione del test scatta la fotografia nuova e chiede di controllarla e salvarla nel repository.
* **Ogni versione precedente si aggiorna correttamente.** Per ogni fotografia di una versione precedente, il test crea il database, lo apre con l'app attuale (che lo aggiorna) e lo confronta con un database creato da zero: devono avere stesse tabelle, colonne, vincoli, indici e dati iniziali.
* **Meccanismo.** Con passaggi finti si verifica che ricostruire una tabella non tocchi le tabelle figlie e lasci le chiavi esterne funzionanti, che un passaggio che fallisce o che lascia righe orfane annulli tutto l'aggiornamento, che un passaggio mancante blocchi l'aggiornamento e che un database più recente dell'app non venga aperto.

---

## 5. Conseguenze

* **Vantaggi:** i dati dell'utente sopravvivono agli aggiornamenti dell'app; ogni cambio di schema è documentato da un passaggio numerato; gli errori annullano l'aggiornamento invece di corrompere il database; i test scoprono subito una modifica allo schema senza migrazione.
* **Costi:** ogni modifica allo schema richiede di scriverla due volte (in `onCreate` e nel passaggio) e, per i casi che `ALTER TABLE` non copre, di ricostruire la tabella copiando la sua definizione.
* **Backup:** il file di backup conterrà la versione dello schema da cui proviene. Un backup di una versione precedente si ripristinerà in un database di quella versione, che le migrazioni porteranno poi alla versione attuale: il backup non deve saper leggere i formati vecchi.
* **Sviluppo:** `DatabaseHelper.resetPerSviluppo()` resta solo per ripartire da un database vuoto, non serve più per applicare uno schema nuovo.
