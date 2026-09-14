# Piano di Gestione della Configurazione (SCM)

## Indice
1. Introduzione
2. Gestione SCM e Ruoli
3. Attività SCM e Workflow Git
4. Pianificazione delle Attività (Sprint & Ricevimenti)
5. Risorse Utilizzate
6. Guida Operativa all'Uso di GitHub
7. Comunicazione e Feedback con i Relatori

---

# 1. Introduzione

## 1.1 Scopo
Il presente documento definisce le attività, le regole e le procedure relative alla **Gestione della Configurazione del Software (SCM)** per il progetto di tesi *Diario di Pesca*. L'obiettivo è garantire tracciabilità, qualità del codice e rigore metodologico secondo le best practice dell'Ingegneria del Software.

## 1.2 Ambito
Il piano si applica a tutti gli artefatti prodotti durante il lavoro di tesi:
- Codice sorgente dell'applicazione mobile.
- Documentazione architetturale e specifica dei requisiti (nella cartella `/docs`).
- Record delle decisioni architetturali.

## 1.3 Definizioni e Acronimi
- **SCM:** Software Configuration Management.
- **CI/CD:** Continuous Integration / Continuous Deployment.
- **Branch:** Linea di sviluppo separata nel repository Git.
- **Issue:** Task o requisito da implementare/risolvere.
- **PR (Pull Request):** Richiesta di integrazione del codice da un branch secondario a uno principale.
- **ADR:** Architecture Decision Record.

---

# 2. Gestione SCM e Ruoli

## 2.1 Gestione Individuale
Trattandosi di un progetto individuale, la responsabilità operativa della configurazione è interamente dello studente. Tuttavia, la gestione segue una suddivisione logica dei ruoli per garantire disciplina nello sviluppo:

- **Sviluppatore / Architetto / SCM Admin (Celeste Locatelli):** Si occupa della progettazione architetturale, della scrittura del codice, della stesura dei test e della manutenzione del repository.
- **Stakeholders / Product Owners (Prof.ssa Silvia Bonfanti, Prof. Angelo Gargantini):** Definiscono la direzione scientifica/didattica del progetto, valutano l'avanzamento durante i ricevimenti e ne approvano i requisiti globali.

## 2.2 Autorità e Regole di Accesso
- Il ramo `main` rappresenta esclusivamente versioni stabili, testate e pronte per la dimostrazione/consegna.
- Il ramo `dev` rappresenta il ramo di integrazione continua per il lavoro corrente.
- Nessuna modifica viene effettuata direttamente su `main` o `dev`. Ogni modifica avviene tramite branch tematici sottoposti a self-review via PR.

---

# 3. Attività SCM e Workflow Git

## 3.1 Struttura del Repository
- `/src` (o cartella del framework mobile): Codice sorgente del progetto.
- `/docs`: Documentazione di progetto, output diagrammi UML e piani SCM.
- `/diagrams`: sorgenti diagrammi UML

## 3.2 Naming Convention dei Branch
Ogni funzionalità o correzione viene sviluppata su un ramo dedicato a partire da `dev`:
- `feature/nome_feature`: per nuove funzionalità (es. `feature/gps-tracking`).
- `bugfix/nome_bug`: per correzione di errori (es. `bugfix/fix-db-migration`).
- `docs/nome_doc`: per aggiornamenti alla documentazione/UML.
- `hotfix/nome`: per correzioni urgenti.

## 3.3 Semantic Versioning (Tagging)
Al raggiungimento di milestone significative o consegne per il docente, verrà creato un tag nel formato `vX.Y.Z`:
- **X (Major):** Moduli architetturali completi o rilasci principali.
- **Y (Minor):** Nuove funzionalità aggiunte a un modulo.
- **Z (Patch):** Bugfix o piccoli ritocchi.

---

# 4. Pianificazione delle Attività (Sprint & Ricevimenti)

