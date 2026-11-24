import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalogo/condizione.dart';
import '../../models/enums.dart';
import '../../models/territorio/categoria.dart';
import '../../models/territorio/coordinata.dart';
import '../../models/territorio/spot.dart';
import '../../repositories/territorio_repository.dart';
import 'bozza_non_valida.dart';
import 'catalogo_state.dart';
import 'dipendenze.dart';
import 'spot_state.dart';

export 'bozza_non_valida.dart';

/// Contenuto del modulo dello spot mentre l'utente lo compila: uno spot
/// nuovo ([nomeOriginale] nullo) o la modifica di uno esistente.
///
/// Voto e lunghezza restano testo finché non si salva, come le temperature
/// della pescata.
class BozzaSpot {
  /// Nome dello spot prima della modifica; `null` per uno spot nuovo.
  final String? nomeOriginale;

  /// Ambiente dello spot prima della modifica, per capire se è cambiato.
  final String? ambienteOriginale;
  final String nome;
  final String? ambiente;
  final String? categoriaNome;

  /// Categoria scritta al momento e non ancora salvata: nasce solo salvando
  /// lo spot, come le esche e le specie nuove nel modulo della pescata.
  final String? nuovaCategoria;
  final Difficolta? difficolta;
  final Accessibilita accessibilita;
  final String voto;

  /// Lunghezza scritta a mano: vale solo con meno di due punti, altrimenti
  /// la calcola il repository dalle coordinate.
  final String lunghezza;
  final String noteOstacoli;
  final String note;
  final String linkParcheggio;

  /// Punti del tratto, nell'ordine; il primo è quello usato per il meteo.
  final List<Coordinata> coordinate;

  const BozzaSpot({
    this.nomeOriginale,
    this.ambienteOriginale,
    this.nome = '',
    this.ambiente,
    this.categoriaNome,
    this.nuovaCategoria,
    this.difficolta,
    this.accessibilita = Accessibilita.accessibile,
    this.voto = '',
    this.lunghezza = '',
    this.noteOstacoli = '',
    this.note = '',
    this.linkParcheggio = '',
    this.coordinate = const [],
  });

  /// Bozza per modificare [spot] (con le sue coordinate).
  factory BozzaSpot.da(Spot spot) => BozzaSpot(
        nomeOriginale: spot.nome,
        ambienteOriginale: spot.ambiente,
        nome: spot.nome,
        ambiente: spot.ambiente,
        categoriaNome: spot.categoriaNome,
        difficolta: spot.difficolta,
        accessibilita: spot.accessibilita,
        voto: _testo(spot.voto),
        lunghezza: spot.coordinate.length >= 2 ? '' : _testo(spot.lunghezzaMetri),
        noteOstacoli: spot.noteOstacoli ?? '',
        note: spot.note ?? '',
        linkParcheggio: spot.linkParcheggio ?? '',
        coordinate: spot.coordinate,
      );

  bool get isNuovo => nomeOriginale == null;

  /// Riassunto di tutto ciò che il salvataggio scriverebbe: due bozze con la
  /// stessa firma salvano lo stesso spot. Serve a capire se l'utente ha
  /// modificato qualcosa (un testo scritto e poi cancellato non conta).
  String get firma => [
        nome.trim(),
        ambiente ?? '',
        categoriaNome ?? '',
        difficolta?.name ?? '',
        accessibilita.name,
        voto.trim(),
        coordinate.length < 2 ? lunghezza.trim() : '',
        noteOstacoli.trim(),
        note.trim(),
        linkParcheggio.trim(),
        for (final c in coordinate) '${c.latitudine},${c.longitudine}',
      ].join('\u0001');

  /// `true` se si sta modificando uno spot e il suo ambiente è cambiato.
  bool get ambienteCambiato =>
      !isNuovo &&
      ambiente != null &&
      ambiente!.toLowerCase() != ambienteOriginale?.toLowerCase();

  /// Lunghezza calcolata dai punti (metri), `null` con meno di due punti.
  double? get lunghezzaCalcolata => TerritorioRepository.calcolaLunghezzaMetri(coordinate);

