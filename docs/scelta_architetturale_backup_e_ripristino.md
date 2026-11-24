# Scelta Architetturale: Backup e Ripristino

## 1. Contesto e problema

Tutti i dati di *Diario di Pesca* stanno solo sul telefono: il database SQLite e, quando ci saranno, i file delle foto. Un telefono perso, rotto o sostituito vuol dire perdere anni di pescate. Serve quindi un **backup** che l'utente possa conservare fuori dal telefono e un **ripristino** che rimetta tutto com'era, anche su un altro telefono (REQ-FUN-14, REQ-FUN-15).

Il meccanismo deve:

1. salvare **tutti** i dati, comprese tabelle aggiunte in futuro, senza dover ricordare di aggiornare il backup a ogni modifica dello schema;
2. funzionare **senza rete** e senza un server dello sviluppatore, come il resto dell'app;
3. permettere di conservare il file **fuori dal telefono**, per esempio su Google Drive;
4. ripristinare anche un backup creato da una **versione precedente** dell'app, e rifiutare quello di una versione più recente;
5. non perdere i dati attuali se il ripristino **fallisce** a metà;
6. non trattare credenziali: il file contiene dati personali, e l'app non deve conoscerne la destinazione più del necessario.

Il backup sostituisce anche l'import dello storico (ex REQ-FUN-19), lo strumento usato una volta sola per caricare nell'app i dati raccolti prima: da qui in avanti i dati si spostano solo con il backup.

## 2. Alternative considerate

**Contenuto del backup**

| Alternativa | Pro | Contro |
| :--- | :--- | :--- |
| **Dati in JSON** (una lista di oggetti per tabella), come previsto nella prima versione dei requisiti | File leggibile a occhio; indipendente da SQLite | Serializzazione e ripopolamento da scrivere e mantenere per 26 tabelle, nell'ordine delle chiavi esterne; ogni modifica dello schema va riportata nel backup, e una dimenticanza perde dati senza errori; il ripristino deve rifare a mano ciò che le migrazioni fanno già |
| **Copia del file SQLite** in un archivio ZIP con un manifesto e le foto *(scelta)* | Copia esatta di tutto, tabelle future comprese, senza codice per tabella; la versione dello schema è già nel file (`user_version`) e le migrazioni esistenti aggiornano un backup vecchio; il controllo di integrità lo fa SQLite | Il file non si legge senza uno strumento per SQLite (per esempio DBeaver); funziona solo tra app che usano lo stesso schema, cosa vera per un backup dell'app stessa |

**Destinazione del file**