Il ciclo di vita dello sviluppo adotta un approccio **Iterativo ed Incrementale (Solo-Scrum / Scrumban)** guidato dalle scadenze dei ricevimenti con i docenti:

1. **Durata Sprint:** 2 Settimane.
2. **Sprint Planning (Post-Incontro):** Subito dopo il ricevimento con i docenti, l'esito della discussione viene convertito in nuove Issue nella colonna `Backlog` / `To Do` della Kanban Board su GitHub.
3. **Sviluppo & Self-Review (In-Sprint):** Lavorando sulle Issue tramite branch dedicati e Pull Request collegate (`Closes #ID`).
4. **Sprint Review & Demo (Incontro Docenti):** Ogni 2 settimane viene presentata ai docenti la versione corrente (colonna `Done` della Kanban e codice unito su `dev` o `main`).

---

# 5. Risorse Utilizzate

- **GitHub:** Host del repository, Kanban Board (GitHub Projects), Issue Tracking e GitHub Actions (CI).
- **IDE:** IDE scelta per lo sviluppo mobile (es. VSCode / Android Studio).
- **Git:** Versionamento del codice locale e remoto.

---

# 6. Guida Operativa all'Uso di GitHub

## 6.1.1 Clonazione del repository


Prima di tutto per ottenere il progetto sul nostro PC locale dobbiamo clonare il
repository remoto su di esso.
Questa operazione è da svolgersi una **singola volta** all’inizio.

```
git clone https://github.com/LocaCele04/LC_Tesi.git
```

Verrà così creata una cartella locale con tutto il codice e la storia del progetto nella
directory dove ci troviamo (ad es. Desktop).

## 6.1.2 Regole di lavoro


Per evitare problemi sulle versioni stabili non si lavora mai
direttamente sul branch main.
Ogni modifica verrà fatta su un nuovo branch a partire dal branch di sviluppo dev
seguendo questa naming convention:
- feature/nome_feature , per nuove funzionalità (ad es. feature/login_page).
- bugfix/nome_bug , per correzioni (ad es. bugfix/fix_login_page).
- hotfix/nome , per correzioni urgenti (ad es. hotfix/deploy_error).  

Utilizzare nomi chiari e coerenti con ciò che il branch tratta, così da far
capire e ricordare nell’immediato con cosa si ha a che fare.


## 6.1.3 Creazione di un branch


Prima di iniziare a fare qualsiasi modifica, si deve aggiornare sempre il repository
locale eseguendo un pull tramite Github Desktop così da ottenere i file aggiornati
all’ultima modifica applicata.
Solo dopo si crea un nuovo branch a partire da dev per iniziare a lavorare sulla
modifica.

## 6.1.4 Salvare e caricare le modifiche


Quando vengono eseguite delle modifiche e si ritiene utile il caricamento delle
stesse sul repository remoto allora si può eseguire un commit sempre tramite
Github Desktop utilizzando:
- Titolo, deve essere breve e far intendere al volo cosa si è modificato.
- Descrizione, qui si deve descrivere bene i cambiamenti effettuati ed il
motivo; inoltre se ritenuto necessario si dovrebbe spiegare ancora meglio
delle modifiche apportate che potrebbero risultare difficile da comprendere.


## 6.1.5 Pull Request


Quando si è soddisfatti della propria modifica allora si può eseguire una Pull
Request.
Qui si deve prima di tutto comparare le modifiche e stare attenti di selezionare
la direzione della PR, che deve essere base: *branch_precedente* <- compare:
*nuovo_branch* (dove *branch_precedente* dovrà quasi sempre essere dev tranne
quando si decide di fare il merge con il main). Si devono
scegliere, così come quando si esegue un commit, un titolo ed una
descrizione del lavoro svolto che siano chiari e concisi. 