  BozzaSpot copyWith({
    String? nome,
    String? ambiente,
    String? categoriaNome,
    String? nuovaCategoria,
    bool togliNuovaCategoria = false,
    Difficolta? difficolta,
    bool togliDifficolta = false,
    Accessibilita? accessibilita,
    String? voto,
    String? lunghezza,
    String? noteOstacoli,
    String? note,
    String? linkParcheggio,
    List<Coordinata>? coordinate,
  }) {
    return BozzaSpot(
      nomeOriginale: nomeOriginale,
      ambienteOriginale: ambienteOriginale,
      nome: nome ?? this.nome,
      ambiente: ambiente ?? this.ambiente,
      categoriaNome: categoriaNome ?? this.categoriaNome,
      nuovaCategoria: togliNuovaCategoria ? null : (nuovaCategoria ?? this.nuovaCategoria),
      difficolta: togliDifficolta ? null : (difficolta ?? this.difficolta),
      accessibilita: accessibilita ?? this.accessibilita,
      voto: voto ?? this.voto,
      lunghezza: lunghezza ?? this.lunghezza,
      noteOstacoli: noteOstacoli ?? this.noteOstacoli,
      note: note ?? this.note,
      linkParcheggio: linkParcheggio ?? this.linkParcheggio,
      coordinate: coordinate ?? this.coordinate,
    );
  }

  /// Problemi che impediscono il salvataggio, in parole per l'utente.
  /// [nomiEsistenti] sono i nomi degli spot già salvati.
  List<String> errori(Iterable<String> nomiEsistenti) {
    final problemi = <String>[];
    final nomePulito = nome.trim();
    if (nomePulito.isEmpty) {
      problemi.add('Scrivi il nome dello spot.');
    } else {
      final cambiato = nomePulito.toLowerCase() != nomeOriginale?.toLowerCase();
      final usato = nomiEsistenti.any((n) => n.toLowerCase() == nomePulito.toLowerCase());
      if (cambiato && usato) problemi.add('Esiste già uno spot chiamato "$nomePulito".');
    }
    if (categoriaNome == null) problemi.add('Scegli la categoria.');
    if (ambiente == null) problemi.add('Scegli l\'ambiente.');

    if (voto.trim().isNotEmpty) {
      final v = _numero(voto);
      if (v == null || v < 0 || v > 10) problemi.add('Il voto deve essere un numero tra 0 e 10.');
    }
    if (coordinate.length < 2 && lunghezza.trim().isNotEmpty) {
      final l = _numero(lunghezza);
      if (l == null || l <= 0) problemi.add('La lunghezza deve essere un numero di metri maggiore di 0.');
    }
    return problemi;
  }

  /// Spot da salvare. Da chiamare solo se [errori] è vuoto.
  Spot inSpot() {
    String? facoltativo(String testo) => testo.trim().isEmpty ? null : testo.trim();
    return Spot(
      nome: nome.trim(),
      ambiente: ambiente!,
      categoriaNome: categoriaNome!,
      difficolta: difficolta,
      accessibilita: accessibilita,
      voto: _numero(voto),
      lunghezzaMetri: coordinate.length >= 2 ? null : _numero(lunghezza),
      noteOstacoli: facoltativo(noteOstacoli),
      note: facoltativo(note),
      linkParcheggio: facoltativo(linkParcheggio),
      coordinate: [
        for (var i = 0; i < coordinate.length; i++) coordinate[i].copyWith(ordine: i),
      ],
    );
  }

  static String _testo(double? valore) {
    if (valore == null) return '';
    return valore == valore.roundToDouble() ? '${valore.round()}' : '$valore';
  }

  static double? _numero(String testo) {
    final pulito = testo.trim().replaceAll(',', '.');
    return pulito.isEmpty ? null : double.tryParse(pulito);
  }
}

