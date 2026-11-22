# Registro dei Test Automatici

La verifica del livello di persistenza viene eseguita tramite la libreria `flutter_test` affiancata a `sqflite_common_ffi`, così da poter eseguire i test direttamente in ambiente desktop senza emulatore. Ogni singolo test viene eseguito su un'istanza di database isolata e ripulita prima dell'esecuzione, garantendo risultati deterministici e indipendenti dall'ordine di lancio. Le suite dalla 9 alla 16 verificano invece lo stato dell'interfaccia (Riverpod) e le schermate, la 17 l'aggiornamento dello schema tra versioni.

## 1. `test/database_integrita_test.dart` (20 test)

Questa suite valida direttamente lo schema relazionale definito in `DatabaseHelper`, verificando che il database stesso impedisca l'inserimento di dati incoerenti indipendentemente dalla logica applicativa:

* **Configurazione e struttura:** verifica che i vincoli di chiave esterna siano attivi (`PRAGMA foreign_keys = ON`) e che vengano create correttamente tutte le 24 tabelle e i 19 indici previsti.

* **Inserimenti validi:** popola in sequenza tutte e 24 le tabelle con dati completi e facoltativi (`NULL`), confermando la compatibilità generale dei tipi e delle relazioni.

* **Vincoli di dominio (`CHECK` e `UNIQUE`):** testa il rifiuto automatico di stringhe composte da soli spazi, valori numerici fuori intervallo (lunghezze non positive, voti, temperature, coordinate geografiche, anni), con accettazione dei voti decimali (es. 4.5), stringhe non appartenenti ai domini enumerati, date di calendario inesistenti e duplicazioni della stessa specie all'interno della medesima pescata. Verifica inoltre l'esclusività (`XOR`) della tabella `Foto`, affinché ogni immagine appartenga esattamente a uno tra pescata, cattura memorabile ed esca, mai a più di uno o a nessuno.

* **Ambienti:** verifica la presenza dei quattro ambienti di base, il rifiuto di nomi vuoti e di duplicati che differiscono solo per maiuscole e minuscole, il rifiuto di spot con un ambiente non registrato e l'accettazione di un ambiente esistente scritto con maiuscole diverse.

* **Condizioni:** verifica le condizioni e i valori di base con il loro ordine e i collegamenti agli ambienti (il Lago prevede solo il Meteo); il rifiuto di condizioni e valori duplicati senza distinzione di maiuscole, ammettendo lo stesso nome in condizioni diverse; il rifiuto di un secondo valore per la stessa condizione in una pescata e di un valore attribuito alla condizione sbagliata (FK composta). Nelle azioni referenziali verifica il blocco dell'eliminazione di un valore usato (anche tramite la cascata dalla sua condizione), l'eliminazione a cascata di una condizione mai usata con valori e collegamenti, la propagazione della rinomina di un ambiente ai collegamenti e la pulizia delle condizioni di una pescata eliminata.

* **Meteo:** verifica l'unicità delle celle e di una riga per cella e giorno (o ora), il rifiuto di fonti non valide, date inesistenti, pioggia negativa, ore in formato errato e direzioni del vento fuori intervallo; verifica che eliminando una pescata sparisca solo il suo collegamento al meteo (l'archivio resta) e che eliminando una cella sparisca il suo archivio.

* **Integrità incrociata tra specie:** controlla che le chiavi esterne composte impediscano di associare a una cattura, a un riepilogo o a un obiettivo una caratteristica appartenente a una specie diversa.

* **Azioni referenziali:** verifica il blocco dell'eliminazione (`ON DELETE RESTRICT`) per categorie, ambienti e specie ancora referenziati, la propagazione automatica delle rinomine (`ON UPDATE CASCADE`) su tabelle figlie e chiavi composte, e la pulizia coerente (`ON DELETE SET NULL` e `ON DELETE CASCADE`) alla rimozione di esche, spot e pescate.

## 2. `test/territorio_repository_test.dart` (10 test)

