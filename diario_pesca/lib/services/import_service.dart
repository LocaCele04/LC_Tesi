import 'dart:convert';

import '../models/catalogo/caratteristica.dart';
import '../models/catalogo/specie.dart';
import '../models/catalogo/valore_condizione.dart';
import '../models/enums.dart';
import '../models/pescate/pescata.dart';
import '../models/pescate/riepilogo_caratteristica.dart';
import '../models/pescate/riepilogo_specie.dart';
import '../models/territorio/ambiente.dart';
import '../models/territorio/coordinata.dart';
import '../models/territorio/divieto.dart';
import '../models/territorio/spot.dart';
import '../repositories/catalogo_repository.dart';
import '../repositories/pescate_repository.dart';
import '../repositories/territorio_repository.dart';

// Import dei dati da un file JSON preparato fuori dall'app (es. dallo
// storico su foglio di calcolo e dai tratti di Google Earth).
//
// Il file resta sul telefono: viene letto dall'app e non va mai aggiunto
// al repository, perché contiene dati personali.
//
// Formato (versione 1):
//
// {
//   "formato": "diario-pesca-import", "versione": 1,
//   "ambienti": [{"nome": "Torrentino", "condizioniCome": "Torrente"}],
//   "specie": [{"nome": "Trota", "caratteristiche": ["Over 30"]}],
//   "spot": [{"nome", "categoria", "ambiente", "voto"?, "difficolta"?,
//             "noteOstacoli"?, "note"?, "linkParcheggio"?,
//             "lunghezzaMetri"?, "punti": [[lat, lon], ...]}],
//   "divieti": [{"nome", "note"?, "punti": [[lat, lon], ...]}],
//   "pescate": [{"data": "2026-02-22", "fascia": "alba", "spot",
//                "condizioni": {"Meteo": "Sereno"},
//                "catture": [{"specie", "totale", "caratteristiche": {"Over 30": 1}}],
//                "note"?}]
// }

const formatoImport = 'diario-pesca-import';
const versioneImport = 1;

/// Il file non si può importare. [problemi] sono frasi per l'utente.
class ImportNonValido implements Exception {
  const ImportNonValido(this.problemi);
  final List<String> problemi;

  @override
  String toString() => problemi.join('\n');
}

/// L'import si è fermato a metà, dopo aver già salvato una parte dei dati.
class ImportInterrotto implements Exception {
  const ImportInterrotto(this.fase, this.errore);
  final String fase;
  final Object errore;

  @override
  String toString() => 'Import interrotto durante: $fase ($errore)';
}

/// Una cattura di una pescata da importare.
class CatturaDaImportare {
  const CatturaDaImportare({required this.specie, required this.totale, this.caratteristiche = const {}});
  final String specie;
  final int totale;
  final Map<String, int> caratteristiche;
}

/// Una pescata da importare, con riferimenti per nome a spot, condizioni,
/// specie e caratteristiche (gli id esistono solo dopo il salvataggio).
class PescataDaImportare {
  const PescataDaImportare({
    required this.data,
    required this.fascia,
    required this.spot,
    this.condizioni = const {},
    this.catture = const [],
    this.note,
  });
  final DateTime data;
  final FasciaOraria fascia;
  final String spot;
  final Map<String, String> condizioni;
  final List<CatturaDaImportare> catture;
  final String? note;
}

/// Contenuto di un file già letto e controllato, pronto per l'import.
class DatiImport {
  const DatiImport({
    required this.ambienti,
    required this.specie,
    required this.spot,
    required this.divieti,
    required this.pescate,
  });

  /// Ambienti nuovi e da quale ambiente copiano le condizioni.
  final List<({String nome, String? condizioniCome})> ambienti;
  final Map<String, List<String>> specie;
  final List<Spot> spot;
  final List<Divieto> divieti;
  final List<PescataDaImportare> pescate;

  int get spotConTratto => spot.where((s) => s.coordinate.isNotEmpty).length;
  int get catture => pescate.fold(0, (n, p) => n + p.catture.fold(0, (m, c) => m + c.totale));
}

/// Quanti elementi sono stati importati.
class EsitoImport {
  const EsitoImport({required this.spot, required this.divieti, required this.pescate});
  final int spot;
  final int divieti;
  final int pescate;
}

/// Avanzamento dell'import: fase in corso e quanti elementi su quanti.
typedef AvanzamentoImport = void Function(String fase, int fatti, int totale);

