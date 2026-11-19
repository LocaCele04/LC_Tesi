import '../catalogo/esca.dart';
import '../catalogo/valore_condizione.dart';
import '../enums.dart';
import '../foto.dart';
import '../uguaglianza.dart';
import 'cattura_memorabile.dart';
import 'riepilogo_specie.dart';

/// Attività di pesca in un singolo spot in una certa data e fascia oraria.
///
/// Le condizioni (livello, trasparenza, meteo, ...) non sono campi fissi:
/// [valoriCondizioni] contiene il valore scelto per ciascuna condizione
/// compilata, al massimo uno per condizione.
class Pescata {
  final int? id;
  final DateTime data;
  final FasciaOraria fasciaOraria;
  final double? tempAcqua;
  final double? tempAria;
  final String? note;
  final String? spotNome;
  final List<ValoreCondizione> valoriCondizioni;
  final List<Esca> esche;
  final List<Foto> foto;
  final List<CatturaMemorabile> cattureMemorabili;
  final List<RiepilogoSpecie> riepiloghiSpecie;

  const Pescata({
    this.id,
    required this.data,
    required this.fasciaOraria,
    this.tempAcqua,
    this.tempAria,
    this.note,
    this.spotNome,
    this.valoriCondizioni = const [],
    this.esche = const [],
    this.foto = const [],
    this.cattureMemorabili = const [],
    this.riepiloghiSpecie = const [],
  });

  /// `true` se l'oggetto non è ancora stato salvato nel database: l'id lo
  /// assegna SQLite all'inserimento. I repository restituiscono sempre
  /// oggetti con l'id valorizzato.
  bool get isNuovo => id == null;

  /// Valore scelto per la condizione [condizioneId], o `null` se non compilata.
  ValoreCondizione? valorePer(int condizioneId) {
    for (final v in valoriCondizioni) {
      if (v.condizioneId == condizioneId) return v;
    }
    return null;
  }

  Pescata copyWith({
    int? id,
    DateTime? data,
    FasciaOraria? fasciaOraria,
    double? tempAcqua,
    double? tempAria,
    String? note,
    String? spotNome,
    List<ValoreCondizione>? valoriCondizioni,
    List<Esca>? esche,
    List<Foto>? foto,
    List<CatturaMemorabile>? cattureMemorabili,
    List<RiepilogoSpecie>? riepiloghiSpecie,
  }) {
    return Pescata(
      id: id ?? this.id,
      data: data ?? this.data,
      fasciaOraria: fasciaOraria ?? this.fasciaOraria,
      tempAcqua: tempAcqua ?? this.tempAcqua,
      tempAria: tempAria ?? this.tempAria,
      note: note ?? this.note,
      spotNome: spotNome ?? this.spotNome,
      valoriCondizioni: valoriCondizioni ?? this.valoriCondizioni,
      esche: esche ?? this.esche,
      foto: foto ?? this.foto,
      cattureMemorabili: cattureMemorabili ?? this.cattureMemorabili,
      riepiloghiSpecie: riepiloghiSpecie ?? this.riepiloghiSpecie,
    );
  }

  @override
  String toString() =>
      'Pescata(id: $id, data: $data, fasciaOraria: $fasciaOraria, spotNome: $spotNome, condizioni: ${valoriCondizioni.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Pescata &&
        other.id == id &&
        other.data == data &&
        other.fasciaOraria == fasciaOraria &&
        other.tempAcqua == tempAcqua &&
        other.tempAria == tempAria &&
        other.note == note &&
        other.spotNome == spotNome &&
        listeUguali(other.valoriCondizioni, valoriCondizioni) &&
        listeUguali(other.esche, esche) &&
        listeUguali(other.foto, foto) &&
        listeUguali(other.cattureMemorabili, cattureMemorabili) &&
        listeUguali(other.riepiloghiSpecie, riepiloghiSpecie);
  }

  @override
  int get hashCode => Object.hash(
        id,
        data,
        fasciaOraria,
        tempAcqua,
        tempAria,
        note,
        spotNome,
        Object.hashAll(valoriCondizioni),
        Object.hashAll(esche),
        Object.hashAll(foto),
        Object.hashAll(cattureMemorabili),
        Object.hashAll(riepiloghiSpecie),
      );
}
