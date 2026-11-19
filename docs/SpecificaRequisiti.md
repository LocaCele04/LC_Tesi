# Specifica dei Requisiti Software (SRS)

**Progetto:** Diario di pesca
**Studente:** Celeste Locatelli  
**Matricola:** 1092641  
**Email:** c.locatelli60@studenti.unibg.it 

---

## 1. Introduzione

### 1.1 Obiettivo
* Stesura di un documento contenente tutti i requisiti funzionali, non funzionali e di sistema. Sono previste anche modifiche durante il ciclo di vita del progetto man mano che la comprensione del sistema aumenta.
Documento rivolto a tutti gli utenti interessati alla futura implementazione dell'app e che desiderano proporre idee per dare forma migliore al progetto.
Documento utile anche ai relatori di tesi per comprendere quale potrebbe essere il risultato finale.

### 1.2 Scopo del Sistema
* Realizzazione di un'applicazione per dispositivi mobili, strumento indirizzato a pescatori dilettanti per tenere traccia della propria carriera alieutica attraverso il salvataggio di informazioni rilevanti, con particolare attenzione ai luoghi di pesca (spot e tratti percorsi).

### 1.3 Definizioni, Acronimi e Abbreviazioni
* **SRS**: Software Requirements Specification (Specifica dei Requisiti Software).
* **Categoria**: raggruppamento di spot scelto dall'utente, simile a una cartella (es. la valle di appartenenza come *Val Taleggio*, oppure una zona come *Fondovalle*). Ogni spot appartiene a una sola categoria.
* **Ambiente**: tipologia del corso o specchio d'acqua di uno spot (es. torrente, fiume, lago, mare).
* **Spot**: luogo di pesca identificato da un nome, appartenente a una categoria, caratterizzato da un ambiente e da un tracciato geografico (tratto) che ne delimita l'estensione lungo il corso d'acqua.
* **Tratto**: sequenza ordinata di coordinate geografiche (polilinea) che rappresenta il percorso fisico di uno spot lungo il torrente, analoga ai tracciati salvati in Google Earth.
* **Pescata**: attività di pesca svolta in un singolo spot in una certa data e fascia oraria, con condizioni meteo e dell'acqua, riepilogo delle catture, esche utilizzate, foto ed eventuali note. Un'uscita in cui si visitano più spot si registra come più pescate, una per spot.
* **Riepilogo specie**: numero di esemplari di una specie catturati in una pescata, eventualmente suddiviso per caratteristica (es. 12 trote, di cui 3 "over 30"). L'app non registra i singoli pesci catturati ma solo questi totali.
* **Caratteristica**: aspetto che il pescatore vuole evidenziare per una specie, definito da lui nelle impostazioni (es. un colore, una misura come "over 35", un peso). Ogni caratteristica appartiene a una sola specie.
* **Cattura memorabile**: singola cattura che il pescatore vuole ricordare, associata a una pescata, con specie, una o più foto, esca usata e caratteristiche soddisfatte. È già conteggiata nel riepilogo specie della pescata.
* **Esca**: esca o artificiale presente nel catalogo personale del pescatore, selezionabile nelle pescate e nelle catture memorabili.
* **Obiettivo**: quantità di catture da raggiungere nell'anno solare per una specie, eventualmente limitata a una sua caratteristica.
* **Pianificazione**: pescata futura prevista in uno spot, in una data e fascia oraria.
* **MoSCoW**: tecnica di prioritizzazione dei requisiti (Must have, Should have, Could have, Won't have) utilizzata in questo documento per classificare ogni requisito.

### 1.4 Riferimenti
* Foglio di calcolo Google attualmente in uso dall'utente per il tracciamento di pescate, catture e pianificazione. (non disponibile pubblicamente, dati personali)

### 1.5 Panoramica del Documento
* Il documento è strutturato in tre parti principali: la sezione 2 fornisce una descrizione generale del prodotto, del contesto d'uso e dei vincoli generali; la sezione 3 elenca in dettaglio i requisiti di sistema, funzionali, di progettazione e gli attributi di qualità, ciascuno classificato secondo il metodo MoSCoW per orientare le priorità di sviluppo nelle fasi successive del progetto.

---

## 2. Descrizione Generale

### 2.1 Prospettiva del Prodotto
* Il sistema è un'applicazione mobile autonoma (standalone), priva di un back-end proprio: tutti i dati dell'utente (spot, pescate, catture memorabili, foto, pianificazione) sono persistiti localmente sul dispositivo tramite un database embedded. Le uniche interazioni con servizi esterni di terze parti sono: la lettura delle previsioni da un servizio meteo pubblico tramite API REST e, solo su richiesta esplicita dell'utente, il caricamento e lo scaricamento di un archivio di backup (file ZIP contenente i dati in JSON e le foto) sul Google Drive dell'utente. In futuro si potrebbe aggiungere un assistente AI per effettuare ricerche sui dati.

### 2.2 Funzionalità Principali del Prodotto
* Gestione degli spot di pesca, organizzati in categorie, con relativo tracciato geografico (tratto) disegnabile manualmente sulla mappa dell'app.
* Registrazione delle pescate, con data, fascia oraria, spot, condizioni meteo e dell'acqua, riepilogo delle catture per specie ed esche utilizzate.
* Allegato di fotografie alle pescate, alle catture memorabili e alle esche, con compressione automatica per contenere lo spazio occupato.
* Registrazione delle catture memorabili, consultabili in un'apposita sezione.
* Definizione di caratteristiche personalizzate per ciascuna specie di pesce.
* Visualizzazione di statistiche e riepiloghi (per spot, per periodo, per specie) a partire dallo storico registrato.
* Pianificazione delle uscite future e degli obiettivi annuali.
* Consultazione delle condizioni meteo per uno spot, tramite chiamata diretta a un servizio meteo esterno.
* Backup e ripristino manuale dei dati su Google Drive.

### 2.3 Caratteristiche degli Utenti
* **Utente singolo (proprietario dei dati)**: pescatore amatoriale con competenze tecniche informatiche di livello medio-basso; l'utilizzo dell'app avviene esclusivamente al termine della pescata. Non sono previsti ruoli multipli né gestione di permessi differenziati, trattandosi di un'applicazione a singolo utente e a dati esclusivamente personali.

### 2.4 Vincoli Generali
* L'applicazione deve funzionare in modalità completamente offline per tutte le funzionalità che non richiedono esplicitamente un dato esterno (consultazione meteo, backup su Google Drive, eventuali ricerche AI); inserimento di pescate, catture memorabili, foto e consultazione dei dati storici devono essere disponibili anche in assenza di connettività.
* Nessun costo ricorrente per servizi esterni: le API e i servizi di terze parti impiegati devono rientrare nei piani gratuiti disponibili, essendo un progetto personale/di tesi senza budget dedicato.
* Compatibilità cross-platform Android/iOS tramite un'unica base di codice.
* Occupazione di spazio su disco contenuta nel tempo, anche con uno storico pluriennale di foto e dati (vedi [INT-SW-03] relativo alla compressione immagini).

### 2.5 Assunzioni e Dipendenze
* Si assume la disponibilità continuativa di un servizio meteo pubblico gratuito, consultabile via API REST senza necessità di chiave o con piano gratuito sufficiente all'uso previsto.
* Si assume la disponibilità di provider di tile mappa gratuiti (es. OpenStreetMap) per la visualizzazione cartografica.
* Si assume l'uso su dispositivo singolo per utente: non è previsto, nella versione base, un meccanismo di sincronizzazione multi-dispositivo o backup automatico su cloud.
* Si assume che l'utente disponga di un account Google valido con spazio di archiviazione sufficiente su Google Drive per poter utilizzare la funzionalità facoltativa di backup e ripristino.

---

## 3. Requisiti Specifici

> **Nota di compilazione:** Ciascun requisito deve essere univoco, verificabile e classificato tramite il metodo **MoSCoW** (Must have, Should have, Could have, Won't have). Per coerenza con la classificazione, i requisiti *Must have* usano "deve", i *Should have* "dovrebbe", i *Could have* "potrebbe".

### 3.1 Requisiti di sistema (in aggiornamento)

#### 3.1.1 Interfaccia Utente
* **[INT-UI-01]** - *Must have*: L'app deve fornire una schermata mappa interattiva che mostri gli spot come tratti colorati sovrapposti a una cartografia di base, con possibilità di zoom, ricerca per nome spot e apertura di una scheda di dettaglio al tocco di un tratto.
* **[INT-UI-02]** - *Should have*: L'app dovrebbe fornire una modalità di disegno guidato di un nuovo tratto direttamente sulla mappa (selezione punto di partenza, punti intermedi, punto di arrivo, conferma e assegnazione nome).
* **[INT-UI-03]** - *Could have*: L'app potrebbe offrire una vista satellitare alternativa alla cartografia standard, selezionabile dall'utente.
* **[INT-UI-04]** - *Could have*: L'app potrebbe offrire una vista a carosello per consultare le catture memorabili.

#### 3.1.2 Interfaccia Hardware
* **[INT-HW-01]** - *Must have*: L'app deve poter accedere alla fotocamera e/o alla galleria del dispositivo per l'acquisizione e l'allegazione di fotografie a pescate, catture memorabili ed esche.

#### 3.1.3 Interfaccia Software
* **[INT-SW-01]** - *Must have*: L'app deve integrare una libreria di database locale embedded (SQLite) per la persistenza strutturata di spot, pescate, catture memorabili, esche, specie, obiettivi e pianificazione, senza dipendenza da un database server remoto.
* **[INT-SW-02]** - *Must have*: L'app deve integrare una libreria di mappa client-side (es. flutter_map) in grado di visualizzare tile di provider cartografici gratuiti e di renderizzare tracciati geografici (polilinee) e marker.
* **[INT-SW-03]** - *Should have*: L'app dovrebbe integrare una libreria di compressione/ridimensionamento immagini lato client, applicata automaticamente al salvataggio di ogni fotografia.

#### 3.1.4 Interfaccia di Comunicazione
* **[INT-COM-01]** - *Must have*: L'app deve poter effettuare richieste HTTPS in sola lettura verso un'API meteo pubblica, inviando le coordinate dello spot selezionato e ricevendo le condizioni meteo correnti o previste, senza che tale comunicazione richieda un server applicativo proprio.
* **[INT-COM-02]** - *Won't have*: L'app non prevede, nella versione base, comunicazioni verso un server applicativo proprio né sincronizzazione automatica o continua dei dati verso servizi cloud. L'unico trasferimento di dati personali verso il cloud è il backup manuale descritto in [INT-COM-03].
* **[INT-COM-03]** - *Should have*: L'app dovrebbe poter comunicare tramite HTTPS con le API REST di Google Drive (previo flusso di autenticazione OAuth 2.0) per il caricamento dell'archivio ZIP di backup e il suo download in fase di ripristino.

#### 3.1.5 Requisiti di Prestazione
* **[REQ-PERF-01]** - *Should have*: Il caricamento della schermata mappa, con l'intero insieme di tratti dell'utente visualizzati, dovrebbe completarsi in meno di 2 secondi su dispositivo di fascia media, per uno storico fino a qualche centinaio di spot.
* **[REQ-PERF-02]** - *Should have*: Le query di consultazione dello storico (es. filtro pescate per spot o per periodo, calcolo statistiche di riepilogo) dovrebbero restituire un risultato in meno di 1 secondo, anche con alcune migliaia di pescate accumulate nel tempo.

---

### 3.2 Requisiti Funzionali

#### 3.2.1 Gestione Spot

* **[REQ-FUN-01]** - *Must have*
  * **Descrizione**: Il sistema deve permettere la creazione di un nuovo spot disegnando manualmente il relativo tratto sulla mappa.
  * **Input**: Sequenza di punti selezionati dall'utente sulla mappa (punto di partenza, punti intermedi, punto di arrivo); nome, categoria e ambiente assegnati allo spot al termine del disegno.
  * **Elaborazione**: Validazione che il tratto contenga almeno due punti e che nome, categoria e ambiente siano stati indicati prima del salvataggio; calcolo automatico della lunghezza del tratto in metri.
  * **Output / Risposta**: Nuovo spot salvato e visualizzato sulla mappa; messaggio di conferma del salvataggio.

* **[REQ-FUN-02]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe permettere la modifica dei dati descrittivi di uno spot esistente (nome, categoria, ambiente, difficoltà, esposizione al sole, accessibilità, ostacoli, link parcheggio, note, voto) e del suo tratto.
  * **Input**: Selezione di uno spot esistente e nuovi valori per i campi modificabili.
  * **Output**: Scheda dello spot aggiornata con i nuovi valori; la rinomina dello spot si propaga a pescate, pianificazioni e coordinate collegate.

* **[REQ-FUN-03]** - *Could have*
  * **Descrizione**: Il sistema potrebbe permettere di visualizzare la mappa con diverse viste (es. colore dei tratti in base all'ambiente oppure al voto assegnato).
  * **Input**: Selezione del tipo di vista.
  * **Output**: Modifica dei colori dei tratti sulla mappa.

* **[REQ-FUN-04]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe permettere all'utente di creare, rinominare ed eliminare categorie, che funzionano come cartelle per gli spot (es. le valli minori come *Val Stabina*, oppure zone come *Basso Brembo*).
  * **Elaborazione**: Una categoria che contiene spot non può essere eliminata: l'utente deve prima spostarne gli spot in un'altra categoria.
  * **Output**: Possibilità di assegnare uno o più spot a una categoria e di spostarli da una categoria all'altra.

* **[REQ-FUN-05]** - *Should have*
  * **Descrizione**: L'utente dovrebbe poter aggiungere un nuovo ambiente a quelli già presenti di base (fiume, lago, mare, torrente) e poi usarlo quando definisce nuovi spot.
  * **Input**: Inserimento del nome del nuovo ambiente.
  * **Elaborazione**: Il nome non può essere vuoto né coincidere, anche solo a meno di maiuscole e minuscole, con un ambiente già presente. Un ambiente può essere rinominato (il nuovo nome si applica a tutti i suoi spot) ed eliminato solo se nessuno spot lo usa.
  * **Output**: Elenco più vasto tra cui scegliere per indicare il tipo di spot.

#### 3.2.2 Gestione Pescate e Catture

* **[REQ-FUN-06]** - *Must have*
  * **Descrizione**: Il sistema deve permettere la registrazione di una nuova pescata, comprensiva di data, fascia oraria, spot frequentato, condizioni meteo e note libere; facoltativamente trasparenza, fondo e livello dell'acqua, temperatura dell'acqua e dell'aria.
  * **Input**: Data, fascia oraria, meteo, spot selezionato dall'elenco degli spot esistenti (con possibilità di crearne uno al momento), dati facoltativi e note testuali.
  * **Elaborazione**: Lo spot è obbligatorio: una pescata nuova non può essere salvata senza spot, e a una pescata esistente non si può togliere lo spot. Fa eccezione solo una pescata il cui spot è stato eliminato (vedi [REQ-DES-07]), che resta modificabile anche senza spot.
  * **Output**: Nuova pescata salvata e consultabile nello storico; lo spot risulta visitato (battuto).

* **[REQ-FUN-07]** - *Must have*
  * **Descrizione**: Il sistema deve permettere di registrare, all'interno di una pescata, il riepilogo delle catture per specie e di allegare foto alla pescata.
  * **Input**: Una o più coppie specie–quantità; per ciascuna specie, facoltativamente, la quantità di esemplari che soddisfano ogni caratteristica personale definita per quella specie; foto acquisite da fotocamera o selezionate da galleria.
  * **Elaborazione**: Verifica che ogni specie compaia al massimo una volta nella pescata e che la quantità di ogni caratteristica non superi il totale della specie. Ridimensionamento e compressione delle foto prima del salvataggio su file system; generazione di un'anteprima (thumbnail) per la visualizzazione in elenco; salvataggio del percorso del file immagine come riferimento, senza memorizzare il file binario nel database.
  * **Output / Risposta**: Riepiloghi e foto salvati e associati alla pescata, con foto e anteprime consultabili nella scheda.

* **[REQ-FUN-08]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe permettere all'utente di inserire, dopo la registrazione di una pescata o in un secondo momento, una o più catture memorabili legate a quella pescata.
  * **Input**: Pescata di riferimento (da cui derivano data e spot), una o più foto, specie, esca usata e caratteristiche soddisfatte tra quelle definite per la specie.
  * **Elaborazione**: Ridimensionamento e compressione delle fotografie come in [REQ-FUN-07]. Le caratteristiche selezionate devono appartenere alla specie della cattura. La cattura memorabile non modifica i conteggi della pescata (vedi [REQ-DES-06]).
  * **Output / Risposta**: Cattura memorabile salvata e associata alla pescata, visibile in un'apposita sezione delle statistiche insieme alle altre catture da ricordare (vedi [INT-UI-04]).

* **[REQ-FUN-09]** - *Could have*
  * **Descrizione**: Il sistema potrebbe permettere di gestire un catalogo delle esche utilizzate, utile per ricerche filtrate delle pescate o per statistiche (es. in quante pescate questa stagione ho usato la gomma). Non si registra la quantità di catture per ciascuna esca: sarebbe troppo dettagliato, poco rilevante e rallenterebbe molto la registrazione delle pescate.
  * **Input**: Nome esca, descrizione (es. amo adottato, lunghezza, peso), foto (opzionale).
  * **Elaborazione**: Le informazioni di un'esca sono sempre modificabili; in una pescata si possono selezionare più esche, con possibilità di crearne una al momento.
  * **Output / Risposta**: Catalogo esche.

#### 3.2.3 Pianificazione

* **[REQ-FUN-10]** - *Could have*
  * **Descrizione**: Il sistema potrebbe permettere la pianificazione di pescate future (spot, data, fascia oraria, note), in analogia al piano di battaglia oggi tenuto sul foglio di calcolo.
  * **Input**: Spot, data, fascia oraria e note per l'uscita pianificata.
  * **Output**: Elenco delle uscite pianificate, convertibili in pescata registrata una volta svolte.

* **[REQ-FUN-11]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe permettere la definizione di obiettivi per la stagione; tutti gli obiettivi terminano di validità a fine anno solare.
  * **Input**: L'utente seleziona la specie per cui vuole aggiungere l'obiettivo e la quantità; può associare l'obiettivo a una sola caratteristica di quella specie (vedi [REQ-DES-04]).
  * **Elaborazione**: Il progresso è calcolato sommando le quantità dei riepiloghi (o dei dettagli per caratteristica) delle pescate dell'anno dell'obiettivo.
  * **Output**: Monitoraggio e stato di avanzamento degli obiettivi, avvisi al raggiungimento, riepilogo di fine anno.

* **[REQ-FUN-12]** - *Won't have*
  * **Descrizione**: Il sistema non prevede obiettivi diversi da quelli sulle quantità di specie e caratteristiche, ad esempio obiettivi sul numero di pescate (es. "30 pescate all'alba"), sulle pescate con almeno N catture o sulla scoperta di nuovi spot.

#### 3.2.4 Consultazione Meteo

* **[REQ-FUN-13]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe permettere la consultazione delle condizioni meteo correnti o previste per le coordinate di uno spot selezionato, anche durante la pianificazione di una pescata.
  * **Input**: Spot selezionato dall'utente.
  * **Elaborazione**: Invocazione dell'API meteo esterna con le coordinate dello spot. In assenza di connessione l'app lo segnala senza bloccare le altre funzionalità.
  * **Output / Risposta**: Visualizzazione delle condizioni meteo restituite (temperatura, precipitazioni, ecc.) all'interno della scheda dello spot o della pianificazione.

#### 3.2.5 Backup e Ripristino Dati

* **[REQ-FUN-14]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe consentire l'esportazione manuale di tutti i dati registrati nell'applicazione (spot, pescate, catture memorabili, esche, specie, caratteristiche, obiettivi, pianificazione) e di tutte le foto in un unico archivio ZIP, salvato sullo spazio Google Drive dell'utente.
  * **Input**: Comando di avvio backup da parte dell'utente e autenticazione tramite il proprio account Google.
  * **Elaborazione**: Verifica della connettività di rete e autenticazione tramite OAuth; lettura dei record dal database locale e serializzazione in un file JSON strutturato, contenente la versione dello schema e i percorsi relativi delle foto; creazione di un archivio ZIP con il file JSON e la cartella delle foto e delle anteprime; caricamento dell'archivio in una cartella dedicata su Google Drive.
  * **Output / Risposta**: Archivio ZIP di backup salvato su Google Drive e messaggio di conferma a schermo con data e ora dell'avvenuto salvataggio.

* **[REQ-FUN-15]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe consentire il ripristino dei dati dell'applicazione a partire da un archivio ZIP di backup precedentemente salvato su Google Drive, anche su un dispositivo diverso da quello di origine.
  * **Input**: Comando di ripristino dati, autenticazione dell'account Google e selezione dell'archivio di backup desiderato.
  * **Elaborazione**: Download ed estrazione dell'archivio; verifica della validità dello schema dei dati e della versione del backup; richiesta di conferma all'utente in caso di sovrascrittura del database locale esistente; ripopolamento delle tabelle del database locale e copia delle foto nella cartella dell'app, così che i percorsi relativi registrati tornino validi.
  * **Output / Risposta**: Database locale e foto ripristinati e messaggio a schermo di conferma del completamento del ripristino.

---

### 3.3 Vincoli di Progettazione ed Implementazione

* **[REQ-DES-01]**: L'app deve essere sviluppata in Flutter (Dart), per garantire una base di codice unica cross-platform Android/iOS.
* **[REQ-DES-02]**: La persistenza dei dati deve avvenire esclusivamente tramite database locale embedded SQLite, utilizzato tramite il plugin `sqflite` con query SQL scritte a mano e un livello di mapping dedicato (`db_mappers.dart`); non è prevista, nella versione base, alcuna componente server-side né database relazionale remoto.
* **[REQ-DES-03]**: I file immagine devono essere salvati sul file system del dispositivo, nella cartella documenti dell'app, e referenziati nel database tramite percorso relativo a tale cartella; il database non deve contenere file binari. Il percorso relativo rende i riferimenti validi anche dopo un ripristino su un altro dispositivo o dopo un aggiornamento dell'app che cambi il percorso assoluto della cartella.
* **[REQ-DES-04]**: Per obiettivi "complessi", ad esempio trota "marmorata" (car1) + "over 70" (car2), non si allegano più caratteristiche allo stesso obiettivo: sarà il pescatore a creare una nuova caratteristica con quel nome associata alla specie trota (insieme: "marmorata over 70").
* **[REQ-DES-05]**: L'architettura del codice deve essere organizzata a livelli (presentazione, logica applicativa, accesso ai dati), per favorire manutenibilità e testabilità delle singole componenti.
* **[REQ-DES-06]**: Le caratteristiche aggiunte alla cattura memorabile non vengono conteggiate negli obiettivi: nella registrazione di una pescata il pescatore considera la cattura memorabile come una cattura qualsiasi e inserisce già da subito i valori totali per specie e caratteristiche. Questo semplifica l'inserimento dei dati; la cattura memorabile viene aggiunta a parte ma rimane comunque associata alla pescata.
* **[REQ-DES-07]**: Politiche di eliminazione, garantite dal database tramite vincoli di integrità referenziale:
  * una categoria che contiene spot non può essere eliminata;
  * un ambiente usato da almeno uno spot non può essere eliminato;
  * l'eliminazione di uno spot elimina il suo tratto e le sue pianificazioni, mentre le pescate svolte nello spot restano nello storico senza spot associato (è l'unico modo in cui una pescata può trovarsi senza spot, vedi [REQ-FUN-06]);
  * l'eliminazione di una pescata elimina riepiloghi, catture memorabili e foto collegate, compresi i file immagine sul dispositivo;
  * una specie usata in almeno una pescata o cattura memorabile non può essere eliminata.

---

### 3.4 Attributi di Qualità del Sistema (Requisiti Non Funzionali)

* **Sicurezza (Security)**: I dati dell'utente risiedono in locale sul dispositivo e non sono trasmessi a server dello sviluppatore o di terze parti. L'interrogazione dell'API meteo trasmette esclusivamente coordinate geografiche, senza dati identificativi dell'utente. Gli unici dati personali che lasciano il dispositivo sono quelli contenuti nell'archivio di backup, caricato solo su comando esplicito dell'utente sul suo Google Drive personale, tramite connessione HTTPS e autenticazione OAuth 2.0.
* **Affidabilità e Disponibilità**: Non essendo prevista alcuna componente server-side, non si applicano requisiti di uptime; l'affidabilità è demandata all'integrità del database locale, garantita da vincoli e transazioni, e al backup manuale su Google Drive (dati e foto), a discrezione dell'utente.
* **Manutenibilità e Portabilità**: Il codice deve essere organizzato in moduli disaccoppiati (gestione territorio e spot, gestione pescate, statistiche, meteo, backup), per permettere l'estensione futura del sistema (es. eventuale sincronizzazione multi-dispositivo) senza richiedere una riscrittura delle componenti esistenti. L'uso di Flutter garantisce la portabilità del client su Android e iOS a partire da un'unica base di codice.
