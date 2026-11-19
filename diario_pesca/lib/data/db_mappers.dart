import '../models/catalogo/caratteristica.dart';
import '../models/catalogo/esca.dart';
import '../models/catalogo/specie.dart';
import '../models/enums.dart';
import '../models/foto.dart';
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
  }) {
    final trasparenzaRaw = map['trasparenza'] as String?;
    final fondoRaw = map['fondo'] as String?;
    final livelloRaw = map['livello'] as String?;

    return Pescata(
      id: map['id'] as int?,
      data: DateTime.parse(map['data'] as String),
      fasciaOraria:
          FasciaOraria.values.byName(map['fasciaOraria'] as String),
      meteo: Meteo.values.byName(map['meteo'] as String),
      trasparenza: trasparenzaRaw != null
          ? Trasparenza.values.byName(trasparenzaRaw)
          : null,
      fondo: fondoRaw != null ? Fondo.values.byName(fondoRaw) : null,
      livello: livelloRaw != null ? Livello.values.byName(livelloRaw) : null,
      tempAcqua: (map['temp_acqua'] as num?)?.toDouble(),
      tempAria: (map['temp_aria'] as num?)?.toDouble(),
      note: map['note'] as String?,
      spotNome: map['spot_nome'] as String?,
      esche: esche,
      foto: foto,
      cattureMemorabili: cattureMemorabili,
      riepiloghiSpecie: riepiloghiSpecie,
    );
  }

  static Map<String, Object?> pescataToMap(Pescata p) => {
        if (p.id != null) 'id': p.id,
        'data': formatData(p.data),
        'fasciaOraria': p.fasciaOraria.name,
        'meteo': p.meteo.name,
        'trasparenza': p.trasparenza?.name,
        'fondo': p.fondo?.name,
        'livello': p.livello?.name,
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
}
