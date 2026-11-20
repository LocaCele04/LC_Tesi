# Scelta Architetturale: Gestione dello Stato con Riverpod

## 1. Contesto e problema

Lo **stato** dell'interfaccia è l'insieme dei dati che l'app tiene in memoria mentre l'utente la usa e che le schermate mostrano: l'elenco degli spot, le pescate, la pescata in compilazione, lo stato del meteo di una pescata, le statistiche.

In *Diario di Pesca* gli stessi dati compaiono in più schermate. Quando l'utente salva una pescata:

* l'elenco delle pescate deve mostrarla;
* lo spot deve risultare *battuto*;
* le statistiche e gli obiettivi devono tenerne conto;
* la pescata risulta *da scaricare* finché il meteo non viene scaricato.

Se ogni schermata leggesse i dati per conto suo, dopo un salvataggio alcune mostrerebbero dati vecchi, oppure ognuna dovrebbe ricordarsi di ricaricare tutto a mano. Serve quindi un meccanismo che:

1. renda i dati disponibili a tutte le schermate che li usano;
2. le aggiorni automaticamente quando i dati cambiano;
3. gestisca il fatto che quasi tutti i dati arrivano in modo **asincrono** (letture da SQLite, scaricamento del meteo, foto), mostrando anche lo stato di *caricamento* e quello di *errore*;
4. non mescoli la logica dell'app con il codice grafico, così da poterla provare con test automatici.

Flutter non impone una soluzione unica: offre il meccanismo di base (`setState`) e lascia la scelta di una libreria allo sviluppatore.

---

## 2. Alternative considerate

| Soluzione | Come funziona | Vantaggi | Svantaggi per questo progetto |
| :--- | :--- | :--- | :--- |
| **`setState`** (integrato in Flutter) | Ogni schermata (`StatefulWidget`) gestisce i propri dati e si ridisegna quando cambiano. | Nessuna dipendenza, immediato da imparare. | I dati non si condividono tra schermate: vanno passati a mano nei costruttori e ricaricati dopo ogni modifica. Logica e grafica finiscono nella stessa classe e si testano solo con test dell'interfaccia. Adatto solo allo stato *locale* di un widget. |
| **Provider** | Classi `ChangeNotifier` messe a disposizione dell'albero dei widget; le schermate le "ascoltano" e si ridisegnano quando notificano un cambiamento. | Semplice, molto diffuso, citato nella documentazione ufficiale di Flutter. | Il caricamento asincrono (in corso / errore / pronto) va gestito a mano in ogni classe. Dipende dalla posizione nell'albero dei widget e dal `BuildContext` (errori a runtime se un provider non è "sopra" la schermata). Le dipendenze tra provider sono meno comode da esprimere. Lo stesso autore ha poi creato Riverpod proprio per superare questi limiti. |
| **Riverpod** (scelta) | I provider sono dichiarati come variabili globali e indipendenti dai widget; ogni provider può dipendere da altri; le schermate li osservano tramite `ref.watch`. | Gestione nativa dei dati asincroni (`AsyncValue`), dipendenze esplicite tra provider, sostituzione dei provider nei test, nessuna dipendenza dal `BuildContext`, errori rilevati in compilazione. | Un pacchetto esterno e alcuni concetti nuovi da imparare (provider, notifier, `watch`/`read`, `invalidate`). |
| **Bloc / Cubit** | Lo stato cambia solo in risposta a eventi, attraverso classi dedicate. | Molto strutturato, diffuso in contesti aziendali, flusso dei dati molto prevedibile. | Richiede molto codice in più (eventi, stati, bloc per ogni funzione). Per un'app sviluppata da una persona sola il costo supera i benefici. |

---

## 3. Decisione

Si adotta **Riverpod 3** (pacchetto `flutter_riverpod`, versione `^3.4.1`), **senza generazione di codice** (`riverpod_generator`): i provider sono scritti a mano.

La versione 3 è stabile dal settembre 2025 ed è mantenuta dallo stesso autore di Provider.

---

## 4. Motivazioni

### A. I dati dell'app sono quasi tutti asincroni
Leggere dal database, scaricare il meteo e caricare le foto richiede tempo. Riverpod rappresenta ogni dato asincrono con `AsyncValue`, che è sempre in uno di tre stati: **caricamento**, **errore** o **dati**. La schermata deve solo dire cosa mostrare in ciascun caso, senza variabili `isLoading` e blocchi `try/catch` ripetuti ovunque. Nel progetto questo è racchiuso in un unico widget riutilizzabile, `VistaAsincrona`.

Durante un aggiornamento Riverpod conserva i dati precedenti, così la schermata non "lampeggia" dopo ogni salvataggio.

### B. Si appoggia all'architettura a strati esistente
Il progetto ha già i livelli dati, repository e servizi (vedi `struttura_del_progetto_diario_di_pesca.md`). Riverpod si aggiunge sopra senza modificarli:

* ogni repository e servizio è esposto da un **provider di dipendenza** (`lib/ui/state/dipendenze.dart`), creato una sola volta;
* i **provider di stato** (es. `elencoSpotProvider`) usano i repository e preparano i dati per le schermate;
* le **schermate** osservano i provider di stato e non conoscono né il database né la rete.

