import '../models/catalogo/caratteristica.dart';
import '../models/catalogo/condizione.dart';
import '../models/catalogo/esca.dart';
import '../models/catalogo/specie.dart';
import '../models/catalogo/valore_condizione.dart';
import '../models/enums.dart';
import '../models/foto.dart';
import '../models/meteo/cella_meteo.dart';
import '../models/meteo/meteo_giorno.dart';
import '../models/meteo/meteo_ora.dart';
import '../models/obiettivi/obiettivo.dart';
import '../models/pescate/cattura_memorabile.dart';
import '../models/pescate/pescata.dart';
import '../models/pescate/pianificazione.dart';
import '../models/pescate/riepilogo_caratteristica.dart';
import '../models/pescate/riepilogo_specie.dart';
import '../models/territorio/ambiente.dart';
import '../models/territorio/categoria.dart';
import '../models/territorio/coordinata.dart';
import '../models/territorio/spot.dart';

class DbMappers {
  static String formatData(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final g = d.day.toString().padLeft(2, '0');
    return '$y-$m-$g';
  }

  /// Ora in UTC nel formato di `MeteoOrario.data_ora` (es. `2026-11-10T05:00`).
  /// Si salva in UTC perché in ora locale il cambio dell'ora legale
  /// produrrebbe ore mancanti o ripetute.
  static String formatDataOra(DateTime d) {
    final u = d.toUtc();
    final h = u.hour.toString().padLeft(2, '0');
    return '${formatData(u)}T$h:00';
  }

  static double? _reale(Object? v) => (v as num?)?.toDouble();

  // --- TERRITORIO ---

  static Categoria categoriaFromMap(Map<String, Object?> map) => Categoria(
        nome: map['nome'] as String,
        note: map['note'] as String?,
      );

  static Map<String, Object?> categoriaToMap(Categoria c) => {
        'nome': c.nome,
        'note': c.note,
      };

  static Ambiente ambienteFromMap(Map<String, Object?> map) => Ambiente(
        nome: map['nome'] as String,
      );

  static Map<String, Object?> ambienteToMap(Ambiente a) => {
        'nome': a.nome,
      };

  static Condizione condizioneFromMap(
    Map<String, Object?> map, {
    List<ValoreCondizione> valori = const [],
  }) =>
      Condizione(
        id: map['id'] as int?,
        nome: map['nome'] as String,
        ordine: map['ordine'] as int,
        attiva: (map['attiva'] as int) == 1,
        valori: valori,
      );

  static Map<String, Object?> condizioneToMap(Condizione c) => {
        if (c.id != null) 'id': c.id,
        'nome': c.nome,
        'ordine': c.ordine,
        'attiva': c.attiva ? 1 : 0,
      };

  static ValoreCondizione valoreCondizioneFromMap(Map<String, Object?> map) =>
      ValoreCondizione(
        id: map['id'] as int?,
        condizioneId: map['condizione_id'] as int,
        nome: map['nome'] as String,
        ordine: map['ordine'] as int,
        attivo: (map['attivo'] as int) == 1,
      );

  static Map<String, Object?> valoreCondizioneToMap(ValoreCondizione v) => {
        if (v.id != null) 'id': v.id,
        'condizione_id': v.condizioneId,
        'nome': v.nome,
        'ordine': v.ordine,
        'attivo': v.attivo ? 1 : 0,
      };

  static Coordinata coordinataFromMap(Map<String, Object?> map) => Coordinata(
        spotNome: map['spot_nome'] as String,
        ordine: map['ordine'] as int,
        latitudine: (map['latitudine'] as num).toDouble(),
        longitudine: (map['longitudine'] as num).toDouble(),
      );

  static Map<String, Object?> coordinataToMap(Coordinata c) => {
        'spot_nome': c.spotNome,
        'ordine': c.ordine,
        'latitudine': c.latitudine,
        'longitudine': c.longitudine,
      };

  static Spot spotFromMap(
    Map<String, Object?> map, {
    List<Coordinata> coordinate = const [],
  }) {
    final difficoltaRaw = map['difficolta'] as String?;
    return Spot(
      nome: map['nome'] as String,
      ambiente: map['ambiente'] as String,
      lunghezzaMetri: (map['lunghezzaMetri'] as num?)?.toDouble(),
      voto: (map['voto'] as num?)?.toDouble(),
      difficolta: difficoltaRaw != null
          ? Difficolta.values.byName(difficoltaRaw)
          : null,
      esposizioneSole: map['esposizioneSole'] as String?,
      noteOstacoli: map['noteOstacoli'] as String?,
      note: map['note'] as String?,
      battuto: (map['battuto'] as int) == 1,
      accessibilita:
          Accessibilita.values.byName(map['accessibilita'] as String),
      linkParcheggio: map['linkParcheggio'] as String?,
      categoriaNome: map['categoria_nome'] as String,
      coordinate: coordinate,
    );
  }

