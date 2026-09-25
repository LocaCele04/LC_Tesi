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
* **Spot**: luogo di pesca identificato, caratterizzato da un nome, una valle/zona di appartenenza e un tracciato geografico (tratto) che ne delimita l'estensione lungo il corso d'acqua.
* **Tratto**: sequenza ordinata di coordinate geografiche (polilinea) che rappresenta il percorso fisico di uno spot lungo il torrente, analoga ai tracciati salvati in Google Earth.
* **Battuta**: singola uscita di pesca, caratterizzata da data, fascia oraria, spot frequentato, condizioni meteo, catture effettuate ed eventuali note.
* **Cattura**: singolo pesce catturato durante una battuta, con attributi propri (specie, taglia, foto, esca utilizzata) e collegabile a campi personalizzati definiti dall'utente.
* **Campo personalizzato**: attributo aggiuntivo, non previsto nello schema dati di base, che l'utente può definire autonomamente per arricchire la scheda di una cattura o di una battuta (es. temperatura dell'acqua, livello idrometrico) senza richiedere una modifica strutturale del database.
* **MoSCoW**: tecnica di prioritizzazione dei requisiti (Must have, Should have, Could have, Won't have) utilizzata in questo documento per classificare ogni requisito.

### 1.4 Riferimenti
* Foglio di calcolo Google attualmente in uso dall'utente per il tracciamento di battute, catture, spese e pianificazione.

### 1.5 Panoramica del Documento
* Il documento è strutturato in tre parti principali: la sezione 2 fornisce una descrizione generale del prodotto, del contesto d'uso e dei vincoli generali; la sezione 3 elenca in dettaglio i requisiti di sistema, funzionali, di progettazione e gli attributi di qualità, ciascuno classificato secondo il metodo MoSCoW per orientare le priorità di sviluppo nelle fasi successive del progetto.

---

## 2. Descrizione Generale

### 2.1 Prospettiva del Prodotto
* Il sistema è un'applicazione mobile autonoma (standalone), priva di un back-end proprio: tutti i dati dell'utente (spot, battute, catture, foto, pianificazione) sono persistiti localmente sul dispositivo tramite un database embedded. Le uniche interazioni con servizi esterni di terze parti avvengono in sola lettura verso un servizio meteo pubblico tramite API REST e, su richiesta dell'utente, verso le API di Google Drive per l'esportazione e l'importazione manuale dei file di backup in formato JSON.

### 2.2 Funzionalità Principali del Prodotto
* Gestione degli spot di pesca, con relativo tracciato geografico (tratto), disegnabile manualmente sulla mappa dell'app.
* Registrazione delle battute di pesca, con data, fascia oraria, spot, condizioni meteo, catture effettuate ed esche utilizzate.
* Registrazione delle catture con possibilità di allegare fotografie, gestite con compressione automatica per contenere lo spazio occupato.
* Definizione di campi personalizzati aggiuntivi da parte dell'utente, applicabili alle catture o alle battute, senza necessità di modifiche strutturali ricorrenti al database.
* Visualizzazione di statistiche e riepiloghi (per spot, per periodo, per specie) a partire dallo storico registrato.
* Pianificazione delle uscite future.
* Consultazione delle condizioni meteo per uno spot, tramite chiamata diretta a un servizio meteo esterno.

### 2.3 Caratteristiche degli Utenti
* **Utente singolo (proprietario dei dati)**: pescatore amatoriale con competenze tecniche informatiche di livello medio-basso; utilizza l'app prevalentemente sul campo, spesso in condizioni di connettività assente o limitata, oppure da casa per pianificazione e consultazione statistiche. Non sono previsti ruoli multipli né gestione di permessi differenziati, trattandosi di un'applicazione a singolo utente e a dati esclusivamente personali.

### 2.4 Vincoli Generali
* L'applicazione deve funzionare in modalità completamente offline per tutte le funzionalità che non richiedono esplicitamente un dato esterno (consultazione meteo, download di nuove tile mappa); inserimento di battute, catture, foto e consultazione dei dati storici devono essere disponibili anche in assenza di connettività.
* Nessun costo ricorrente per servizi esterni: le API e i servizi di terze parti impiegati (meteo, tile mappa) devono rientrare nei piani gratuiti disponibili, essendo un progetto personale/di tesi senza budget dedicato.
* Compatibilità cross-platform Android/iOS tramite un'unica base di codice.
* Occupazione di spazio su disco contenuta nel tempo, anche con uno storico pluriennale di foto e dati (vedi requisito REQ-DES relativo alla compressione immagini).

### 2.5 Assunzioni e Dipendenze
* Si assume la disponibilità continuativa di un servizio meteo pubblico gratuito, consultabile via API REST senza necessità di chiave o con piano gratuito sufficiente all'uso previsto.
* Si assume la disponibilità di provider di tile mappa gratuiti (es. OpenStreetMap) per la visualizzazione cartografica.
* Si assume l'uso su dispositivo singolo per utente: non è previsto, nella versione base, un meccanismo di sincronizzazione multi-dispositivo o backup automatico su cloud.
* Si assume che l'utente disponga di un account Google valido con spazio di archiviazione sufficiente su Google Drive per poter utilizzare la funzionalità facoltativa di backup e ripristino.

---

## 3. Requisiti Specifici

> **Nota di compilazione:** Ciascun requisito deve essere unequivoco, verificabile e classificato tramite il metodo **MoSCoW** (Must have, Should have, Could have, Won't have).

### 3.1 Requisiti di sistema

#### 3.1.1 Interfaccia Utente
* **[INT-UI-01]** - *Must have*: L'app deve fornire una schermata mappa interattiva che mostri gli spot come tratti colorati sovrapposti a una cartografia di base, con possibilità di zoom, ricerca per nome spot e apertura di una scheda di dettaglio al tocco di un tratto.
* **[INT-UI-02]** - *Should have*: L'app deve fornire una modalità di disegno guidato di un nuovo tratto direttamente sulla mappa (selezione punto di partenza, punti intermedi, punto di arrivo, conferma e assegnazione nome).
* **[INT-UI-03]** - *Could have*: L'app potrebbe offrire una vista satellitare alternativa alla cartografia standard, selezionabile dall'utente.

#### 3.1.2 Interfaccia Hardware
* **[INT-HW-01]** - *Must have*: L'app deve poter accedere alla fotocamera e/o alla galleria del dispositivo per l'acquisizione e l'allegazione di fotografie alle catture registrate.
* **[INT-HW-02]** - *Should have*: L'app dovrebbe poter accedere al modulo GPS del dispositivo per la geolocalizzazione automatica durante il disegno di un nuovo tratto o la registrazione di una cattura.

#### 3.1.3 Interfaccia Software
* **[INT-SW-01]** - *Must have*: L'app deve integrare una libreria di database locale embedded (es. SQLite tramite un ORM come drift) per la persistenza strutturata di spot, battute, catture, spese e pianificazione, senza dipendenza da un database server remoto.
* **[INT-SW-02]** - *Must have*: L'app deve integrare una libreria di mappa client-side (es. flutter_map) in grado di visualizzare tile di provider cartografici gratuiti e di renderizzare tracciati geografici (polilinee) e marker.
* **[INT-SW-03]** - *Should have*: L'app dovrebbe integrare una libreria di compressione/ridimensionamento immagini lato client, applicata automaticamente al salvataggio di ogni fotografia.

#### 3.1.4 Interfaccia di Comunicazione
* **[INT-COM-01]** - *Must have*: L'app deve poter effettuare richieste HTTPS in sola lettura verso un'API meteo pubblica, inviando le coordinate dello spot selezionato e ricevendo le condizioni meteo correnti o previste, senza che tale comunicazione richieda un server applicativo proprio.
* **[INT-COM-02]** - *Won't have*: L'app non prevede, nella versione base, comunicazioni verso un server applicativo proprio né sincronizzazione dati verso servizi cloud di terze parti.
* **[INT-COM-03]** - *Should have*: L'app deve poter comunicare tramite protocollo HTTPS sicuro con le API REST di Google Drive (previo flusso di autenticazione OAuth 2.0) per il caricamento del file JSON di backup e il download in fase di ripristino.

### 3.1.5 Requisiti di Prestazione

* **[REQ-PERF-01]** - *Should have*: Il caricamento della schermata mappa, con l'intero insieme di tratti dell'utente visualizzati, deve completarsi in meno di 2 secondi su dispositivo di fascia media, per uno storico fino a qualche centinaio di spot.
* **[REQ-PERF-02]** - *Should have*: Le query di consultazione dello storico (es. filtro catture per spot o per periodo, calcolo statistiche di riepilogo) devono restituire un risultato in meno di 1 secondo, anche con alcune migliaia di record di catture accumulati nel tempo.

---


### 3.2 Requisiti Funzionali

#### 3.2.1 Gestione Spot

* **[REQ-FUN-01]** - *Must have*
  * **Descrizione**: Il sistema deve permettere la creazione di un nuovo spot disegnando manualmente il relativo tratto sulla mappa.
  * **Input**: Sequenza di punti selezionati dall'utente sulla mappa (punto di partenza, punti intermedi, punto di arrivo); nome assegnato allo spot al termine del disegno.
  * **Elaborazione**: Validazione che il tratto contenga almeno due punti e che sia stato assegnato un nome non vuoto prima del salvataggio.
  * **Output / Risposta**: Nuovo spot salvato e visualizzato sulla mappa con un colore distintivo; messaggio di conferma del salvataggio.

* **[REQ-FUN-02]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe permettere la modifica dei dati descrittivi di uno spot esistente (valle/zona, categoria, difficoltà, note, voto).
  * **Input**: Selezione di uno spot esistente e nuovi valori per i campi modificabili.
  * **Output**: Scheda dello spot aggiornata con i nuovi valori.

#### 3.2.2 Gestione Battute e Catture

* **[REQ-FUN-03]** - *Must have*
  * **Descrizione**: Il sistema deve permettere la registrazione di una nuova battuta di pesca, comprensiva di data, fascia oraria, spot frequentato e note libere.
  * **Input**: Data, fascia oraria, spot selezionato dall'elenco degli spot esistenti, note testuali.
  * **Output**: Nuova battuta salvata e consultabile nello storico.

* **[REQ-FUN-04]** - *Must have*
  * **Descrizione**: Il sistema deve permettere la registrazione di una o più catture all'interno di una battuta, con possibilità di allegare una fotografia per ciascuna cattura.
  * **Input**: Dati della cattura (es. specie, taglia); fotografia acquisita da fotocamera o selezionata da galleria.
  * **Elaborazione**: Ridimensionamento e compressione della fotografia prima del salvataggio su file system; generazione di un'anteprima (thumbnail) per la visualizzazione in elenco; salvataggio del percorso del file immagine come riferimento nel record della cattura, senza memorizzare il file binario nel database.
  * **Output / Risposta**: Cattura salvata e associata alla battuta corrente, con foto e anteprima consultabili nella scheda.

* **[REQ-FUN-05]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe permettere all'utente di definire nuovi campi personalizzati da associare alle catture (es. temperatura dell'acqua, esca utilizzata non prevista tra i valori predefiniti), specificandone nome e tipo di dato (numerico, testuale, booleano, scelta da lista).
  * **Input**: Nome del campo, tipo di dato, eventuale unità di misura.
  * **Elaborazione**: Il nuovo campo viene reso disponibile nel form di inserimento cattura senza richiedere una modifica dello schema del database; i campi fissi previsti dal sistema (data, spot, chiavi identificative) non sono in alcun caso eliminabili o rinominabili dall'utente.
  * **Output / Risposta**: Nuovo campo personalizzato disponibile da subito nella schermata di inserimento di una nuova cattura.

#### 3.2.3 Statistiche e Riepiloghi

* **[REQ-FUN-06]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe fornire riepiloghi aggregati (numero di catture per spot, andamento mensile/annuale, media catture per battuta) a partire dallo storico registrato.
  * **Input**: Periodo o spot su cui filtrare il riepilogo.
  * **Output**: Visualizzazione sintetica (tabellare o grafica) delle statistiche richieste.

#### 3.2.4 Pianificazione

* **[REQ-FUN-07]** - *Could have*
  * **Descrizione**: Il sistema potrebbe permettere la pianificazione di battute future (spot, data, fascia oraria, note), in analogia al piano di battaglia oggi tenuto sul foglio di calcolo.
  * **Input**: Spot, data, fascia oraria e note per l'uscita pianificata.
  * **Output**: Elenco delle uscite pianificate, convertibili in battuta registrata una volta svolte.


#### 3.2.5 Consultazione Meteo

* **[REQ-FUN-8]** - *Should have*
  * **Descrizione**: Il sistema dovrebbe permettere la consultazione delle condizioni meteo correnti o previste per le coordinate di uno spot selezionato.
  * **Input**: Spot selezionato dall'utente.
  * **Elaborazione**: Invocazione dell'API meteo esterna con le coordinate dello spot.
  * **Output / Risposta**: Visualizzazione delle condizioni meteo restituite (temperatura, precipitazioni, ecc.) all'interno della scheda dello spot o della battuta.


#### 3.2.6 Backup e Ripristino Dati

* **[REQ-FUN-09]** - *Should have*
  * **Descrizione**: Il sistema deve consentire l'esportazione manuale di tutti i dati registrati nell'applicazione (spot, battute, catture, campi personalizzati, pianificazione) e il loro salvataggio in formato JSON sullo spazio Google Drive dell'utente.
  * **Input**: Comando di avvio backup da parte dell'utente e autenticazione tramite il proprio account Google.
  * **Elaborazione**: Verifica della connettività di rete e autenticazione tramite OAuth; lettura dei record dal database locale embedded e serializzazione dei dati in formato JSON strutturato (inclusi i riferimenti e metadati delle foto); caricamento del file JSON generato all'interno di una cartella dedicata su Google Drive.
  * **Output / Risposta**: File JSON di backup salvato su Google Drive e messaggio di conferma a schermo contenente la data e l'ora dell'avvenuto salvataggio.

* **[REQ-FUN-10]** - *Should have*
  * **Descrizione**: Il sistema deve consentire l'importazione e il ripristino dei dati dell'applicazione a partire da un file di backup in formato JSON precedentemente salvato su Google Drive.
  * **Input**: Comando di ripristino dati, autenticazione dell'account Google e selezione del file di backup JSON desiderato da Google Drive.
  * **Elaborazione**: Download del file JSON scelto; verifica della validità dello schema dei dati e della versione del backup; richiesta di conferma all'utente in caso di sovrascrittura del database locale esistente; deserializzazione del JSON e ripopolamento delle tabelle del database locale embedded.
  * **Output / Risposta**: Database locale aggiornato con le informazioni importate e messaggio a schermo di conferma del completamento del ripristino.

---



### 3.4 Vincoli di Progettazione ed Implementazione

* **[REQ-DES-01]**: L'app deve essere sviluppata in Flutter (Dart), per garantire una base di codice unica cross-platform Android/iOS.
* **[REQ-DES-02]**: La persistenza dei dati deve avvenire esclusivamente tramite database locale embedded (SQLite, tramite ORM drift o equivalente); non è prevista, nella versione base, alcuna componente server-side (es. backend PHP) né database relazionale remoto.
* **[REQ-DES-03]**: I file immagine (foto delle catture) devono essere salvati sul file system del dispositivo, referenziati nel database tramite il relativo percorso; il database non deve contenere file binari.
* **[REQ-DES-04]**: I campi personalizzati definiti dall'utente devono essere gestiti tramite uno schema a metadati (pattern Entity-Attribute-Value), per evitare migrazioni strutturali del database a ogni nuovo campo aggiunto dall'utente.
* **[REQ-DES-05]**: L'architettura del codice deve essere organizzata a livelli (presentazione, logica applicativa, accesso ai dati), per favorire manutenibilità e testabilità delle singole componenti.

---

### 3.5 Attributi di Qualità del Sistema (Requisiti Non Funzionali)

* **Sicurezza (Security)**: I dati dell'utente risiedono esclusivamente in locale sul dispositivo; non è prevista trasmissione di dati personali (catture, foto) verso server esterni. L'unica comunicazione di rete prevista (interrogazione API meteo) trasmette esclusivamente coordinate geografiche, senza dati identificativi dell'utente.
* **Affidabilità e Disponibilità**: Non essendo prevista alcuna componente server-side, non si applicano requisiti di uptime; l'affidabilità è demandata all'integrità del database locale e a un'eventuale funzione di esportazione manuale dei dati come backup, a discrezione dell'utente.
* **Manutenibilità e Portabilità**: Il codice deve essere organizzato in moduli disaccoppiati (gestione spot, gestione battute/catture, statistiche, meteo), per permettere l'estensione futura del sistema (es. eventuale sincronizzazione multi-dispositivo) senza richiedere una riscrittura delle componenti esistenti. L'uso di Flutter garantisce la portabilità del client su Android e iOS a partire da un'unica base di codice.