Questa suite verifica la traduzione tra righe SQLite e modelli immutabili Dart, nonché la logica applicativa incapsulata in `TerritorioRepository` (aggiornamento di `battuto` compreso, tramite `QueryCondivise`):

* **Gestione degli Ambienti:** verifica che vengano restituiti gli ambienti di base più quelli aggiunti in ordine alfabetico (con rimozione degli spazi superflui dal nome), il rifiuto di un duplicato con maiuscole diverse, la propagazione della rinomina agli spot collegati e il blocco dell'eliminazione di un ambiente ancora in uso.

* **Gestione delle Categorie:** testa l'inserimento e il recupero ordinato alfabeticamente, l'aggiornamento con rinomina della chiave primaria (verificando che gli spot collegati ereditino il nuovo nome) e il blocco dell'eliminazione quando la categoria è associata ad almeno uno spot.

* **Gestione di Spot e Coordinate:** verifica il salvataggio transazionale di uno spot con le relative coordinate GPS ordinate e il calcolo automatico della lunghezza in metri tramite formula di Haversine quando non inserita manualmente. Testa inoltre la ricerca parametrica combinata (per categoria, ambiente *case-insensitive*, voto minimo e lunghezza massima), l'aggiornamento di uno spot esistente con risincronizzazione dei punti GPS e l'eliminazione completa di spot e categoria una volta liberata.

* **Condizioni al cambio di ambiente:** verifica che `getCondizioniNonPreviste` segnali le condizioni usate dalle pescate di uno spot e non previste dal nuovo ambiente (e nessuna se il nuovo ambiente le prevede tutte), e che il cambio di ambiente non tocchi i valori già salvati.

## 3. `test/pescate_repository_test.dart` (11 test)

Questa suite valida le operazioni, i filtri e le transazioni multi-tabella gestite da `PescateRepository`, l'unico componente che scrive pescate, riepiloghi, catture memorabili e pianificazioni:

* **Pianificazioni:** verifica inserimento, aggiornamento, filtro per spot e per intervallo di date ed eliminazione.

* **Pescate:** testa il salvataggio transazionale della pescata insieme ai valori delle condizioni, alle esche associate e alle foto allegate, la rilettura dei valori nell'ordine delle condizioni, l'aggiornamento automatico dello stato `battuto` dello spot, i filtri combinati (fascia oraria, valori di condizione, periodo) con eventuale limite sul numero di risultati, il rifiuto di due valori per la stessa condizione, di valori non salvati e di valori attribuiti alla condizione sbagliata, e la pulizia a cascata dei figli collegati all'eliminazione mantenendo integri spot ed esche.

* **Spot obbligatorio:** verifica che una nuova pescata senza spot (o con nome vuoto) venga rifiutata e che non si possa togliere lo spot a una pescata esistente; verifica poi che, eliminando lo spot, la pescata resti nello storico con spot nullo (`ON DELETE SET NULL`) e sia ancora modificabile.

* **Catture Memorabili e Dettaglio Completo:** verifica il salvataggio e il filtraggio delle catture con caratteristiche e foto, il cambio di specie in modifica, il blocco dell'associazione di caratteristiche appartenenti a una specie diversa, la creazione al volo di esche e caratteristiche nella stessa transazione della pescata (tramite `CatalogoRepository`) e la ricostruzione dell'intero aggregato `Pescata` tramite `getPescataCompleta`.

* **Riepiloghi Specie e Dettagli:** testa il salvataggio e l'aggiornamento dei riepiloghi con i dettagli per caratteristica attraverso `salvaPescata`, il rifiuto di un dettaglio superiore al totale, di una caratteristica di un'altra specie e della stessa specie ripetuta nella pescata, l'assenza di dati parziali dopo una transazione fallita e la rimozione dei riepiloghi; la creazione, nella stessa transazione, di una specie scritta al momento e il riuso di una esistente scritta con maiuscole e spazi diversi.

## 4. `test/catalogo_repository_test.dart` (10 test)

