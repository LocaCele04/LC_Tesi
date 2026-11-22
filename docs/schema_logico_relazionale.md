# Schema Logico Relazionale

Lo schema descritto in questo documento corrisponde a quello effettivamente creato da `DatabaseHelper.onCreate` (`lib/data/database_helper.dart`): 26 tabelle e 19 indici su SQLite, alla **versione 2** dello schema (`DatabaseHelper.versioneSchema`). Come si passa da una versione alla successiva è descritto in `scelta_architetturale_migrazioni_del_database.md`.

---

## 1. Convenzioni di Notazione
* **`PK`**: Chiave Primaria (*Primary Key*)
* **`FK`**: Chiave Esterna (*Foreign Key*)
* **`UQ`**: Vincolo di unicità (*Unique*)
* **`NULL`**: Attributo facoltativo / opzionale
* **`NOT NULL`**: Attributo obbligatorio
* Tipi: SQLite usa affinità di tipo; si riportano i tipi effettivi `TEXT`, `INTEGER`, `REAL`. Le date sono `TEXT` in formato ISO `AAAA-MM-GG`, i booleani `INTEGER` (0/1).
* Azioni referenziali: `ON DELETE` / `ON UPDATE` indicate accanto a ogni FK (default SQLite: `NO ACTION`).

---

## 2. Schema Logico Relazionale (Formato Testuale)

### **Categoria**
* **`nome`**: TEXT **(PK)** — non vuoto
* `note`: TEXT *(NULL)*

### **Ambiente**
* **`nome`**: TEXT **(PK)** `COLLATE NOCASE` — non vuoto; unico senza distinzione tra maiuscole e minuscole
* Popolata alla creazione del database con i valori di base `Torrente`, `Fiume`, `Lago`, `Mare`; l'utente può aggiungerne altri.

### **Condizione**
* **`id`**: INTEGER **(PK, autoincrement)**
* `nome`: TEXT `COLLATE NOCASE` **(NOT NULL, UQ)** — non vuoto; unico senza distinzione tra maiuscole e minuscole
* `ordine`: INTEGER **(NOT NULL)**, default 0 — posizione nel form della pescata
* `attiva`: INTEGER **(NOT NULL)**, default 1 — 0/1; una condizione disattivata non è più proposta nelle nuove pescate
* Popolata alla creazione del database con `Livello`, `Trasparenza`, `Fondo`, `Meteo` (vedi §3.7).

### **ValoreCondizione**
* **`id`**: INTEGER **(PK, autoincrement)**
* *`condizione_id`*: INTEGER **(FK, NOT NULL)** $\rightarrow$ `Condizione(id)` — `ON DELETE CASCADE`
* `nome`: TEXT `COLLATE NOCASE` **(NOT NULL)** — non vuoto
* `ordine`: INTEGER **(NOT NULL)**, default 0 — posizione nella scala della condizione (es. Secca 0 … Piena 4)
* `attivo`: INTEGER **(NOT NULL)**, default 1 — 0/1; un valore disattivato non è più proposto nelle nuove pescate
* **UQ** (`condizione_id`, `nome`) — nomi unici all'interno della stessa condizione
* **UQ** (`id`, `condizione_id`) — chiave candidata usata dalla FK composta di `Pescata_Condizione`