I repository restano classi Dart pure, senza dipendenze da Flutter o da Riverpod: si possono riusare e testare come prima.

### C. Aggiornamento coerente di tutte le schermate
Dopo una modifica non si "aggiusta" lo stato in memoria a mano. Il notifier chiama il repository e **invalida** i provider i cui dati sono cambiati, che si ricaricano dal database. Le schermate che li osservano si ridisegnano da sole. Per esempio, salvare uno spot aggiorna sia l'elenco sia la scheda di dettaglio aperta.

La fonte di verità resta il database, e lo stato in memoria non può divergere da quello salvato. È lo stesso principio già adottato con l'immutabilità dei modelli (`scelta_architetturale_immutabilit_dei_modelli.md`).

### D. Coerenza con i modelli immutabili
Riverpod 3 decide se avvisare le schermate confrontando il valore nuovo con quello vecchio tramite `==`. I modelli del progetto sono immutabili e hanno un'uguaglianza strutturale (tutti i campi, liste comprese). Quindi:

* se un ricaricamento restituisce gli stessi dati, le schermate **non** si ridisegnano inutilmente;
* se un dato cambia, cambia anche il valore, e il cambiamento non può sfuggire.

### E. Indipendenza dall'albero dei widget
I provider non dipendono dalla posizione delle schermate né dal `BuildContext`. Un provider si può leggere da qualunque schermata, da un altro provider o da un test, e un provider mancante è segnalato in compilazione e non a runtime.

### F. Testabilità
Ogni provider può essere **sostituito** (`overrides`) senza toccare il codice dell'app:

* i test dello stato sostituiscono solo `databaseHelperProvider` con un database in memoria e verificano tutta la catena notifier → repository → SQLite (`test/spot_state_test.dart`);
* i test delle schermate sostituiscono direttamente il provider di stato con dati finti, senza database (`test/elenco_spot_screen_test.dart`);
* `ProviderContainer.test()` crea un contenitore che viene eliminato da solo alla fine di ogni test.

### G. Gestione della memoria
I provider di dettaglio (es. la scheda di uno spot) sono dichiarati `autoDispose`: vengono eliminati quando nessuna schermata li usa più, così i dati non restano in memoria inutilmente. Riverpod 3 inoltre sospende i provider usati solo da schermate non visibili.

---

## 5. Organizzazione nel progetto

```
lib/ui/
├── state/
│   ├── dipendenze.dart            # Provider di database, repository, servizi e orologio
│   ├── spot_state.dart            # Stato degli spot (esempio di riferimento)
│   ├── pescate_state.dart         # Elenco delle pescate con salva / elimina
│   ├── catalogo_state.dart        # Esche, specie, caratteristiche, condizioni
│   ├── modulo_pescata_state.dart  # Bozza del modulo "Registra pescata"
│   ├── modulo_spot_state.dart     # Bozza del modulo dello spot
│   └── bozza_non_valida.dart      # Errore comune dei moduli
├── screens/
│   ├── elenco_spot_screen.dart
│   ├── modulo_spot_screen.dart
│   └── registra_pescata_screen.dart
└── widgets/
    ├── vista_asincrona.dart       # Caricamento / errore / dati per ogni AsyncValue
    ├── dialoghi.dart              # Problemi del modulo, richiesta di conferma
    ├── dialogo_nome.dart          # Richiesta di un nome (nuova esca, nuova specie)
    └── etichette.dart             # Testi per l'utente (fasce orarie, date)
```