Questa suite verifica `CatalogoRepository`, che gestisce le anagrafiche personali del pescatore:

* **Specie:** testa inserimento, recupero ordinato alfabeticamente, ricerca testuale *case-insensitive* ed eliminazione; verifica poi, con una pescata reale, il blocco dell'eliminazione di una specie usata (`ON DELETE RESTRICT`), la propagazione della rinomina a caratteristiche, obiettivi e riepiloghi (`ON UPDATE CASCADE`) e l'eliminazione a cascata di caratteristiche e obiettivi una volta liberata la specie.

* **Caratteristiche:** verifica salvataggio, aggiornamento, filtri per specie e per nome, eliminazione e il blocco del cambio di specie di una caratteristica già usata in un obiettivo.

* **Esche:** verifica inserimento e aggiornamento con zero, una o più foto, ordinamento, ricerca testuale *case-insensitive* ed eliminazione, comprese le foto collegate.

* **Creazione al volo con nome già esistente:** verifica la ricerca per nome senza distinzione di maiuscole e spazi (`getEscaPerNome`, `getCaratteristicaPerNome`); il riuso dell'esca o della caratteristica esistente quando quella nuova ha solo il nome; la `NomeDuplicatoException` (con l'id dell'elemento esistente) quando quella nuova porta foto o una descrizione diverse; l'annullamento completo della pescata o dell'obiettivo che si stava salvando.

* **Condizioni:** verifica le condizioni di base e i filtri per ambiente e per stato; la creazione di una condizione nuova con i suoi valori e il collegamento a un ambiente; la rinomina, l'aggiunta e l'eliminazione di valori non usati con l'ordine della scala; il rifiuto di eliminare un valore usato (con annullamento della modifica) e la sua disattivazione, che lo toglie dai valori attivi ma non dalla pescata; il blocco dell'eliminazione di una condizione usata; la copia dei collegamenti da un ambiente all'altro; le condizioni proposte nel form, che per una pescata già salvata includono anche condizioni non più previste e valori disattivati.

## 5. `test/obiettivi_repository_test.dart` (2 test)

Questa suite verifica `ObiettiviRepository`: salvataggio e aggiornamento degli obiettivi (anche con una caratteristica creata al volo tramite il catalogo), filtri per anno, specie, caratteristica e tipologia (generici o legati a una caratteristica), eliminazione e rifiuto di un obiettivo collegato a una caratteristica di un'altra specie.

## 6. `test/meteo_repository_test.dart` (7 test)

Questa suite verifica `MeteoRepository`, l'archivio dei dati meteo storici, e la statistica sulla pioggia dello `StatisticheService`:

* **Intervalli e pescate da scaricare:** verifica che per una pescata si chiedano 31 giorni (30 precedenti più il giorno stesso) e le ore, in UTC, dalla mezzanotte locale del giorno prima a quella del giorno dopo; che sia da scaricare solo una pescata il cui spot ha coordinate, usando il primo punto del tratto, e che senza coordinate lo stato sia *non disponibile*.

* **Salvataggio e lettura:** verifica che i dati salvati rendano la pescata *scaricata* e vengano restituiti in ordine (31 giorni, ore in UTC, quota della cella); che una seconda pescata nello stesso punto riusi la cella già nota e che risultino mancanti solo i giorni e le ore nuovi; il collegamento di una pescata a una cella già completa senza nuovi dati; la sostituzione di un dato riscaricato e la creazione di una cella distinta per lo stesso punto della griglia a un'altra quota.

* **Stato calcolato:** verifica che modificare lo spot senza cambiare il primo punto lasci il meteo *scaricato*, che cambiare il primo punto o la data della pescata lo renda *da scaricare* (e di nuovo *scaricato* tornando alla data originale), che rinominare o eliminare lo spot non tocchi i dati e che eliminando la pescata resti l'archivio.

* **Pioggia cumulata:** verifica la somma della pioggia sui 3, 14 e 30 giorni precedenti escludendo il giorno della pescata, il risultato nullo se il meteo non è scaricato e il rifiuto di finestre oltre i 30 giorni.