**N.B.**:
Come titolo della PR si deve mettere *titolo_pr keyword #numero_issue*
Dove:
- *titolo_pr*, indica il titolo chiaro della stessa
- *keyword*, deve essere una tra quelle proposte [qui](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue).
Così avviene il link tra issue e PR, così che una volta approvata la PR
l’issue verrà chiuso in automatico eventualmente.
- *#numero_issue*, indica il numero che Github assegna in automatico
all’issue, così che quando eventualmente chiude sa quale issue deve
prendere.



Solo dopo eventuale approvazione quindi verrà effettuato il merge nel branch dev
e sta ai Repository Admin poi effettuare il merge nel main una volta ritenuto
idoneo.

## 6.1.6 Best practices

1. Prima di eseguire qualsiasi modifica ricorda di aggiornare il repository
    locale tramite **pull**.
2. Per evitare al meglio conflitti e/o file persi si dovrebbe creare un branch per
    risolvere o implementare **funzionalità** “ **piccole** ” man mano, ovvero che non
    richiedano troppo tempo.
3. Non si deve **modificare/eliminare file** che si sta modificando
    in quel momento in altri branch per evitare conflitti.
4. In caso di eventuali conflitti procedere con il **merge** dopo aver risolto i problemi di salvataggio.


## 6.2 Gestione della Board Kanban (GitHub Projects)

La gestione dei task e l'avanzamento dei lavori avvengono visivamente tramite la scheda **Projects** su GitHub, organizzata secondo la metodologia Kanban.

### 6.2.1 Struttura delle Colonne
La board è suddivisa nelle seguenti colonne operative:
- 📌 **Backlog:** Contiene tutte le idee, i requisiti generali e le funzionalità future identificate per la tesi ma non ancora pianificate per lo sprint corrente.
- 📋 **To Do:** Task e Issue selezionati durante lo *Sprint Planning* da completare nelle due settimane correnti.
- ⚙️ **In Progress:** Issue su cui si sta attivamente lavorando nel giorno/sessione corrente.
- 🔍 **In Review:** Pull Request aperte in attesa di verifica, esecuzione della CI o merge su `dev`.
- ✅ **Done:** Task completati, testati e il cui codice è stato integrato con successo nei branch di riferimento.

### 6.2.2 Automazioni della Board
- **Aggiunta Automatica:** Ogni nuova Issue creata nel repository viene inserita automaticamente nella board (colonna *Backlog*).
- **Avanzamento Automatico:** Quando una PR collegata a un'Issue viene unita (*merged*), GitHub sposta automaticamente l'Issue correlata nella colonna **Done** e ne aggiorna lo stato in *Closed*.

---

# 7. Comunicazione e Feedback con i Relatori (GitHub Discussions)

Per facilitare l'interazione con i relatori e mantenere traccia storica di tutte le decisioni e i feedback senza sovrappopolare la gestione dei task tecnici (Issue), il progetto utilizza **GitHub Discussions**.

## 7.1 Categorie delle Discussions

La sezione **Discussions** del repository è organizzata nelle seguenti categorie principali:

- 📢 **Announcements:**
  - **Verbale Ricevimento:** Spazio a disposizione dei relatori per fornire indicazioni, linee guida e avvisi.
- ❓ **Q&A / Domande & Chiarimenti:**
  - Spazio a disposizione dei relatori per porre domande sull'architettura, sulla documentazione o sulle scelte implementative.
  - Spazio per lo studente per richiedere chiarimenti su requisiti o indicazioni teoriche/metodologiche.
- 💡 **Ideas & Feedback:**
  - Spazio dedicato alla discussione di nuove idee o cambi di direzione proposti dai docenti.

## 7.2 Guida Sintetica per i Docenti

Per lasciare un commento, un feedback o fare una domanda:
1. Accedere alla scheda **Discussions** nella barra principale del repository su GitHub.
2. Per fare una nuova domanda o proposta, cliccare su **New discussion**, selezionare la categoria idonea (es. *Q&A* o *Ideas*) e inserire il testo.

