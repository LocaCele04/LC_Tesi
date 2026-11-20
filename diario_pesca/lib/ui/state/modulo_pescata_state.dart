import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalogo/caratteristica.dart';
import '../../models/catalogo/condizione.dart';
import '../../models/catalogo/esca.dart';
import '../../models/catalogo/valore_condizione.dart';
import '../../models/enums.dart';
import '../../models/pescate/pescata.dart';
import '../../models/pescate/riepilogo_caratteristica.dart';
import '../../models/pescate/riepilogo_specie.dart';
import 'bozza_non_valida.dart';
import 'dipendenze.dart';

export 'bozza_non_valida.dart';
import 'pescate_state.dart';

/// Catture di una specie nel modulo: specie, totale e quante catture hanno
/// ciascuna caratteristica (es. 7 trote, di cui 5 "Over 30").
class BozzaCattura {
  /// Identifica la riga nel modulo anche se cambia la specie (serve ai
  /// campi di testo per non scambiarsi i valori quando si toglie una riga).
  final int chiave;
  final String? specieNome;
  final int totale;
  final Map<Caratteristica, int> dettagli;

  const BozzaCattura({
    required this.chiave,
    this.specieNome,
    this.totale = 0,
    this.dettagli = const {},
  });

  BozzaCattura copyWith({
    String? specieNome,
    int? totale,
    Map<Caratteristica, int>? dettagli,
  }) {
    return BozzaCattura(
      chiave: chiave,
      specieNome: specieNome ?? this.specieNome,
      totale: totale ?? this.totale,
      dettagli: dettagli ?? this.dettagli,
    );
  }
}

/// Contenuto del modulo "Registra pescata" mentre l'utente lo compila.
///
/// È immutabile come i modelli: ogni modifica crea una nuova bozza. Le
/// temperature restano testo finché non si salva, così un valore scritto a
/// metà ("12,") non viene perso né trasformato.
class BozzaPescata {
  final String? spotNome;

  /// Ambiente dello spot scelto: decide quali condizioni compilare.
  final String? ambiente;
  final DateTime data;
  final FasciaOraria? fasciaOraria;

  /// Valore scelto per ogni condizione, per id della condizione.
  final Map<int, ValoreCondizione> valori;
  final List<Esca> esche;
  final List<BozzaCattura> catture;
  final String tempAcqua;
  final String tempAria;
  final String note;

  const BozzaPescata({
    this.spotNome,
    this.ambiente,
    required this.data,
    this.fasciaOraria,
    this.valori = const {},
    this.esche = const [],
    this.catture = const [],
    this.tempAcqua = '',
    this.tempAria = '',
    this.note = '',
  });

  BozzaPescata copyWith({
    String? spotNome,
    String? ambiente,
    DateTime? data,
    FasciaOraria? fasciaOraria,
    Map<int, ValoreCondizione>? valori,
    List<Esca>? esche,
    List<BozzaCattura>? catture,
    String? tempAcqua,
    String? tempAria,
    String? note,
  }) {
    return BozzaPescata(
      spotNome: spotNome ?? this.spotNome,
      ambiente: ambiente ?? this.ambiente,
      data: data ?? this.data,
      fasciaOraria: fasciaOraria ?? this.fasciaOraria,
      valori: valori ?? this.valori,
      esche: esche ?? this.esche,
      catture: catture ?? this.catture,
      tempAcqua: tempAcqua ?? this.tempAcqua,
      tempAria: tempAria ?? this.tempAria,
      note: note ?? this.note,
    );
  }

  /// Somma delle catture di tutte le specie.
  int get totaleCatture => catture.fold(0, (somma, c) => somma + c.totale);

  bool contieneEsca(Esca esca) => esche.any((e) => _stessaEsca(e, esca));