### **Ambiente_Condizione** *(Relazione N:M "prevede")*
* *`ambiente_nome`*: TEXT `COLLATE NOCASE` **(PK, FK)** $\rightarrow$ `Ambiente(nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* *`condizione_id`*: INTEGER **(PK, FK)** $\rightarrow$ `Condizione(id)` — `ON DELETE CASCADE`
* Indica quali condizioni proporre nel form per gli spot di un ambiente; non vincola i dati delle pescate (vedi §3.7).

### **Spot**
* **`nome`**: TEXT **(PK)** — non vuoto
* *`ambiente`*: TEXT `COLLATE NOCASE` **(FK, NOT NULL)** $\rightarrow$ `Ambiente(nome)` — `ON DELETE RESTRICT`, `ON UPDATE CASCADE`
* `lunghezzaMetri`: REAL *(NULL)* — > 0; calcolata automaticamente dalle coordinate se presenti almeno 2 punti
* `voto`: REAL *(NULL)* — tra 0 e 10, ammessi decimali (es. 4.5)
* `difficolta`: TEXT *(NULL)* — `bassa | media | alta`
* `noteOstacoli`: TEXT *(NULL)*
* `note`: TEXT *(NULL)*
* `battuto`: INTEGER **(NOT NULL)**, default 0 — 1 se esiste almeno una pescata nello spot (mantenuto dai repository)
* `accessibilita`: TEXT **(NOT NULL)**, default `accessibile` — `accessibile | inaccessibile`
* `linkParcheggio`: TEXT *(NULL)*
* *`categoria_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Categoria(nome)` — `ON DELETE RESTRICT`, `ON UPDATE CASCADE`

### **Coordinata**
* *`spot_nome`*: TEXT **(PK, FK)** $\rightarrow$ `Spot(nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* **`ordine`**: INTEGER **(PK)** — ≥ 0, indice posizionale del punto nel tracciato
* `latitudine`: REAL **(NOT NULL)** — tra -90 e 90
* `longitudine`: REAL **(NOT NULL)** — tra -180 e 180

### **Divieto** *(tratto in cui non si può pescare; non è uno spot)*
* **`id`**: INTEGER **(PK, autoincrement)**
* `nome`: TEXT **(NOT NULL)** — non vuoto; non unico, più divieti possono chiamarsi allo stesso modo
* `note`: TEXT *(NULL)*

### **CoordinataDivieto**
* *`divieto_id`*: INTEGER **(PK, FK)** $\rightarrow$ `Divieto(id)` — `ON DELETE CASCADE`
* **`ordine`**: INTEGER **(PK)** — ≥ 0, indice posizionale del punto nel tracciato
* `latitudine`: REAL **(NOT NULL)** — tra -90 e 90
* `longitudine`: REAL **(NOT NULL)** — tra -180 e 180
* Un divieto ha almeno un punto: il vincolo è verificato da `TerritorioRepository.salvaDivieto` (vedi §3.9).

### **Pianificazione**
* **`id`**: INTEGER **(PK, autoincrement)**
* `data`: TEXT **(NOT NULL)** — data ISO valida
* `fasciaOraria`: TEXT **(NOT NULL)** — `alba | mattina | pomeriggio | tramonto | sera | notte`
* `note`: TEXT *(NULL)*
* *`spot_nome`*: TEXT *(FK, NULL)* $\rightarrow$ `Spot(nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`

### **Pescata**
* **`id`**: INTEGER **(PK, autoincrement)**
* `data`: TEXT **(NOT NULL)** — data ISO valida
* `fasciaOraria`: TEXT **(NOT NULL)** — `alba | mattina | pomeriggio | tramonto | sera | notte`
* `temp_acqua`: REAL *(NULL)* — tra 0 e 35 °C
* `note`: TEXT *(NULL)*
* *`spot_nome`*: TEXT *(FK, NULL)* $\rightarrow$ `Spot(nome)` — `ON DELETE SET NULL`, `ON UPDATE CASCADE`. Nullable solo per consentire il `SET NULL` quando uno spot viene eliminato: alla creazione lo spot è obbligatorio (vedi §3.4)

### **Pescata_Condizione** *(valore scelto per una condizione in una pescata)*
* *`pescata_id`*: INTEGER **(PK, FK)** $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`condizione_id`*: INTEGER **(PK)**
* `valore_id`: INTEGER **(NOT NULL)**
* **FK** (`valore_id`, `condizione_id`) $\rightarrow$ `ValoreCondizione(id, condizione_id)` — `ON DELETE RESTRICT`
* La chiave primaria (`pescata_id`, `condizione_id`) ammette al massimo un valore per condizione in ogni pescata; la FK composta garantisce che il valore appartenga alla condizione indicata.

### **CellaMeteo**
* **`id`**: INTEGER **(PK, autoincrement)**
* `latitudine`: REAL **(NOT NULL)** — tra -90 e 90; coordinate della cella della griglia restituite da Open-Meteo
* `longitudine`: REAL **(NOT NULL)** — tra -180 e 180
* `elevazione`: REAL **(NOT NULL)** — quota (m) del punto richiesto, restituita da Open-Meteo, che la usa per correggere le temperature
* **UQ** (`latitudine`, `longitudine`, `elevazione`) — la stessa cella della griglia a quote diverse dà celle distinte, perché le temperature cambiano con la quota

### **MeteoGiornaliero**
* *`cella_id`*: INTEGER **(PK, FK)** $\rightarrow$ `CellaMeteo(id)` — `ON DELETE CASCADE`
* **`data`**: TEXT **(PK)** — data ISO valida (giorno locale)
* `pioggia_mm`: REAL *(NULL)* — ≥ 0
* `temp_min`, `temp_max`: REAL *(NULL)* — °C
* `pressione_media`: REAL *(NULL)* — hPa, ridotta al livello del mare
* `vento_max`, `raffica_max`: REAL *(NULL)* — km/h
* `direzione_vento`: INTEGER *(NULL)* — gradi tra 0 e 360 (direzione dominante)

### **MeteoOrario**
* *`cella_id`*: INTEGER **(PK, FK)** $\rightarrow$ `CellaMeteo(id)` — `ON DELETE CASCADE`
* **`data_ora`**: TEXT **(PK)** — formato `AAAA-MM-GGTHH:00`, **in UTC** (in ora locale il cambio dell'ora legale produrrebbe ore ripetute o mancanti)
* `pioggia_mm`: REAL *(NULL)* — ≥ 0
* `temperatura`: REAL *(NULL)* — °C
* `pressione`: REAL *(NULL)* — hPa, ridotta al livello del mare
* `vento`, `raffica`: REAL *(NULL)* — km/h
* `direzione_vento`: INTEGER *(NULL)* — gradi tra 0 e 360

### **PescataMeteo** *(dati della richiesta meteo di una pescata)*
* *`pescata_id`*: INTEGER **(PK, FK)** $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`cella_id`*: INTEGER **(FK, NOT NULL)** $\rightarrow$ `CellaMeteo(id)` — `ON DELETE CASCADE`
* `data`: TEXT **(NOT NULL)** — data della pescata al momento della richiesta
* `latitudine`, `longitudine`: REAL **(NOT NULL)** — punto dello spot usato per la richiesta (prima coordinata del tratto)

### **Esca**
* **`id`**: INTEGER **(PK, autoincrement)**
* `nome`: TEXT **(NOT NULL)** — non vuoto
* `descrizione`: TEXT *(NULL)*

### **Pescata_Esca** *(Relazione N:M "usa")*
* *`pescata_id`*: INTEGER **(PK, FK)** $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`esca_id`*: INTEGER **(PK, FK)** $\rightarrow$ `Esca(id)` — `ON DELETE CASCADE`

### **Specie**
* **`nome`**: TEXT **(PK)** — non vuoto
* `informazioni`: TEXT *(NULL)*

### **CatturaMemorabile**
* **`id`**: INTEGER **(PK, autoincrement)**
* `descrizione`: TEXT *(NULL)*
* *`pescata_id`*: INTEGER **(FK, NOT NULL)** $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`specie_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Specie(nome)` — `ON DELETE RESTRICT`, `ON UPDATE CASCADE`
* *`esca_id`*: INTEGER *(FK, NULL)* $\rightarrow$ `Esca(id)` — `ON DELETE SET NULL`
* **UQ** (`id`, `specie_nome`) — chiave candidata usata dalle FK composte (vedi §3.2)

### **Foto**
* **`id`**: INTEGER **(PK, autoincrement)**
* `percorso`: TEXT **(NOT NULL)** — percorso relativo alla cartella documenti dell'app
* `percorsoThumbnail`: TEXT **(NOT NULL)** — percorso relativo alla cartella documenti dell'app
* *`pescata_id`*: INTEGER *(FK, NULL)* $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`cattura_memorabile_id`*: INTEGER *(FK, NULL)* $\rightarrow$ `CatturaMemorabile(id)` — `ON DELETE CASCADE`
* *`esca_id`*: INTEGER *(FK, NULL)* $\rightarrow$ `Esca(id)` — `ON DELETE CASCADE`

### **RiepilogoSpecie**
* **`id`**: INTEGER **(PK, autoincrement)**
* *`pescata_id`*: INTEGER **(FK, NOT NULL)** $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`specie_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Specie(nome)` — `ON DELETE RESTRICT`, `ON UPDATE CASCADE`
* `quantita`: INTEGER **(NOT NULL)** — ≥ 0
* **UQ** (`pescata_id`, `specie_nome`) — una sola riga per specie in ogni pescata
* **UQ** (`id`, `specie_nome`) — chiave candidata usata dalle FK composte

### **Caratteristica**
* **`id`**: INTEGER **(PK, autoincrement)**
* *`specie_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Specie(nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* `nome`: TEXT **(NOT NULL)** — non vuoto
* `descrizione`: TEXT *(NULL)*
* **UQ** (`specie_nome`, `nome`) — nomi unici all'interno della stessa specie
* **UQ** (`id`, `specie_nome`) — chiave candidata usata dalle FK composte

### **Cattura_Caratteristica** *(Relazione N:M "soddisfa")*
* *`cattura_memorabile_id`*: INTEGER **(PK)**
* *`caratteristica_id`*: INTEGER **(PK)**
* `specie_nome`: TEXT **(NOT NULL)**
* **FK** (`cattura_memorabile_id`, `specie_nome`) $\rightarrow$ `CatturaMemorabile(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* **FK** (`caratteristica_id`, `specie_nome`) $\rightarrow$ `Caratteristica(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`

### **Obiettivo**
* **`id`**: INTEGER **(PK, autoincrement)**
* *`specie_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Specie(nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* `anno`: INTEGER **(NOT NULL)** — tra 2000 e 2100
* `quantita`: INTEGER **(NOT NULL)** — > 0
* `caratteristica_id`: INTEGER *(NULL)* — se NULL l'obiettivo riguarda l'intera specie
* **FK** (`caratteristica_id`, `specie_nome`) $\rightarrow$ `Caratteristica(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`

### **DettaglioRiepilogo** *(Relazione N:M "dettaglio")*
* *`riepilogo_specie_id`*: INTEGER **(PK)**
* *`caratteristica_id`*: INTEGER **(PK)**
* `specie_nome`: TEXT **(NOT NULL)**
* `quantita`: INTEGER **(NOT NULL)** — ≥ 0
* **FK** (`riepilogo_specie_id`, `specie_nome`) $\rightarrow$ `RiepilogoSpecie(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* **FK** (`caratteristica_id`, `specie_nome`) $\rightarrow$ `Caratteristica(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`

---

## 3. Vincoli d'Integrità

### 3.1 Esclusività Foto (XOR) — *garantito da CHECK*
Ogni tupla di `Foto` appartiene esattamente a uno tra pescata, cattura memorabile ed esca: una sola delle tre colonne `pescata_id`, `cattura_memorabile_id`, `esca_id` è valorizzata, mai due o tre insieme e mai nessuna.

### 3.2 Concordanza di Specie — *garantito da FK composte*
* In `Cattura_Caratteristica` la caratteristica deve appartenere alla stessa specie della `CatturaMemorabile`.
* In `Obiettivo`, se è indicata una caratteristica, essa deve appartenere alla specie dell'obiettivo.
* In `DettaglioRiepilogo` la caratteristica deve appartenere alla specie del `RiepilogoSpecie`.

Tutti e tre i casi sono garantiti dal database: la colonna `specie_nome` è ripetuta nella tabella figlia e partecipa a entrambe le chiavi esterne composte, che puntano alle coppie `UNIQUE (id, specie_nome)` delle tabelle padre. Una caratteristica di una specie diversa viola quindi una delle due FK.

### 3.3 Quantità nel Dettaglio — *garantito dai repository*
La quantità di un `DettaglioRiepilogo` non può superare la quantità del `RiepilogoSpecie` a cui appartiene:
$$\text{quantità}(\text{DettaglioRiepilogo}) \le \text{quantità}(\text{RiepilogoSpecie})$$
Il vincolo coinvolge due tabelle e non è esprimibile con un `CHECK`: è verificato in `PescateRepository.salvaPescata` prima del salvataggio, che è l'unico punto in cui si scrivono i riepiloghi.

### 3.4 Spot obbligatorio per le pescate — *garantito dai repository*
Una nuova pescata deve avere uno spot, e a una pescata esistente non si può togliere lo spot. La colonna `Pescata.spot_nome` non può essere `NOT NULL`, perché deve poter diventare NULL per effetto di `ON DELETE SET NULL` quando lo spot viene eliminato: il vincolo è quindi verificato in `PescateRepository.salvaPescata`. Una pescata rimasta senza spot dopo l'eliminazione dello spot resta modificabile.

### 3.5 Domini estendibili — *garantiti da FK*
L'ambiente di uno spot e le condizioni di una pescata non sono domini chiusi ma tabelle di dominio (`Ambiente`, `Condizione`, `ValoreCondizione`) che l'utente può ampliare: le chiavi esterne impediscono valori non registrati o scritti in modo diverso, e la collation `NOCASE` evita duplicati che differiscono solo per maiuscole e minuscole (`Torrente` / `torrente`). Per le condizioni la colonna `ordine` conserva la scala dei valori anche quando sono definiti dall'utente, così filtri e statistiche possono confrontarli (es. "livello da Normale in su"). Restano domini chiusi solo la fascia oraria, comune a ogni tipo di pesca, e la difficoltà e l'accessibilità dello spot.

### 3.6 Domini chiusi e formati — *garantiti da CHECK*
Stringhe non vuote per i nomi, intervalli numerici (voto, temperature, coordinate, anno, quantità), valori ammessi delle enumerazioni, date di calendario valide. In SQLite un valore `NULL` supera sempre un `CHECK`, quindi i campi facoltativi restano facoltativi.

### 3.7 Condizioni e ambienti: una guida per il form, non un vincolo — *scelta progettuale*
`Ambiente_Condizione` dice quali condizioni proporre registrando una pescata in uno spot di un certo ambiente (es. il Livello per il Torrente, lo Stato del mare per il Mare). Il database **non** impone però che le condizioni di una pescata siano previste dall'ambiente del suo spot: se lo facesse, cambiare l'ambiente di uno spot o scollegare una condizione renderebbe invalide le pescate già registrate. Le righe di `Pescata_Condizione` restano quindi valide qualunque cosa accada ai collegamenti, e il form mostra sempre le condizioni previste più quelle che la pescata ha già compilato.

Alla creazione del database: `Livello` (Secca, Magra, Normale, Morbida, Piena), `Trasparenza` (Sporca, Velata, Chiara) e `Fondo` (Scuro, Normale, Pulito) sono collegate a Torrente e Fiume; `Meteo` (Sereno, Velato, Variabile, Coperto, Plumbeo, Pioggia, Ventoso) a tutti e quattro gli ambienti di base.

### 3.8 Archivio meteo e stato calcolato — *scelta progettuale*
I dati meteo non sono copiati in ogni pescata ma archiviati per **cella della griglia del modello meteo** (circa 2 km, alla quota del punto) e per giorno (`MeteoGiornaliero`) o ora (`MeteoOrario`): pescate vicine nello spazio e nel tempo condividono le stesse righe, e un giorno già in archivio non viene riscaricato. Per ogni pescata servono i 30 giorni precedenti più il giorno della pescata (giornalieri) e il giorno prima più il giorno della pescata (orari); le finestre statistiche (es. pioggia degli ultimi 14 giorni) si calcolano con query su questi dati.

Lo **stato del meteo** di una pescata (*da scaricare*, *scaricato*, *non disponibile*) non è una colonna ma viene **calcolato** confrontando la pescata con `PescataMeteo`, che conserva la data e il punto usati per la richiesta:
* *scaricato* se esiste la riga e data e punto coincidono con quelli attuali (o lo spot non esiste più);
* *da scaricare* se lo spot ha almeno una coordinata ma la riga manca o non coincide più;
* *non disponibile* se lo spot non ha coordinate.

In questo modo nessun altro componente deve ricordarsi di "invalidare" il meteo: spostare la data di una pescata o il primo punto di uno spot la rende automaticamente da scaricare, mentre rinominare o eliminare lo spot non tocca i dati.

Tutti i dati vengono da un'unica fonte, l'archivio delle previsioni passate di Open-Meteo (modello ICON-D2, circa 2 km): per questo non serve una colonna che distingua la provenienza, e un dato riscaricato sostituisce semplicemente quello precedente.

### 3.9 Divieti separati dagli spot — *scelta progettuale*
Un divieto è un tratto in cui non si pesca: ha un nome e un tracciato come uno spot, ma nessuno degli altri attributi dello spot (categoria, ambiente, voto, stato *battuto*) ha senso per lui, e non deve comparire tra gli spot, nelle pescate o nelle statistiche. Per questo è un'entità a parte con la propria tabella dei punti, invece di uno spot con un indicatore. La chiave è un `id` e non il nome, perché più divieti possono chiamarsi allo stesso modo. Non c'è alcun legame con gli spot: se uno spot entra in un divieto lo si vede sulla mappa. Un divieto senza punti non sarebbe visibile, quindi `TerritorioRepository.salvaDivieto` ne richiede almeno uno; il vincolo coinvolge due tabelle e non è esprimibile con un `CHECK`.

---

## 4. Politiche di Eliminazione e Aggiornamento

| Operazione | Effetto |
| :--- | :--- |
| Eliminare una **Categoria** | Bloccata (`RESTRICT`) se contiene spot: prima vanno spostati in un'altra categoria (`TerritorioRepository.spostaSpot`). |
| Eliminare un **Ambiente** | Bloccata (`RESTRICT`) se usato da almeno uno spot; altrimenti elimina i suoi collegamenti con le condizioni (`CASCADE`). |
| Eliminare un **Valore di condizione** | Bloccata (`RESTRICT`) se usato in almeno una pescata: va disattivato. |
| Eliminare una **Condizione** | Elimina valori e collegamenti agli ambienti (`CASCADE`), ma è bloccata se uno dei suoi valori è usato in una pescata (il `RESTRICT` sul valore blocca la cascata): va disattivata. |
| Rinominare una **Categoria** / **Ambiente** / **Spot** / **Specie** | Il nuovo nome si propaga a tutte le tabelle figlie (`ON UPDATE CASCADE`). |
| Eliminare uno **Spot** | Elimina coordinate (tratto) e pianificazioni (`CASCADE`); le pescate restano nello storico con `spot_nome = NULL` (`SET NULL`). |
| Eliminare un **Divieto** | Elimina i suoi punti (`CASCADE`). Nessun'altra tabella fa riferimento ai divieti. |
| Eliminare una **Pescata** | Elimina il collegamento al meteo (`PescataMeteo`; l'archivio meteo resta), valori delle condizioni, legami con le esche, riepiloghi, dettagli, catture memorabili e foto (`CASCADE`); il repository cancella anche i file immagine dal disco e ricalcola `Spot.battuto`. |
| Eliminare una **CellaMeteo** | Elimina il suo archivio giornaliero e orario e i collegamenti delle pescate, che tornano da scaricare (`CASCADE`). L'app non elimina mai le celle: la regola garantisce solo la coerenza. |
| Eliminare un'**Esca** | Elimina i legami con le pescate e le sue foto (`CASCADE`); nelle catture memorabili il riferimento diventa NULL (`SET NULL`). |
| Eliminare una **Specie** | Bloccata (`RESTRICT`) se usata in riepiloghi o catture memorabili; altrimenti elimina caratteristiche e obiettivi (`CASCADE`). |
| Eliminare una **Caratteristica** | Elimina obiettivi, dettagli e associazioni con le catture che la usano (`CASCADE`). |

---

## 5. Indici

| Indice | Tabella (colonne) |
| :--- | :--- |
| `idx_spot_categoria` | Spot (categoria_nome) |
| `idx_spot_ambiente` | Spot (ambiente) |
| `idx_pescata_data` | Pescata (data) |
| `idx_pescata_spot` | Pescata (spot_nome) |
| `idx_pianificazione_spot` | Pianificazione (spot_nome) |
| `idx_pescata_esca_esca` | Pescata_Esca (esca_id) |
| `idx_cattura_pescata` | CatturaMemorabile (pescata_id) |
| `idx_cattura_specie` | CatturaMemorabile (specie_nome) |
| `idx_cattura_esca` | CatturaMemorabile (esca_id) |
| `idx_foto_pescata` | Foto (pescata_id) |
| `idx_foto_esca` | Foto (esca_id) |
| `idx_foto_cattura` | Foto (cattura_memorabile_id) |
| `idx_riepilogo_specie` | RiepilogoSpecie (specie_nome) |
| `idx_cattcar_caratteristica` | Cattura_Caratteristica (caratteristica_id) |
| `idx_dettaglio_caratteristica` | DettaglioRiepilogo (caratteristica_id) |
| `idx_obiettivo_anno` | Obiettivo (anno) |
| `idx_ambcond_condizione` | Ambiente_Condizione (condizione_id) |
| `idx_pescond_valore` | Pescata_Condizione (valore_id, condizione_id) |
| `idx_pescatameteo_cella` | PescataMeteo (cella_id) |
