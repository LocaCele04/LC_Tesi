# Registro dei Test Automatici

La verifica del livello di persistenza viene eseguita tramite la libreria `flutter_test` affiancata a `sqflite_common_ffi`, così da poter eseguire i test direttamente in ambiente desktop senza emulatore. Ogni singolo test viene eseguito su un'istanza di database isolata e ripulita prima dell'esecuzione, garantendo risultati deterministici e indipendenti dall'ordine di lancio.

## 1. `test/database_integrita_test.dart` (15 test)

Questa suite valida direttamente lo schema relazionale definito in `DatabaseHelper`, verificando che il database stesso impedisca l'inserimento di dati incoerenti indipendentemente dalla logica applicativa:

* **Configurazione e struttura:** verifica che i vincoli di chiave esterna siano attivi (`PRAGMA foreign_keys = ON`) e che vengano create correttamente tutte le 15 tabelle e i 14 indici previsti.

* **Inserimenti validi:** popola in sequenza tutte e 15 le tabelle con dati completi e facoltativi (`NULL`), confermando la compatibilità generale dei tipi e delle relazioni.

* **Vincoli di dominio (`CHECK` e `UNIQUE`):** testa il rifiuto automatico di stringhe composte da soli spazi, valori numerici fuori intervallo (lunghezze non positive, voti, temperature, coordinate geografiche, anni), stringhe non appartenenti ai domini enumerati, date di calendario inesistenti e duplicazioni della stessa specie all'interno della medesima pescata. Verifica inoltre l'esclusività (`XOR`) della tabella `Foto`, affinché ogni immagine appartenga a una pescata oppure a una cattura memorabile, mai a entrambe o a nessuna.

* **Integrità incrociata tra specie:** controlla che le chiavi esterne composte impediscano di associare a una cattura, a un riepilogo o a un obiettivo una caratteristica appartenente a una specie diversa.

* **Azioni referenziali:** verifica il blocco dell'eliminazione (`ON DELETE RESTRICT`) per categorie e specie ancora referenziate, la propagazione automatica delle rinomine (`ON UPDATE CASCADE`) su tabelle figlie e chiavi composte, e la pulizia coerente (`ON DELETE SET NULL` e `ON DELETE CASCADE`) alla rimozione di esche, spot e pescate.

## 2. `test/territorio_repository_test.dart` (7 test)

Questa suite verifica la traduzione tra righe SQLite e modelli immutabili Dart, nonché la logica applicativa incapsulata in `TerritorioRepository`:

* **Gestione delle Categorie:** testa l'inserimento e il recupero ordinato alfabeticamente, l'aggiornamento con rinomina della chiave primaria (verificando che gli spot collegati ereditino il nuovo nome) e il blocco dell'eliminazione quando la categoria è associata ad almeno uno spot.

* **Gestione di Spot e Coordinate:** verifica il salvataggio transazionale di uno spot con le relative coordinate GPS ordinate e il calcolo automatico della lunghezza in metri tramite formula di Haversine quando non inserita manualmente. Testa inoltre la ricerca parametrica combinata (per categoria, ambiente *case-insensitive*, voto minimo e lunghezza massima), l'aggiornamento di uno spot esistente con risincronizzazione dei punti GPS e l'eliminazione completa di spot e categoria una volta liberata.

## 3. `test/statistiche_repository_test.dart` (7 test)

Questa suite verifica in isolamento le operazioni CRUD, i filtri parametrici e la coerenza transazionale gestiti da `StatisticheRepository`:

* **Gestione delle Specie:** testa inserimento, recupero ordinato alfabeticamente e ricerca testuale *case-insensitive*, oltre alla propagazione a cascata della rinomina (`ON UPDATE CASCADE`) e al blocco dell'eliminazione quando la specie è referenziata (`ON DELETE RESTRICT`).

* **Caratteristiche e Obiettivi:** verifica salvataggio, aggiornamento, filtri combinati (per specie, nome, anno e distinzione tra obiettivi generici e legati a una caratteristica) ed eliminazione. Controlla inoltre il rifiuto di obiettivi associati a una caratteristica appartenente a una specie diversa.

* **Riepiloghi Specie e Dettagli:** testa il salvataggio e l'aggiornamento transazionale di `RiepilogoSpecie` con la risincronizzazione dei relativi `DettaglioRiepilogo` per caratteristica, il filtraggio per pescata o specie, l'eliminazione e il blocco di associazioni incrociate tra specie non coerenti.

## 4. `test/battute_repository_test.dart` (7 test)

Questa suite valida in isolamento tutte le operazioni CRUD, i filtri parametrici e le transazioni multi-tabella gestite da `BattuteRepository`:

* **Esche e Pianificazioni:** verifica inserimento, aggiornamento, ordinamento, filtri (ricerca testuale *case-insensitive* per le esche; filtro per spot e intervallo di date per le pianificazioni) ed eliminazione.

* **Pescate:** testa il salvataggio transazionale della sessione insieme alle esche associate e alle foto allegate, i filtri combinati ambientali e temporali con eventuale limite sul numero di risultati, e la pulizia a cascata dei figli collegati all'eliminazione mantenendo integri spot ed esche.

* **Catture Memorabili e Dettaglio Completo:** verifica il salvataggio e il filtraggio delle catture con caratteristiche e foto, il blocco dell'associazione di caratteristiche appartenenti a una specie diversa e la ricostruzione dell'intero aggregato `Pescata` (comprensivo di esche, foto, catture e riepiloghi specie) tramite `getPescataCompleta`.