/// Legge un punto scritto o incollato dall'utente. Accetta:
/// * due numeri: `45.7612, 9.6401`, `45.7612 9.6401`, `45,7612; 9,6401`
///   e anche `45,7612, 9,6401` (virgola decimale);
/// * gradi, primi e secondi come li mostra Google Maps:
///   `45°40'02.5"N 9°35'18.3"E`;
/// * un link di Google Maps completo (`...!3d45.66!4d9.58...` o `@45.66,9.58,17z`).
///
/// Restituisce `null` se il testo non contiene un punto valido.
/// I link brevi (`maps.app.goo.gl/...`) non contengono le coordinate: vanno
/// aperti e si copia il punto dalla mappa.
Coordinata? leggiCoordinata(String testo) {
  final t = testo.trim();
  if (t.isEmpty) return null;

  (double, double)? coppia;
  final pin = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)').firstMatch(t);
  final vista = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(t);
  final gms = RegExp(
    r'''(\d+)°\s*(\d+)['′]\s*(\d+(?:[.,]\d+)?)["″]?\s*([NS])\s*,?\s*(\d+)°\s*(\d+)['′]\s*(\d+(?:[.,]\d+)?)["″]?\s*([EOW])''',
    caseSensitive: false,
  ).firstMatch(t);

  if (pin != null) {
    coppia = (double.parse(pin.group(1)!), double.parse(pin.group(2)!));
  } else if (vista != null) {
    coppia = (double.parse(vista.group(1)!), double.parse(vista.group(2)!));
  } else if (gms != null) {
    double gradi(int g) {
      final valore = double.parse(gms.group(g)!) +
          double.parse(gms.group(g + 1)!) / 60 +
          double.parse(gms.group(g + 2)!.replaceAll(',', '.')) / 3600;
      final emisfero = gms.group(g + 3)!.toUpperCase();
      return emisfero == 'S' || emisfero == 'W' || emisfero == 'O' ? -valore : valore;
    }

    coppia = (gradi(1), gradi(5));
  } else if (t.contains(';')) {
    final parti = t.split(';');
    if (parti.length == 2) {
      final a = double.tryParse(parti[0].trim().replaceAll(',', '.'));
      final b = double.tryParse(parti[1].trim().replaceAll(',', '.'));
      if (a != null && b != null) coppia = (a, b);
    }
  } else {
    final numeri = RegExp(r'-?\d+(?:\.\d+)?').allMatches(t).map((m) => m.group(0)!).toList();
    final soloNumeri = RegExp(r'^[\s\d.,\-]+$').hasMatch(t);
    if (soloNumeri && numeri.length == 2) {
      coppia = (double.parse(numeri[0]), double.parse(numeri[1]));
    } else if (soloNumeri && numeri.length == 4 && !t.contains('.')) {
      // "45,7612, 9,6401": virgola decimale e virgola come separatore
      coppia = (
        double.parse('${numeri[0]}.${numeri[1]}'),
        double.parse('${numeri[2]}.${numeri[3]}'),
      );
    }
  }

  if (coppia == null) return null;
  final (lat, lon) = coppia;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return Coordinata(ordine: 0, latitudine: lat, longitudine: lon);
}

/// Stato del modulo dello spot: `spotIniziale` nullo per uno spot nuovo,
/// altrimenti lo spot da modificare (con le coordinate). `autoDispose`:
/// chiudendo la schermata la bozza viene scartata.
final moduloSpotProvider =
    NotifierProvider.autoDispose.family<ModuloSpotNotifier, BozzaSpot, Spot?>(
  ModuloSpotNotifier.new,
);

class ModuloSpotNotifier extends Notifier<BozzaSpot> {
  ModuloSpotNotifier(this.spotIniziale);

  final Spot? spotIniziale;

  /// Firma della bozza all'apertura, per sapere se ci sono modifiche.
  String _firmaIniziale = '';

  @override
  BozzaSpot build() {
    final bozza = spotIniziale == null ? const BozzaSpot() : BozzaSpot.da(spotIniziale!);
    _firmaIniziale = bozza.firma;
    return bozza;
  }

  /// `true` se la bozza è diversa da com'era all'apertura: uscendo senza
  /// salvare le modifiche andrebbero perse.
  bool get modificato => state.firma != _firmaIniziale;

  void impostaNome(String testo) => state = state.copyWith(nome: testo);
  void impostaAmbiente(String ambiente) => state = state.copyWith(ambiente: ambiente);
  /// Sceglie una categoria; se era stata scritta una categoria nuova e se ne
  /// sceglie un'altra, quella nuova viene scartata.
  void impostaCategoria(String categoria) => state = state.copyWith(
        categoriaNome: categoria,
        togliNuovaCategoria: categoria != state.nuovaCategoria,
      );

  /// Categoria scritta al momento. Se corrisponde a una del [catalogo]
  /// (senza distinzione di maiuscole e spazi) sceglie quella; altrimenti la
  /// categoria è *nuova* e nasce solo salvando lo spot. Restituisce il nome
  /// scelto.
  String aggiungiCategoriaNuova(String nome, List<Categoria> catalogo) {
    final pulito = nome.trim();
    for (final c in catalogo) {
      if (c.nome.toLowerCase() == pulito.toLowerCase()) {
        impostaCategoria(c.nome);
        return c.nome;
      }
    }
    state = state.copyWith(categoriaNome: pulito, nuovaCategoria: pulito);
    return pulito;
  }