/// Legge, controlla e importa un file di dati. Funziona solo su un diario
/// vuoto (nessuno spot, divieto o pescata), così non nascono doppioni.
///
/// Il controllo ([leggi]) è completo e non scrive nulla; l'import ([importa])
/// usa i repository, ognuno con le sue transazioni. Se si ferma a metà per
/// un errore imprevisto lancia [ImportInterrotto]: i dati già salvati
/// restano e conviene ripartire da un diario vuoto.
class ImportService {
  ImportService({
    required TerritorioRepository territorio,
    required CatalogoRepository catalogo,
    required PescateRepository pescate,
  })  : _territorio = territorio,
        _catalogo = catalogo,
        _pescate = pescate;

  final TerritorioRepository _territorio;
  final CatalogoRepository _catalogo;
  final PescateRepository _pescate;

  /// Legge [testo] (il contenuto del file) e controlla tutto ciò che si può
  /// controllare prima di scrivere. Lancia [ImportNonValido] con l'elenco
  /// dei problemi (al massimo i primi 30).
  Future<DatiImport> leggi(String testo) async {
    final problemi = <String>[];

    Object? json;
    try {
      json = jsonDecode(testo);
    } on FormatException {
      throw const ImportNonValido(['Il file non è un JSON valido.']);
    }
    if (json is! Map<String, Object?> || json['formato'] != formatoImport) {
      throw const ImportNonValido(['Il file non è un file di import del Diario di pesca.']);
    }
    if (json['versione'] != versioneImport) {
      throw ImportNonValido(['Versione del file ${json['versione']} non supportata (attesa $versioneImport).']);
    }

    if ((await _territorio.getSpots()).isNotEmpty ||
        (await _territorio.getDivieti()).isNotEmpty ||
        (await _pescate.getPescate()).isNotEmpty) {
      problemi.add('Il diario non è vuoto: l\'import si può fare solo su un diario nuovo.');
    }

    List<Map<String, Object?>> elenco(String chiave) {
      final v = json is Map<String, Object?> ? json[chiave] : null;
      if (v == null) return const [];
      if (v is! List) {
        problemi.add('"$chiave" deve essere un elenco.');
        return const [];
      }
      return [for (final e in v) if (e is Map<String, Object?>) e];
    }

    String? testoOpz(Map<String, Object?> m, String k) {
      final v = m[k];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    List<Coordinata> punti(Object? v, String dove) {
      if (v == null) return const [];
      final risultato = <Coordinata>[];
      if (v is List) {
        for (final p in v) {
          if (p is List && p.length == 2 && p[0] is num && p[1] is num) {
            final lat = (p[0] as num).toDouble();
            final lon = (p[1] as num).toDouble();
            if (lat.abs() <= 90 && lon.abs() <= 180) {
              risultato.add(Coordinata(ordine: risultato.length, latitudine: lat, longitudine: lon));
              continue;
            }
          }
          problemi.add('$dove: punto non valido ($p).');
        }
      }
      return risultato;
    }

    // Ambienti: quelli già presenti più i nuovi del file.
    final ambientiNoti = {for (final a in await _territorio.getAmbienti()) a.nome.toLowerCase()};
    final ambienti = <({String nome, String? condizioniCome})>[];
    for (final a in elenco('ambienti')) {
      final nome = testoOpz(a, 'nome');
      final come = testoOpz(a, 'condizioniCome');
      if (nome == null) {
        problemi.add('Un ambiente non ha il nome.');
        continue;
      }
      if (come != null && !ambientiNoti.contains(come.toLowerCase())) {
        problemi.add('Ambiente $nome: l\'ambiente "$come" da cui copiare le condizioni non esiste.');
      }
      if (ambientiNoti.add(nome.toLowerCase())) ambienti.add((nome: nome, condizioniCome: come));
    }

    // Specie e caratteristiche dichiarate.
    final specie = <String, List<String>>{};
    for (final s in elenco('specie')) {
      final nome = testoOpz(s, 'nome');
      if (nome == null) {
        problemi.add('Una specie non ha il nome.');
        continue;
      }
      final car = s['caratteristiche'];
      specie[nome] = [if (car is List) for (final c in car) if (c is String && c.trim().isNotEmpty) c.trim()];
    }

    // Spot.
    final spot = <Spot>[];
    final nomiSpot = <String, String>{};
    for (final s in elenco('spot')) {
      final nome = testoOpz(s, 'nome');
      final categoria = testoOpz(s, 'categoria');
      final ambiente = testoOpz(s, 'ambiente');
      if (nome == null || categoria == null || ambiente == null) {
        problemi.add('Spot ${nome ?? '(senza nome)'}: servono nome, categoria e ambiente.');
        continue;
      }
      if (nomiSpot.containsKey(nome.toLowerCase())) {
        problemi.add('Spot "$nome" ripetuto.');
        continue;
      }
      if (!ambientiNoti.contains(ambiente.toLowerCase())) {
        problemi.add('Spot $nome: ambiente "$ambiente" sconosciuto.');
      }
      final voto = s['voto'];
      if (voto != null && (voto is! num || voto < 0 || voto > 10)) {
        problemi.add('Spot $nome: voto non valido ($voto).');
      }
      final difficolta = testoOpz(s, 'difficolta');
      final diff = Difficolta.values.where((d) => d.name == difficolta).firstOrNull;
      if (difficolta != null && diff == null) problemi.add('Spot $nome: difficoltà "$difficolta" non valida.');
      final lunghezza = s['lunghezzaMetri'];
      nomiSpot[nome.toLowerCase()] = nome;
      spot.add(Spot(
        nome: nome,
        categoriaNome: categoria,
        ambiente: ambiente,
        voto: voto is num ? voto.toDouble() : null,
        difficolta: diff,
        noteOstacoli: testoOpz(s, 'noteOstacoli'),
        note: testoOpz(s, 'note'),
        linkParcheggio: testoOpz(s, 'linkParcheggio'),
        lunghezzaMetri: lunghezza is num && lunghezza > 0 ? lunghezza.toDouble() : null,
        coordinate: punti(s['punti'], 'Spot $nome'),
      ));
    }

    // Divieti.
    final divieti = <Divieto>[];
    for (final d in elenco('divieti')) {
      final nome = testoOpz(d, 'nome');
      final p = punti(d['punti'], 'Divieto ${nome ?? ''}');
      if (nome == null || p.isEmpty) {
        problemi.add('Divieto ${nome ?? '(senza nome)'}: servono il nome e almeno un punto.');
        continue;
      }
      divieti.add(Divieto(nome: nome, note: testoOpz(d, 'note'), coordinate: p));
    }

    // Pescate.
    final condizioni = {
      for (final c in await _catalogo.getCondizioni())
        c.nome.toLowerCase(): {for (final v in c.valori) v.nome.toLowerCase()},
    };
    final pescate = <PescataDaImportare>[];
    var indice = 0;
    for (final p in elenco('pescate')) {
      indice++;
      final dove = 'Pescata $indice${p['data'] is String ? ' (${p['data']})' : ''}';
      final data = p['data'] is String ? DateTime.tryParse(p['data'] as String) : null;
      final fascia = FasciaOraria.values.where((f) => f.name == p['fascia']).firstOrNull;
      final nomeSpot = nomiSpot[(testoOpz(p, 'spot') ?? '').toLowerCase()];
      if (data == null) problemi.add('$dove: data non valida.');
      if (fascia == null) problemi.add('$dove: fascia oraria "${p['fascia']}" non valida.');
      if (nomeSpot == null) problemi.add('$dove: lo spot "${p['spot']}" non è nel file.');

      final cond = <String, String>{};
      final c = p['condizioni'];
      if (c is Map) {
        for (final e in c.entries) {
          final valori = condizioni[e.key.toString().toLowerCase()];
          if (valori == null) {
            problemi.add('$dove: condizione "${e.key}" inesistente.');
          } else if (!valori.contains(e.value.toString().toLowerCase())) {
            problemi.add('$dove: valore "${e.value}" inesistente per ${e.key}.');
          } else {
            cond[e.key.toString()] = e.value.toString();
          }
        }
      }

      final catture = <CatturaDaImportare>[];
      final elencoCatture = p['catture'];
      if (elencoCatture is List) {
        for (final ct in elencoCatture.whereType<Map<String, Object?>>()) {
          final sp = testoOpz(ct, 'specie');
          final totale = ct['totale'];
          if (sp == null || !specie.containsKey(sp)) {
            problemi.add('$dove: specie "$sp" non dichiarata.');
            continue;
          }
          if (totale is! int || totale < 1) {
            problemi.add('$dove: totale delle catture non valido ($totale).');
            continue;
          }
          final car = <String, int>{};
          final dettagli = ct['caratteristiche'];
          if (dettagli is Map) {
            for (final e in dettagli.entries) {
              if (!specie[sp]!.contains(e.key)) {
                problemi.add('$dove: caratteristica "${e.key}" non dichiarata per $sp.');
              } else if (e.value is! int || (e.value as int) < 0) {
                problemi.add('$dove: quantità non valida per ${e.key}.');
              } else if (e.value as int > 0) {
                car[e.key.toString()] = e.value as int;
              }
            }
          }
          if (car.values.fold(0, (a, b) => a + b) > totale) {
            problemi.add('$dove: le caratteristiche contano più catture del totale ($totale).');
          }
          catture.add(CatturaDaImportare(specie: sp, totale: totale, caratteristiche: car));
        }
      }

      if (data != null && fascia != null && nomeSpot != null) {
        pescate.add(PescataDaImportare(
          data: DateTime(data.year, data.month, data.day),
          fascia: fascia,
          spot: nomeSpot,
          condizioni: cond,
          catture: catture,
          note: testoOpz(p, 'note'),
        ));
      }
    }

    if (problemi.isNotEmpty) {
      throw ImportNonValido([
        ...problemi.take(30),
        if (problemi.length > 30) '…e altri ${problemi.length - 30} problemi.',
      ]);
    }
    return DatiImport(ambienti: ambienti, specie: specie, spot: spot, divieti: divieti, pescate: pescate);
  }

  /// Salva i [dati] letti da [leggi]: ambienti, specie e caratteristiche,
  /// spot (con le categorie), divieti e infine le pescate, che rendono gli
  /// spot *battuti*. Il meteo delle pescate resta da scaricare.
  Future<EsitoImport> importa(DatiImport dati, {AvanzamentoImport? avanzamento}) async {
    var fase = 'ambienti';
    try {
      for (final a in dati.ambienti) {
        await _territorio.inserisciAmbiente(Ambiente(nome: a.nome));
        if (a.condizioniCome != null) {
          await _catalogo.copiaCondizioniAmbiente(daAmbiente: a.condizioniCome!, aAmbiente: a.nome);
        }
      }

      fase = 'specie';
      final specieEsistenti = {for (final s in await _catalogo.getSpecie()) s.nome.toLowerCase()};
      final caratteristiche = <String, Caratteristica>{};
      for (final e in dati.specie.entries) {
        if (!specieEsistenti.contains(e.key.toLowerCase())) {
          await _catalogo.inserisciSpecie(Specie(nome: e.key));
        }
        for (final nome in e.value) {
          caratteristiche['${e.key}|$nome'] =
              await _catalogo.getCaratteristicaPerNome(specieNome: e.key, nome: nome) ??
                  await _catalogo.salvaCaratteristica(Caratteristica(specieNome: e.key, nome: nome));
        }
      }

      fase = 'spot';
      for (var i = 0; i < dati.spot.length; i++) {
        avanzamento?.call('Spot', i, dati.spot.length);
        await _territorio.salvaSpotConCoordinate(dati.spot[i]);
      }

      fase = 'divieti';
      for (var i = 0; i < dati.divieti.length; i++) {
        avanzamento?.call('Divieti', i, dati.divieti.length);
        await _territorio.salvaDivieto(dati.divieti[i]);
      }

      fase = 'pescate';
      // Valori delle condizioni per nome, con i loro id.
      final valori = <String, ValoreCondizione>{};
      for (final c in await _catalogo.getCondizioni()) {
        for (final v in c.valori) {
          valori['${c.nome.toLowerCase()}|${v.nome.toLowerCase()}'] = v;
        }
      }
      for (var i = 0; i < dati.pescate.length; i++) {
        avanzamento?.call('Pescate', i, dati.pescate.length);
        final p = dati.pescate[i];
        await _pescate.salvaPescata(Pescata(
          data: p.data,
          fasciaOraria: p.fascia,
          spotNome: p.spot,
          note: p.note,
          valoriCondizioni: [
            for (final e in p.condizioni.entries)
              valori['${e.key.toLowerCase()}|${e.value.toLowerCase()}']!,
          ],
          riepiloghiSpecie: [
            for (final c in p.catture)
              RiepilogoSpecie(
                specieNome: c.specie,
                quantita: c.totale,
                dettagli: [
                  for (final e in c.caratteristiche.entries)
                    RiepilogoCaratteristica(
                      caratteristica: caratteristiche['${c.specie}|${e.key}']!,
                      quantita: e.value,
                    ),
                ],
              ),
          ],
        ));
      }
      avanzamento?.call('Pescate', dati.pescate.length, dati.pescate.length);
    } catch (e) {
      throw ImportInterrotto(fase, e);
    }
    return EsitoImport(spot: dati.spot.length, divieti: dati.divieti.length, pescate: dati.pescate.length);
  }
}