## 7. `test/meteo_service_test.dart` (8 test)

Questa suite verifica `MeteoService` senza accedere alla rete: un client HTTP simulato (`MockClient` del pacchetto `http`) risponde nel formato reale di Open-Meteo (`timeformat=unixtime`, scarto orario, blocchi `daily` e `hourly`) e registra le richieste ricevute. La data di "oggi" è fissata nel test.

* **Storico delle pescate:**
  * una pescata si scarica con una sola chiamata all'archivio delle previsioni passate, con i parametri corretti (coordinate del primo punto, intervallo di 31 giorni più un giorno di margine per lato, fuso orario, variabili, nessun modello imposto), e risulta collegata alla cella con 31 giorni, ore in UTC, pressione media calcolata dalle ore e solo le ore necessarie salvate;
  * una pescata di ieri si scarica subito con una sola chiamata, e i dati di oggi, non ancora conclusi, non vengono salvati;
  * due spot nella stessa cella della griglia ma a quote diverse ottengono celle distinte;
  * una pescata nello stesso punto e nello stesso giorno non richiede chiamate, una del giorno dopo richiede solo il giorno mancante;
  * le pescate della giornata in corso non vengono scaricate;
  * rete assente, errore HTTP del servizio e risposta in formato inatteso vengono contati come errori senza interrompere l'aggiornamento né salvare dati;
  * se il servizio non restituisce i dati di alcuni giorni la pescata resta incompleta e si completa al tentativo successivo.

* **Previsioni:** verifica che `getPrevisioni` chieda i giorni indicati all'API delle previsioni, restituisca giorni e ore senza salvarli e rifiuti un numero di giorni non valido.

## 8. `test/statistiche_service_test.dart` (1 test)

Questa suite verifica `StatisticheService`, il servizio di sola lettura per le statistiche: la lettura dei riepiloghi filtrati per pescata o per specie su più pescate, completi dei dettagli per caratteristica, e il risultato vuoto per una specie mai catturata.

## 9. `test/spot_state_test.dart` (5 test)

Questa suite verifica lo stato degli spot gestito con Riverpod (`lib/ui/state/spot_state.dart`) sul database reale in memoria: nel contenitore dei provider (`ProviderContainer.test`) viene sostituito solo `databaseHelperProvider`, quindi è provata tutta la catena notifier → repository → SQLite. I nuovi tentativi automatici sono disattivati.

* **Lettura:** verifica che l'elenco degli spot si carichi in ordine alfabetico e che ambienti e categorie siano disponibili; che, se il repository non riesce a leggere, lo stato sia un errore senza nuovi tentativi automatici e che invalidare il provider (pulsante *Riprova*) rilegga il database.
* **Scrittura:** verifica che salvare uno spot aggiorni da solo sia l'elenco sia il dettaglio già osservati (coordinate e lunghezza calcolata); che rinominare ed eliminare uno spot aggiornino l'elenco; che un errore di salvataggio (ambiente inesistente) arrivi a chi salva lasciando l'elenco com'era.

## 10. `test/elenco_spot_screen_test.dart` (3 test)

Questa suite verifica la schermata `ElencoSpotScreen` senza database: il provider dell'elenco viene sostituito con uno finto che restituisce dati preparati nel test.

* verifica che la schermata mostri gli spot con ambiente, categoria e l'icona degli spot battuti;
* che durante il caricamento compaia l'indicatore e, a dati arrivati, il messaggio per l'elenco vuoto;
* che in caso di errore compaiano il messaggio e il pulsante *Riprova*, e che premerlo ricarichi i dati e li mostri.

## 11. `test/modulo_pescata_test.dart` (8 test)

Questa suite verifica le regole del modulo *Registra pescata* (`ModuloPescataNotifier` e `BozzaPescata`) senza interfaccia, sul database in memoria e con una data di "oggi" fissa (`orologioProvider`).