  /// Problemi che impediscono il salvataggio, in parole per l'utente.
  /// Vuoto se la bozza si può salvare.
  List<String> errori({DateTime? oggi}) {
    final problemi = <String>[];
    if (spotNome == null) problemi.add('Scegli lo spot.');
    if (fasciaOraria == null) problemi.add('Scegli la fascia oraria.');

    final adesso = oggi ?? DateTime.now();
    if (data.isAfter(DateTime(adesso.year, adesso.month, adesso.day))) {
      problemi.add('La data non può essere nel futuro.');
    }

    _controllaTemperatura(problemi, tempAcqua, 'dell\'acqua', 0, 35);
    _controllaTemperatura(problemi, tempAria, 'dell\'aria', -30, 45);

    final specieViste = <String>{};
    for (var i = 0; i < catture.length; i++) {
      final c = catture[i];
      final nome = c.specieNome ?? 'specie n. ${i + 1}';
      if (c.specieNome == null) {
        problemi.add('Scegli la specie della riga ${i + 1} delle catture.');
      } else if (!specieViste.add(c.specieNome!.toLowerCase())) {
        problemi.add('${c.specieNome} compare due volte nelle catture.');
      }
      if (c.totale < 1) {
        problemi.add('Indica quante catture di $nome (o togli la riga).');
      }
      for (final d in c.dettagli.entries) {
        if (d.value > c.totale) {
          problemi.add(
            '"${d.key.nome}" ($nome): ${d.value} è più del totale (${c.totale}).',
          );
        }
      }
    }
    return problemi;
  }

  /// Pescata da salvare. Da chiamare solo se [errori] è vuoto.
  Pescata inPescata() {
    final noteTrim = note.trim();
    return Pescata(
      data: data,
      fasciaOraria: fasciaOraria!,
      spotNome: spotNome,
      tempAcqua: _numero(tempAcqua),
      tempAria: _numero(tempAria),
      note: noteTrim.isEmpty ? null : noteTrim,
      valoriCondizioni: valori.values.toList(),
      esche: esche,
      riepiloghiSpecie: [
        for (final c in catture)
          RiepilogoSpecie(
            specieNome: c.specieNome!,
            quantita: c.totale,
            dettagli: [
              for (final d in c.dettagli.entries)
                if (d.value > 0)
                  RiepilogoCaratteristica(caratteristica: d.key, quantita: d.value),
            ],
          ),
      ],
    );
  }

  static void _controllaTemperatura(
    List<String> problemi,
    String testo,
    String di,
    double minimo,
    double massimo,
  ) {
    if (testo.trim().isEmpty) return;
    final valore = _numero(testo);
    if (valore == null) {
      problemi.add('La temperatura $di non è un numero.');
    } else if (valore < minimo || valore > massimo) {
      problemi.add(
        'La temperatura $di deve essere tra ${minimo.round()} e ${massimo.round()} °C.',
      );
    }
  }

  /// Numero scritto dall'utente, con la virgola o con il punto.
  static double? _numero(String testo) {
    final pulito = testo.trim().replaceAll(',', '.');
    return pulito.isEmpty ? null : double.tryParse(pulito);
  }
}

bool _stessaEsca(Esca a, Esca b) => a.id != null && b.id != null
    ? a.id == b.id
    : a.nome.trim().toLowerCase() == b.nome.trim().toLowerCase();

/// Stato del modulo "Registra pescata". È `autoDispose`: chiudendo la
/// schermata la bozza viene scartata e la prossima apertura riparte vuota.
final moduloPescataProvider = NotifierProvider.autoDispose<ModuloPescataNotifier, BozzaPescata>(
  ModuloPescataNotifier.new,
);

class ModuloPescataNotifier extends Notifier<BozzaPescata> {
  int _prossimaChiave = 0;

  @override
  BozzaPescata build() {
    final oggi = ref.read(orologioProvider)();
    return BozzaPescata(data: DateTime(oggi.year, oggi.month, oggi.day));
  }

  /// Sceglie lo spot. Se cambia l'ambiente cambiano le condizioni da
  /// compilare, quindi i valori già scelti vengono tolti.
  void impostaSpot(String nome, String ambiente) {
    final stessoAmbiente = state.ambiente?.toLowerCase() == ambiente.toLowerCase();
    state = state.copyWith(
      spotNome: nome,
      ambiente: ambiente,
      valori: stessoAmbiente ? state.valori : const {},
    );
  }