### 5.1 Regole d'uso
* **Letture**: un provider asincrono carica i dati dal repository. Si usa un `FutureProvider` per i dati di sola lettura (categorie, ambienti, dettaglio di uno spot) e un `AsyncNotifierProvider` quando sugli stessi dati ci sono anche operazioni di modifica (elenco degli spot).
* **Scritture**: sono metodi del notifier (es. `ElencoSpotNotifier.salva`, `elimina`). Chiamano il repository, poi invalidano i provider interessati e attendono il nuovo valore. Quando il metodo termina, le schermate sono già aggiornate.
* **Errori di scrittura**: vengono rilanciati a chi ha chiamato il metodo (di solito un modulo, che mostra il messaggio all'utente). Lo stato già caricato resta invariato.
* **Errori di lettura**: diventano lo stato di errore del provider. La schermata mostra il messaggio e il pulsante *Riprova*, che invalida il provider.
* **Nelle schermate**: `ref.watch` per i dati da mostrare (la schermata si ridisegna quando cambiano), `ref.read` per le azioni (es. il pulsante *Salva* chiama `ref.read(elencoSpotProvider.notifier).salva(...)`).
* **Stato locale**: lo stato puramente visivo di un widget (il testo di un campo di ricerca, una scheda aperta, il pulsante disattivato durante un salvataggio) resta in un `StatefulWidget` con `setState`. Riverpod serve per lo stato condiviso e per i dati che vengono dal database.
* **Moduli complessi**: il contenuto di un modulo con regole (es. *Registra pescata*) sta in un `Notifier` `autoDispose` che tiene una **bozza immutabile** (`BozzaPescata`). Il notifier espone un metodo per ogni modifica (`impostaSpot`, `aggiungiCattura`…); la bozza calcola i propri errori in parole per l'utente e si trasforma nel modello da salvare. Così le regole del modulo si provano con test senza interfaccia (`test/modulo_pescata_test.dart`), e chiudendo la schermata la bozza viene scartata. Quando il modulo modifica un elemento esistente, il provider è una *family* con l'elemento come parametro (`moduloSpotProvider(spot)`): ogni spot aperto ha la sua bozza.
* **Elementi creati al momento**: un'esca, una specie o una categoria scritte dentro un modulo restano nella bozza, *in sospeso*, e nascono nel database solo quando si salva il modulo, nella stessa transazione. Chiudere il modulo senza salvare quindi non lascia nulla nel catalogo, e la regola è la stessa in tutti i moduli. Togliere un elemento in sospeso lo scarta: la bozza dice quando succederebbe (`specieScartata`, `categoriaScartata`) e la schermata chiede conferma prima di farlo.
* **Data di oggi**: chi ha bisogno di "oggi" lo chiede a `orologioProvider`, che nei test si sostituisce con una data fissa.
* Le operazioni composte continuano a passare dai **servizi** (es. `MeteoService`), esposti anch'essi da un provider.

### 5.2 Esempio
```dart
// Stato: elenco degli spot, con le operazioni di modifica
final elencoSpotProvider = AsyncNotifierProvider<ElencoSpotNotifier, List<Spot>>(
  ElencoSpotNotifier.new,
);

class ElencoSpotNotifier extends AsyncNotifier<List<Spot>> {
  @override
  Future<List<Spot>> build() => ref.watch(territorioRepositoryProvider).getSpots();

  Future<void> salva(Spot spot, {String? nomeOriginale}) async {
    await ref.read(territorioRepositoryProvider)
        .salvaSpotConCoordinate(spot, nomeOriginale: nomeOriginale);
    ref.invalidate(dettaglioSpotProvider);
    ref.invalidateSelf();
    await future;
  }
}

// Schermata: mostra caricamento, errore o dati e si aggiorna da sola
final elenco = ref.watch(elencoSpotProvider);
```

---

## 6. Scelte di configurazione

* **Nuovi tentativi automatici disattivati.** Riverpod 3, se un provider fallisce, riprova da solo a intervalli crescenti. Nell'app (`main.dart`) e nei test questo comportamento è disattivato (`retry: (tentativo, errore) => null`), per tre motivi:
  * un errore del database locale (vincolo violato, file danneggiato) non si risolve riprovando;
  * il `MeteoService` gestisce già i propri errori di rete e ritenta al successivo aggiornamento;
  * l'utente ha sempre il pulsante *Riprova*, e nei test un errore deve risultare subito.
* **Niente generazione di codice.** Riverpod offre annotazioni (`@riverpod`) che generano i provider con `build_runner`. Si è preferito scrivere i provider a mano: nessuno strumento aggiuntivo da eseguire, codice esplicito e leggibile così com'è (utile anche per la tesi), e il numero di provider dell'app resta contenuto.
* **Pacchetto `flutter_riverpod`** e non `hooks_riverpod`: gli *hooks* richiederebbero un'ulteriore libreria e un altro stile di scrittura dei widget, senza vantaggi per questa app.

---

## 7. Costi e rischi

* **Curva di apprendimento**: concetti nuovi (provider, notifier, `watch`/`read`, `invalidate`, `autoDispose`). Sono limitati dal fatto che tutte le aree dell'app seguono lo stesso schema di `spot_state.dart`.
* **Dipendenza esterna**: l'app dipende da un pacchetto non ufficiale di Flutter. Il rischio è contenuto: Riverpod è tra i pacchetti più usati e mantenuti, e i repository e i servizi non dipendono da esso, quindi un eventuale cambio di soluzione toccherebbe solo `lib/ui/`.
* **Errori d'uso tipici**: usare `ref.read` dove serve `ref.watch` (la schermata non si aggiorna) o dimenticare di invalidare un provider dopo una scrittura. Il secondo caso è coperto dai test dello stato, che verificano che elenco e dettaglio si aggiornino dopo ogni operazione.
* **Invalidazioni tra aree**: alcune modifiche toccano più aree (rinominare uno spot cambia le pescate collegate). Quando esisteranno i provider delle pescate, i metodi degli spot dovranno invalidare anche quelli: è annotato nel codice (`_ricarica`).

---

## 8. Riferimenti
* Riverpod — documentazione: <https://riverpod.dev>
* Riverpod 3.0 — novità (nuovi tentativi automatici, `ProviderContainer.test`, sospensione dei provider): <https://riverpod.dev/docs/whats_new>
* `flutter_riverpod` su pub.dev: <https://pub.dev/packages/flutter_riverpod>
* Flutter — panoramica delle soluzioni per la gestione dello stato: <https://docs.flutter.dev/data-and-backend/state-mgmt/options>