* **Controlli:** verifica che la bozza parta dalla data di oggi e che senza spot e fascia oraria non si possa salvare; che vengano segnalati, con messaggi per l'utente, la data futura, la temperatura dell'acqua fuori intervallo, la riga di catture senza specie o senza totale, la caratteristica che supera il totale e la specie ripetuta (anche con maiuscole diverse); che, corretti i dati, la bozza sia valida e accetti la virgola decimale.
* **Compilazione:** verifica che le condizioni proposte dipendano dall'ambiente dello spot (tutte per il torrente, solo il meteo per il lago), che toccare di nuovo un valore lo tolga e che passare a uno spot di un altro ambiente tolga i valori scelti; che un'esca nuova con il nome di una esistente (maiuscole e spazi diversi) selezioni quella e che la stessa esca nuova non si duplichi; che cambiare la specie di una riga ne tolga le caratteristiche; che una specie scritta al momento scelga quella del catalogo o una già scritta (senza duplicarla), resti in sospeso finché una riga la usa, venga segnalata da `specieScartata` solo quando togliere o cambiare la riga la scarterebbe, e non entri nel catalogo prima del salvataggio.
* **Salvataggio:** verifica che il salvataggio registri la pescata completa (spot, data, fascia, temperatura, note ripulite, valore della condizione, esca esistente ed esca nuova, riepiloghi con dettagli) e che subito dopo l'elenco delle pescate, lo stato *battuto* dello spot e il catalogo delle esche risultino aggiornati; che una specie nuova entri nel catalogo (e nel provider delle specie) solo salvando la pescata.

## 12. `test/registra_pescata_screen_test.dart` (3 test)

Questa suite verifica la schermata `RegistraPescataScreen` senza database: spot, specie ed esche sono sostituiti da dati preparati nel test.

* salvando il modulo vuoto il pulsante smette di mostrare il salvataggio in corso e compare il dialogo con i problemi (spot e fascia oraria mancanti);
* scegliere una fascia oraria la evidenzia, selezionare un'esca aggiorna il conteggio delle selezionate e aggiungere una specie con il suo totale aggiorna il totale della pescata;
* un'esca nuova compare selezionata e segnata come *nuova*; toglierla apre la richiesta di conferma (annullando resta, confermando viene scartata), mentre un'esca del catalogo si toglie senza domande.

## 13. `test/modulo_spot_test.dart` (7 test)

Questa suite verifica il modulo dello spot (`ModuloSpotNotifier`, `BozzaSpot` e `leggiCoordinata`) senza interfaccia, sul database in memoria.

* **Lettura dei punti:** verifica che `leggiCoordinata` riconosca i formati copiati da Google Maps (due numeri con punto o virgola decimale, separati da virgola, spazio o punto e virgola; gradi-primi-secondi; link completo con il punto o con la vista) e rifiuti testo qualsiasi, un numero solo, coordinate fuori intervallo e i link brevi senza coordinate.
* **Compilazione:** verifica i messaggi per nome mancante o già usato (anche con maiuscole diverse), categoria e ambiente mancanti, voto e lunghezza non validi, e che la virgola decimale sia accettata; che i punti si aggiungano, spostino e tolgano, e che con due punti la lunghezza scritta a mano sia ignorata a favore di quella calcolata; che la difficoltà si tolga toccandola di nuovo.
* **Salvataggio:** verifica che uno spot nuovo, con una categoria scritta nel modulo (che entra nel catalogo solo salvando), si salvi con i punti, la lunghezza calcolata, l'accessibilità e le note ripulite; che rinominando lo spot e passando dal torrente al lago venga proposto di collegare il solo *Livello* usato nelle pescate (il meteo è già previsto per il lago), che dopo il collegamento il lago preveda entrambe e che la pescata segua il nuovo nome; che eliminando lo spot le sue pescate restino senza spot; che una categoria scritta al momento scelga quella esistente con lo stesso nome (maiuscole e spazi diversi), che `categoriaScartata` segnali quando sceglierne un'altra scarterebbe quella nuova e che un modulo abbandonato non lasci categorie nel catalogo.

