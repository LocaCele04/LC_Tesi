# Registro dei Test Automatici

La verifica del livello di persistenza viene eseguita tramite la libreria `flutter_test` affiancata a `sqflite_common_ffi`, così da poter eseguire i test direttamente in ambiente desktop senza emulatore. Ogni singolo test viene eseguito su un'istanza di database isolata e ripulita prima dell'esecuzione, garantendo risultati deterministici e indipendenti dall'ordine di lancio.

## 1. `test/database_integrita_test.dart` (17 test)

Questa suite valida direttamente lo schema relazionale definito in `DatabaseHelper`, verificando che il database stesso impedisca l'inserimento di dati incoerenti indipendentemente dalla logica applicativa:

* **Configurazione e struttura:** verifica che i vincoli di chiave esterna siano attivi (`PRAGMA foreign_keys = ON`) e che vengano create correttamente tutte le 16 tabelle e i 16 indici previsti.

* **Inserimenti validi:** popola in sequenza tutte e 16 le tabelle con dati completi e facoltativi (`NULL`), confermando la compatibilità generale dei tipi e delle relazioni.

* **Vincoli di dominio (`CHECK` e `UNIQUE`):** testa il rifiuto automatico di stringhe composte da soli spazi, valori numerici fuori intervallo (lunghezze non positive, voti, temperature, coordinate geografiche, anni), con accettazione dei voti decimali (es. 4.5), stringhe non appartenenti ai domini enumerati, date di calendario inesistenti e duplicazioni della stessa specie all'interno della medesima pescata. Verifica inoltre l'esclusività (`XOR`) della tabella `Foto`, affinché ogni immagine appartenga esattamente a uno tra pescata, cattura memorabile ed esca, mai a più di uno o a nessuno.

* **Ambienti:** verifica la presenza dei quattro ambienti di base, il rifiuto di nomi vuoti e di duplicati che differiscono solo per maiuscole e minuscole, il rifiuto di spot con un ambiente non registrato e l'accettazione di un ambiente esistente scritto con maiuscole diverse.

* **Integrità incrociata tra specie:** controlla che le chiavi esterne composte impediscano di associare a una cattura, a un riepilogo o a un obiettivo una caratteristica appartenente a una specie diversa.

* **Azioni referenziali:** verifica il blocco dell'eliminazione (`ON DELETE RESTRICT`) per categorie, ambienti e specie ancora referenziati, la propagazione automatica delle rinomine (`ON UPDATE CASCADE`) su tabelle figlie e chiavi composte, e la pulizia coerente (`ON DELETE SET NULL` e `ON DELETE CASCADE`) alla rimozione di esche, spot e pescate.

## 2. `test/territorio_repository_test.dart` (9 test)

Questa suite verifica la traduzione tra righe SQLite e modelli immutabili Dart, nonché la logica applicativa incapsulata in `TerritorioRepository`:

* **Gestione degli Ambienti:** verifica che vengano restituiti gli ambienti di base più quelli aggiunti in ordine alfabetico (con rimozione degli spazi superflui dal nome), il rifiuto di un duplicato con maiuscole diverse, la propagazione della rinomina agli spot collegati e il blocco dell'eliminazione di un ambiente ancora in uso.

* **Gestione delle Categorie:** testa l'inserimento e il recupero ordinato alfabeticamente, l'aggiornamento con rinomina della chiave primaria (verificando che gli spot collegati ereditino il nuovo nome) e il blocco dell'eliminazione quando la categoria è associata ad almeno uno spot.

* **Gestione di Spot e Coordinate:** verifica il salvataggio transazionale di uno spot con le relative coordinate GPS ordinate e il calcolo automatico della lunghezza in metri tramite formula di Haversine quando non inserita manualmente. Testa inoltre la ricerca parametrica combinata (per categoria, ambiente *case-insensitive*, voto minimo e lunghezza massima), l'aggiornamento di uno spot esistente con risincronizzazione dei punti GPS e l'eliminazione completa di spot e categoria una volta liberata.

## 3. `test/statistiche_repository_test.dart` (8 test)

Questa suite verifica in isolamento le operazioni CRUD, i filtri parametrici e la coerenza transazionale gestiti da `StatisticheRepository`:

* **Gestione delle Specie:** testa inserimento, recupero ordinato alfabeticamente e ricerca testuale *case-insensitive*, oltre alla propagazione a cascata della rinomina (`ON UPDATE CASCADE`) e al blocco dell'eliminazione quando la specie è referenziata (`ON DELETE RESTRICT`).

* **Caratteristiche e Obiettivi:** verifica salvataggio, aggiornamento, filtri combinati (per specie, nome, anno e distinzione tra obiettivi generici e legati a una caratteristica) ed eliminazione. Controlla inoltre il rifiuto di obiettivi associati a una caratteristica appartenente a una specie diversa.

* **Riepiloghi Specie e Dettagli:** testa il salvataggio e l'aggiornamento transazionale di `RiepilogoSpecie` con la risincronizzazione dei relativi `DettaglioRiepilogo` per caratteristica, il filtraggio per pescata o specie, l'eliminazione e il blocco di associazioni incrociate tra specie non coerenti.

## 4. `test/battute_repository_test.dart` (8 test)

Questa suite valida in isolamento tutte le operazioni CRUD, i filtri parametrici e le transazioni multi-tabella gestite da `BattuteRepository`:

* **Esche e Pianificazioni:** verifica inserimento, aggiornamento, ordinamento, filtri (ricerca testuale *case-insensitive* per le esche; filtro per spot e intervallo di date per le pianificazioni) ed eliminazione.

* **Pescate:** testa il salvataggio transazionale della sessione insieme alle esche associate e alle foto allegate, i filtri combinati ambientali e temporali con eventuale limite sul numero di risultati, e la pulizia a cascata dei figli collegati all'eliminazione mantenendo integri spot ed esche.

* **Spot obbligatorio:** verifica che una nuova pescata senza spot (o con nome vuoto) venga rifiutata e che non si possa togliere lo spot a una pescata esistente; verifica poi che, eliminando lo spot, la pescata resti nello storico con spot nullo (`ON DELETE SET NULL`) e sia ancora modificabile.

* **Catture Memorabili e Dettaglio Completo:** verifica il salvataggio e il filtraggio delle catture con caratteristiche e foto, il blocco dell'associazione di caratteristiche appartenenti a una specie diversa e la ricostruzione dell'intero aggregato `Pescata` (comprensivo di esche, foto, catture e riepiloghi specie) tramite `getPescataCompleta`.