| Alternativa | Pro | Contro |
| :--- | :--- | :--- |
| **API di Google Drive** con accesso OAuth 2.0, come previsto nella prima versione dei requisiti | Caricamento in una cartella dedicata senza passaggi per l'utente | Progetto Google Cloud, schermata di consenso e verifica dell'app da parte di Google; gestione di account, token e loro scadenza; rete obbligatoria; vincola il backup a Google Drive |
| **Finestra di sistema per salvare e scegliere i file** (Storage Access Framework di Android, tramite `file_picker`) *(scelta)* | Nessuna credenziale nell'app; l'utente sceglie la memoria del telefono, Google Drive (se ne ha l'app) o un altro servizio; funziona offline; la stessa finestra serve per scegliere il file da ripristinare | Il backup non è automatico e l'utente sceglie ogni volta la cartella |

**Copia del database aperto**

| Alternativa | Pro | Contro |
| :--- | :--- | :--- |
| Chiudere il database e copiare il file | Semplice | Le schermate aperte perdono la connessione; con il journal WAL una parte delle modifiche può essere ancora fuori dal file |
| **`VACUUM INTO`** *(scelta)*, con la copia del file come riserva | Copia coerente e compatta con il database aperto, in un'unica istruzione SQL | Richiede SQLite 3.27 (Android 11 e successivi): sulle versioni precedenti si riversa il WAL nel file (`PRAGMA wal_checkpoint`) e si copia il file, sicuro perché durante il backup l'app non scrive |

## 3. Soluzione adottata

### 3.1 Il file di backup

Un archivio ZIP chiamato con data e ora (es. `diario_pesca_backup_2026-11-24_1050.zip`) con:

* `manifesto.json`: `formato` (`diario-pesca-backup`), `versioneFormato` (oggi 1), `creatoIl`, `versioneSchema`;
* `diario_pesca.db`: la copia del database;
* `foto/…`: i file delle foto, con lo stesso percorso relativo alla cartella delle foto che il database registra (REQ-DES-03), così che dopo il ripristino i riferimenti tornino validi. La cartella si riempirà con il `FotoService`; oggi il backup non contiene foto.

Il manifesto distingue due versioni diverse: `versioneFormato` riguarda la struttura dell'archivio (cambierebbe, per esempio, aggiungendo un file), `versioneSchema` quella del database (cambia a ogni migrazione).

### 3.2 Divisione dei compiti

* `BackupService` produce e legge **solo byte**: non sa dove finisce il file. Così si prova nei test senza finestre di sistema.
* `BackupScreen` chiede all'utente dove salvarlo e quale file ripristinare (`file_picker`), mostra il riepilogo e chiede conferma.
* `DatabaseHelper.sostituisciCon` sostituisce il file del database: è l'unico punto che conosce il percorso del file e come aprirlo.

### 3.3 Controlli prima del ripristino

`BackupService.leggi` controlla tutto **senza toccare i dati dell'app** e, se qualcosa non va, lancia `BackupNonValido` con il motivo in parole per l'utente:

1. il file è un archivio ZIP con `manifesto.json` e `diario_pesca.db`;
2. il manifesto è del formato giusto e la sua versione non è più recente di quella che l'app conosce;
3. il database inizia con l'intestazione di SQLite, supera `PRAGMA integrity_check` e la sua versione dello schema non è più recente di quella dell'app;
4. nessuna foto ha un percorso che esce dalla sua cartella (`../`) o assoluto, così un archivio costruito ad arte non può scrivere altrove.

Il database viene aperto in una copia temporanea, senza creazione né migrazioni, solo per questi controlli e per contare spot, divieti, pescate e catture del riepilogo.

### 3.4 Sostituzione senza perdere i dati

`DatabaseHelper.sostituisciCon`:

1. chiude il database;
2. rinomina il file attuale in `diario_pesca.db.prima_del_ripristino` e toglie i file di journal e WAL, che appartengono al file vecchio;
3. copia al suo posto il database del backup e lo apre come a ogni avvio: se è di una versione precedente, le **migrazioni** lo aggiornano (vedi `scelta_architetturale_migrazioni_del_database.md`);
4. se l'apertura o una migrazione fallisce, toglie il file nuovo e rimette al suo posto quello vecchio, poi rilancia l'errore: l'app resta con i dati di prima;
5. se tutto va bene, cancella la copia messa da parte.

Solo dopo il database viene sostituita la cartella delle foto. Al termine la schermata fa rileggere il database a tutti i provider dei dati, così ogni sezione mostra i dati ripristinati.

### 3.5 Dati personali

Il file contiene tutti i dati personali dell'utente. L'app non lo invia da nessuna parte: lo salva dove l'utente sceglie e non conserva credenziali. Nel repository del progetto il `.gitignore` esclude `*backup*.zip`, oltre al database e ai file dello storico.

## 4. Verifica con i test

`test/backup_service_test.dart` lavora su file veri in una cartella temporanea e verifica: il viaggio completo backup → modifica dei dati → ripristino; la copia di riserva senza `VACUUM INTO`; il ripristino di un backup della versione 1 dello schema, aggiornato dalle migrazioni; un ripristino fallito che lascia i dati di prima; le foto; tutti i casi di file non valido. `test/backup_screen_test.dart` verifica la schermata con un servizio finto: conferma di data e ora del salvataggio, riepilogo, conferma prima di sostituire, messaggi di errore. Il dettaglio è nel registro dei test (suite 22 e 23).

## 5. Conseguenze

* Il backup non va aggiornato quando cambia lo schema: copia sempre tutto, e le migrazioni pensano ai backup vecchi.
* Un backup non si può aprire con una versione dell'app più vecchia di quella che l'ha creato: l'utente deve aggiornare l'app, come per il database stesso.
* Il backup è manuale: ricordarsi di farlo spetta all'utente (in futuro l'app potrebbe mostrare la data dell'ultimo backup o ricordarlo dopo un certo numero di pescate).
* Il ripristino sostituisce tutto, non unisce due diari: unire i dati di due telefoni richiederebbe regole per i doppioni e resta fuori dalla versione base (INT-COM-02).