  /// Categoria nuova (non ancora salvata) che verrebbe scartata scegliendo
  /// [altra]; `null` se non si scarta nulla. Serve a chiedere conferma.
  String? categoriaScartata(String altra) {
    final nuova = state.nuovaCategoria;
    return nuova != null && nuova != altra ? nuova : null;
  }

  /// Sceglie la difficoltà; scegliere di nuovo la stessa la toglie.
  void impostaDifficolta(Difficolta difficolta) => state = state.difficolta == difficolta
      ? state.copyWith(togliDifficolta: true)
      : state.copyWith(difficolta: difficolta);

  void impostaAccessibile(bool accessibile) => state = state.copyWith(
        accessibilita: accessibile ? Accessibilita.accessibile : Accessibilita.inaccessibile,
      );

  void impostaVoto(String testo) => state = state.copyWith(voto: testo);
  void impostaLunghezza(String testo) => state = state.copyWith(lunghezza: testo);
  void impostaNoteOstacoli(String testo) => state = state.copyWith(noteOstacoli: testo);
  void impostaNote(String testo) => state = state.copyWith(note: testo);
  void impostaLinkParcheggio(String testo) => state = state.copyWith(linkParcheggio: testo);

  /// Aggiunge in fondo al tratto il punto scritto in [testo] (vedi
  /// [leggiCoordinata]). Restituisce `false` se il testo non è un punto.
  bool aggiungiPunto(String testo) {
    final punto = leggiCoordinata(testo);
    if (punto == null) return false;
    state = state.copyWith(coordinate: [...state.coordinate, punto]);
    return true;
  }

  /// Sostituisce tutti i punti del tratto (es. con quelli disegnati sulla
  /// mappa).
  void impostaPunti(List<Coordinata> punti) {
    state = state.copyWith(coordinate: [
      for (var i = 0; i < punti.length; i++) punti[i].copyWith(ordine: i),
    ]);
  }

  void rimuoviPunto(int indice) {
    final punti = [...state.coordinate]..removeAt(indice);
    state = state.copyWith(coordinate: punti);
  }

  /// Sposta il punto [indice] di una posizione (−1 in su, +1 in giù).
  void spostaPunto(int indice, int verso) {
    final nuovo = indice + verso;
    if (nuovo < 0 || nuovo >= state.coordinate.length) return;
    final punti = [...state.coordinate];
    final punto = punti.removeAt(indice);
    punti.insert(nuovo, punto);
    state = state.copyWith(coordinate: punti);
  }

  /// Condizioni usate nelle pescate dello spot ma non previste per il nuovo
  /// ambiente: da proporre all'utente prima di salvare un cambio d'ambiente.
  /// Vuoto se l'ambiente non è cambiato.
  Future<List<Condizione>> condizioniDaCollegare() async {
    if (!state.ambienteCambiato) return const [];
    return ref.read(territorioRepositoryProvider).getCondizioniNonPreviste(
          spotNome: state.nomeOriginale!,
          ambienteNome: state.ambiente!,
        );
  }

  /// Salva lo spot. Se la bozza non è valida lancia [BozzaNonValida].
  /// Con [collega] le condizioni indicate vengono collegate al nuovo
  /// ambiente, così restano nel modulo delle pescate di quello spot.
  Future<Spot> salva({List<Condizione> collega = const []}) async {
    final esistenti = await ref.read(elencoSpotProvider.future);
    final problemi = state.errori(esistenti.map((s) => s.nome));
    if (problemi.isNotEmpty) throw BozzaNonValida(problemi);

    final spot = state.inSpot();
    if (collega.isNotEmpty) {
      final catalogo = ref.read(catalogoRepositoryProvider);
      final previste = await catalogo.getCondizioni(ambienteNome: spot.ambiente);
      await catalogo.impostaCondizioniAmbiente(spot.ambiente, [
        for (final c in previste) c.id!,
        for (final c in collega) c.id!,
      ]);
      ref.invalidate(condizioniPerFormProvider);
    }
    await ref.read(elencoSpotProvider.notifier).salva(spot, nomeOriginale: state.nomeOriginale);
    return spot;
  }

  /// Elimina lo spot che si sta modificando; le sue pescate restano, senza spot.
  Future<void> elimina() async {
    final nome = state.nomeOriginale;
    if (nome == null) return;
    await ref.read(elencoSpotProvider.notifier).elimina(nome);
  }
}