  static Map<String, Object?> spotToMap(Spot s) => {
        'nome': s.nome,
        'ambiente': s.ambiente,
        'lunghezzaMetri': s.lunghezzaMetri,
        'voto': s.voto,
        'difficolta': s.difficolta?.name,
        'esposizioneSole': s.esposizioneSole,
        'noteOstacoli': s.noteOstacoli,
        'note': s.note,
        'battuto': s.battuto ? 1 : 0,
        'accessibilita': s.accessibilita.name,
        'linkParcheggio': s.linkParcheggio,
        'categoria_nome': s.categoriaNome,
      };

  // --- BATTUTE ---

  static Esca escaFromMap(
    Map<String, Object?> map, {
    List<Foto> foto = const [],
  }) {
    return Esca(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      descrizione: map['descrizione'] as String?,
      foto: foto,
    );
  }

  static Map<String, Object?> escaToMap(Esca esca) {
    return {
      if (esca.id != null) 'id': esca.id,
      'nome': esca.nome,
      'descrizione': esca.descrizione,
    };
  }


  static Foto fotoFromMap(Map<String, Object?> map) {
    return Foto(
      id: map['id'] as int?,
      percorso: map['percorso'] as String,
      percorsoThumbnail: map['percorsoThumbnail'] as String,
      pescataId: map['pescata_id'] as int?,
      catturaMemorabileId: map['cattura_memorabile_id'] as int?,
      escaId: map['esca_id'] as int?,
    );
  }

  static Map<String, Object?> fotoToMap(Foto foto) {
    return {
      if (foto.id != null) 'id': foto.id,
      'percorso': foto.percorso,
      'percorsoThumbnail': foto.percorsoThumbnail,
      'pescata_id': foto.pescataId,
      'cattura_memorabile_id': foto.catturaMemorabileId,
      'esca_id': foto.escaId,
    };
  }

  static Pianificazione pianificazioneFromMap(Map<String, Object?> map) =>
      Pianificazione(
        id: map['id'] as int?,
        data: DateTime.parse(map['data'] as String),
        fasciaOraria:
            FasciaOraria.values.byName(map['fasciaOraria'] as String),
        note: map['note'] as String?,
        spotNome: map['spot_nome'] as String?,
      );

  static Map<String, Object?> pianificazioneToMap(Pianificazione p) => {
        if (p.id != null) 'id': p.id,
        'data': formatData(p.data),
        'fasciaOraria': p.fasciaOraria.name,
        'note': p.note,
        'spot_nome': p.spotNome,
      };

  static CatturaMemorabile catturaFromMap(
    Map<String, Object?> map, {
    Esca? esca,
    List<Caratteristica> caratteristiche = const [],
    List<Foto> foto = const [],
  }) =>
      CatturaMemorabile(
        id: map['id'] as int?,
        descrizione: map['descrizione'] as String?,
        pescataId: map['pescata_id'] as int,
        specieNome: map['specie_nome'] as String,
        esca: esca,
        caratteristiche: caratteristiche,
        foto: foto,
      );

  static Map<String, Object?> catturaToMap(CatturaMemorabile c) => {
        if (c.id != null) 'id': c.id,
        'descrizione': c.descrizione,
        'pescata_id': c.pescataId,
        'specie_nome': c.specieNome,
        'esca_id': c.esca?.id,
      };

  static Pescata pescataFromMap(
    Map<String, Object?> map, {
    List<Esca> esche = const [],
    List<Foto> foto = const [],
    List<CatturaMemorabile> cattureMemorabili = const [],
    List<RiepilogoSpecie> riepiloghiSpecie = const [],
    List<ValoreCondizione> valoriCondizioni = const [],
  }) {
    return Pescata(
      id: map['id'] as int?,
      data: DateTime.parse(map['data'] as String),
      fasciaOraria:
          FasciaOraria.values.byName(map['fasciaOraria'] as String),
      tempAcqua: (map['temp_acqua'] as num?)?.toDouble(),
      tempAria: (map['temp_aria'] as num?)?.toDouble(),
      note: map['note'] as String?,
      spotNome: map['spot_nome'] as String?,
      esche: esche,
      foto: foto,
      cattureMemorabili: cattureMemorabili,
      riepiloghiSpecie: riepiloghiSpecie,
      valoriCondizioni: valoriCondizioni,
    );
  }

  static Map<String, Object?> pescataToMap(Pescata p) => {
        if (p.id != null) 'id': p.id,
        'data': formatData(p.data),
        'fasciaOraria': p.fasciaOraria.name,
        'temp_acqua': p.tempAcqua,
        'temp_aria': p.tempAria,
        'note': p.note,
        'spot_nome': p.spotNome,
      };

  // --- STATISTICHE ---

  static Specie specieFromMap(Map<String, Object?> map) => Specie(
        nome: map['nome'] as String,
        informazioni: map['informazioni'] as String?,
      );

  static Map<String, Object?> specieToMap(Specie s) => {
        'nome': s.nome,
        'informazioni': s.informazioni,
      };

  static Caratteristica caratteristicaFromMap(Map<String, Object?> map) =>
      Caratteristica(
        id: map['id'] as int?,
        specieNome: map['specie_nome'] as String,
        nome: map['nome'] as String,
        descrizione: map['descrizione'] as String?,
      );