## 14. `test/modulo_spot_screen_test.dart` (2 test)

Questa suite verifica la schermata `ModuloSpotScreen` senza database (spot, categorie e ambienti preparati nel test):

* per uno spot nuovo non c'è il pulsante di eliminazione e salvando il modulo vuoto compare il dialogo con nome, categoria e ambiente mancanti;
* un testo che non è un punto mostra l'errore sotto il campo, mentre un punto valido, confermato con il pulsante *Aggiungi punto*, viene aggiunto all'elenco come primo punto, quello del meteo.

## 15. `test/pescate_state_test.dart` (4 test)

Questa suite verifica lo stato delle pescate (`pescate_state.dart`) e il modulo della pescata in modifica, sul database in memoria, con una data di "oggi" fissa e un Open-Meteo finto (`test/supporto/open_meteo_finto.dart`, condiviso con `meteo_service_test.dart`): nessuna richiesta esce dal test.

* **Elenco:** verifica che l'elenco sia dalla più recente e che i totali delle catture e le pescate con il meteo da scaricare si aggiornino da soli dopo un salvataggio e un'eliminazione; che scaricare il meteo faccia una sola richiesta, porti la pescata a *scaricato*, renda disponibile la pioggia dei giorni precedenti, svuoti l'elenco del meteo mancante e produca il messaggio per l'utente, e che un secondo aggiornamento non faccia richieste e dica che è già tutto scaricato.
* **Modifica:** verifica che il modulo aperto su una pescata salvata parta dai suoi dati (spot, fascia, temperatura, note, valore della condizione, esca, catture con caratteristiche), che le condizioni del modulo includano quelle usate, che una riga aggiunta riceva una chiave nuova e che il salvataggio aggiorni la stessa pescata (stesso id, nessuna pescata in più, dettagli e totali aggiornati); che una pescata rimasta senza spot si possa modificare senza sceglierne uno.

## 16. `test/elenco_pescate_screen_test.dart` (2 test)

Questa suite verifica la schermata `ElencoPescateScreen` senza database (pescate, totali e meteo mancante preparati nel test):

* le pescate compaiono divise per mese, con data e fascia, spot (o *Spot eliminato*), totale delle catture al singolare o al plurale e l'icona del meteo da scaricare solo dove serve;
* senza pescate compare l'invito a registrarne una.

## 17. `test/migrazioni_test.dart` (8 test)

Verifica l'aggiornamento dello schema tra versioni (vedi `scelta_architetturale_migrazioni_del_database.md`). I test lavorano su file veri in una cartella temporanea, perché un database in memoria sparisce alla chiusura e non si potrebbe riaprirlo con una versione nuova. Si appoggiano alle fotografie dello schema in `test/schemi/` (istruzioni `CREATE` e dati iniziali di ogni versione) e a `test/supporto/fotografia_schema.dart`, che le scatta, le ricarica e confronta due database (schema normalizzato e contenuto di tutte le tabelle).

* **Schema attuale:** `onCreate` crea esattamente lo schema della fotografia della versione attuale, quindi una modifica allo schema senza alzare la versione fa fallire il test; alla prima esecuzione dopo aver alzato la versione il test scatta la fotografia nuova e chiede di controllarla. Ogni versione fotografata precedente, aperta dall'app, viene aggiornata alla versione attuale e risulta identica a un database nuovo. I passaggi registrati vanno dalla versione 2 a quella attuale senza buchi.
* **Meccanismo, con passaggi finti:** ricostruire la tabella `Spot` con un vincolo in più non tocca coordinate, pianificazioni e pescate (le azioni a cascata non partono), ricrea gli indici, lascia le chiavi esterne attive e funzionanti sulla tabella nuova e applica il nuovo vincolo; un passaggio che fallisce, o che lascia righe senza la riga a cui puntano, annulla l'intero aggiornamento lasciando versione e dati come prima; un passaggio mancante blocca l'aggiornamento; un database più recente dell'app non viene aperto né modificato.