  void impostaData(DateTime data) =>
      state = state.copyWith(data: DateTime(data.year, data.month, data.day));

  void impostaFascia(FasciaOraria fascia) => state = state.copyWith(fasciaOraria: fascia);

  /// Sceglie [valore] per [condizione]; `null` (o lo stesso valore già
  /// scelto) lascia la condizione non compilata.
  void impostaValore(Condizione condizione, ValoreCondizione? valore) {
    final valori = Map<int, ValoreCondizione>.of(state.valori);
    if (valore == null || valori[condizione.id]?.id == valore.id) {
      valori.remove(condizione.id);
    } else {
      valori[condizione.id!] = valore;
    }
    state = state.copyWith(valori: valori);
  }

  /// Seleziona l'esca se non è selezionata, altrimenti la toglie.
  void alternaEsca(Esca esca) {
    state = state.copyWith(
      esche: state.contieneEsca(esca)
          ? state.esche.where((e) => !_stessaEsca(e, esca)).toList()
          : [...state.esche, esca],
    );
  }

  /// Aggiunge un'esca scritta dall'utente. Se il nome corrisponde a un'esca
  /// del catalogo ([esistenti], senza distinzione di maiuscole e spazi)
  /// seleziona quella invece di crearne un doppione; altrimenti l'esca nuova
  /// verrà creata al salvataggio. Restituisce l'esca selezionata.
  Esca aggiungiEscaNuova(String nome, List<Esca> esistenti) {
    final cercata = Esca(nome: nome.trim());
    final esca = esistenti.firstWhere(
      (e) => _stessaEsca(e, cercata),
      orElse: () => cercata,
    );
    if (!state.contieneEsca(esca)) {
      state = state.copyWith(esche: [...state.esche, esca]);
    }
    return esca;
  }

  void aggiungiCattura() {
    state = state.copyWith(
      catture: [...state.catture, BozzaCattura(chiave: _prossimaChiave++)],
    );
  }

  void rimuoviCattura(int chiave) {
    state = state.copyWith(
      catture: state.catture.where((c) => c.chiave != chiave).toList(),
    );
  }

  /// Cambia la specie di una riga: le caratteristiche sono della specie,
  /// quindi quelle già compilate vengono tolte.
  void impostaSpecie(int chiave, String specieNome) => _modificaCattura(
        chiave,
        (c) => c.specieNome == specieNome
            ? c
            : BozzaCattura(chiave: c.chiave, specieNome: specieNome, totale: c.totale),
      );

  void impostaTotale(int chiave, int totale) =>
      _modificaCattura(chiave, (c) => c.copyWith(totale: totale));

  /// Quante catture della riga hanno [caratteristica]; 0 la toglie.
  void impostaDettaglio(int chiave, Caratteristica caratteristica, int quantita) =>
      _modificaCattura(chiave, (c) {
        final dettagli = Map<Caratteristica, int>.of(c.dettagli);
        if (quantita <= 0) {
          dettagli.remove(caratteristica);
        } else {
          dettagli[caratteristica] = quantita;
        }
        return c.copyWith(dettagli: dettagli);
      });

  void impostaTempAcqua(String testo) => state = state.copyWith(tempAcqua: testo);

  void impostaTempAria(String testo) => state = state.copyWith(tempAria: testo);

  void impostaNote(String testo) => state = state.copyWith(note: testo);

  /// Salva la pescata. Se la bozza non è valida lancia [BozzaNonValida]
  /// con l'elenco dei problemi; gli errori del database arrivano invariati.
  Future<Pescata> salva() async {
    final problemi = state.errori(oggi: ref.read(orologioProvider)());
    if (problemi.isNotEmpty) throw BozzaNonValida(problemi);
    return ref.read(elencoPescateProvider.notifier).salva(state.inPescata());
  }

  void _modificaCattura(int chiave, BozzaCattura Function(BozzaCattura) modifica) {
    state = state.copyWith(
      catture: [
        for (final c in state.catture) c.chiave == chiave ? modifica(c) : c,
      ],
    );
  }
}