  static Map<String, Object?> caratteristicaToMap(Caratteristica c) => {
        if (c.id != null) 'id': c.id,
        'specie_nome': c.specieNome,
        'nome': c.nome,
        'descrizione': c.descrizione,
      };

  static Obiettivo obiettivoFromMap(
    Map<String, Object?> map, {
    Caratteristica? caratteristica,
  }) =>
      Obiettivo(
        id: map['id'] as int?,
        specieNome: map['specie_nome'] as String,
        anno: map['anno'] as int,
        quantita: map['quantita'] as int,
        caratteristica: caratteristica,
      );

  static Map<String, Object?> obiettivoToMap(Obiettivo o) => {
        if (o.id != null) 'id': o.id,
        'specie_nome': o.specieNome,
        'anno': o.anno,
        'quantita': o.quantita,
        'caratteristica_id': o.caratteristica?.id,
      };

  static RiepilogoCaratteristica riepilogoCaratteristicaFromMap(
    Map<String, Object?> map, {
    required Caratteristica caratteristica,
  }) =>
      RiepilogoCaratteristica(
        riepilogoSpecieId: map['riepilogo_specie_id'] as int,
        caratteristica: caratteristica,
        quantita: map['quantita'] as int,
      );

  static Map<String, Object?> riepilogoCaratteristicaToMap(
    RiepilogoCaratteristica d, {
    required String specieNome,
  }) =>
      {
        'riepilogo_specie_id': d.riepilogoSpecieId,
        'caratteristica_id': d.caratteristica.id,
        'specie_nome': specieNome,
        'quantita': d.quantita,
      };

  static RiepilogoSpecie riepilogoSpecieFromMap(
    Map<String, Object?> map, {
    List<RiepilogoCaratteristica> dettagli = const [],
  }) =>
      RiepilogoSpecie(
        id: map['id'] as int?,
        pescataId: map['pescata_id'] as int,
        specieNome: map['specie_nome'] as String,
        quantita: map['quantita'] as int,
        dettagli: dettagli,
      );

  static Map<String, Object?> riepilogoSpecieToMap(RiepilogoSpecie r) => {
        if (r.id != null) 'id': r.id,
        'pescata_id': r.pescataId,
        'specie_nome': r.specieNome,
        'quantita': r.quantita,
      };

  // --- METEO ---

  static CellaMeteo cellaMeteoFromMap(Map<String, Object?> map) => CellaMeteo(
        id: map['id'] as int?,
        latitudine: _reale(map['latitudine'])!,
        longitudine: _reale(map['longitudine'])!,
        elevazione: _reale(map['elevazione']),
      );

  static Map<String, Object?> cellaMeteoToMap(CellaMeteo c) => {
        if (c.id != null) 'id': c.id,
        'latitudine': c.latitudine,
        'longitudine': c.longitudine,
        'elevazione': c.elevazione,
      };

  static MeteoGiorno meteoGiornoFromMap(Map<String, Object?> map) => MeteoGiorno(
        cellaId: map['cella_id'] as int?,
        data: DateTime.parse(map['data'] as String),
        pioggiaMm: _reale(map['pioggia_mm']),
        tempMin: _reale(map['temp_min']),
        tempMax: _reale(map['temp_max']),
        pressioneMedia: _reale(map['pressione_media']),
        ventoMax: _reale(map['vento_max']),
        rafficaMax: _reale(map['raffica_max']),
        direzioneVento: map['direzione_vento'] as int?,
        fonte: FonteMeteo.values.byName(map['fonte'] as String),
      );

  static Map<String, Object?> meteoGiornoToMap(MeteoGiorno g, int cellaId) => {
        'cella_id': cellaId,
        'data': formatData(g.data),
        'pioggia_mm': g.pioggiaMm,
        'temp_min': g.tempMin,
        'temp_max': g.tempMax,
        'pressione_media': g.pressioneMedia,
        'vento_max': g.ventoMax,
        'raffica_max': g.rafficaMax,
        'direzione_vento': g.direzioneVento,
        'fonte': g.fonte.name,
      };

  static MeteoOra meteoOraFromMap(Map<String, Object?> map) => MeteoOra(
        cellaId: map['cella_id'] as int?,
        dataOra: DateTime.parse('${map['data_ora'] as String}Z'),
        pioggiaMm: _reale(map['pioggia_mm']),
        temperatura: _reale(map['temperatura']),
        pressione: _reale(map['pressione']),
        vento: _reale(map['vento']),
        raffica: _reale(map['raffica']),
        direzioneVento: map['direzione_vento'] as int?,
        fonte: FonteMeteo.values.byName(map['fonte'] as String),
      );

  static Map<String, Object?> meteoOraToMap(MeteoOra o, int cellaId) => {
        'cella_id': cellaId,
        'data_ora': formatDataOra(o.dataOra),
        'pioggia_mm': o.pioggiaMm,
        'temperatura': o.temperatura,
        'pressione': o.pressione,
        'vento': o.vento,
        'raffica': o.raffica,
        'direzione_vento': o.direzioneVento,
        'fonte': o.fonte.name,
      };
}
