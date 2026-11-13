import '../enums.dart';
import '../statistiche/riepilogo_specie.dart';
import 'cattura_memorabile.dart';
import 'esca.dart';
import 'foto.dart';

class Pescata {
  final int? id;
  final DateTime data;
  final FasciaOraria fasciaOraria;
  final Meteo meteo;
  final Trasparenza? trasparenza;
  final Fondo? fondo;
  final Livello? livello;
  final double? tempAcqua;
  final double? tempAria;
  final String? note;
  final String? spotNome;
  final List<Esca> esche;
  final List<Foto> foto;
  final List<CatturaMemorabile> cattureMemorabili;
  final List<RiepilogoSpecie> riepiloghiSpecie;

  const Pescata({
    this.id,
    required this.data,
    required this.fasciaOraria,
    required this.meteo,
    this.trasparenza,
    this.fondo,
    this.livello,
    this.tempAcqua,
    this.tempAria,
    this.note,
    this.spotNome,
    this.esche = const [],
    this.foto = const [],
    this.cattureMemorabili = const [],
    this.riepiloghiSpecie = const [],
  });

  Pescata copyWith({
    int? id,
    DateTime? data,
    FasciaOraria? fasciaOraria,
    Meteo? meteo,
    Trasparenza? trasparenza,
    Fondo? fondo,
    Livello? livello,
    double? tempAcqua,
    double? tempAria,
    String? note,
    String? spotNome,
    List<Esca>? esche,
    List<Foto>? foto,
    List<CatturaMemorabile>? cattureMemorabili,
    List<RiepilogoSpecie>? riepiloghiSpecie,
  }) {
    return Pescata(
      id: id ?? this.id,
      data: data ?? this.data,
      fasciaOraria: fasciaOraria ?? this.fasciaOraria,
      meteo: meteo ?? this.meteo,
      trasparenza: trasparenza ?? this.trasparenza,
      fondo: fondo ?? this.fondo,
      livello: livello ?? this.livello,
      tempAcqua: tempAcqua ?? this.tempAcqua,
      tempAria: tempAria ?? this.tempAria,
      note: note ?? this.note,
      spotNome: spotNome ?? this.spotNome,
      esche: esche ?? this.esche,
      foto: foto ?? this.foto,
      cattureMemorabili: cattureMemorabili ?? this.cattureMemorabili,
      riepiloghiSpecie: riepiloghiSpecie ?? this.riepiloghiSpecie,
    );
  }

  @override
  String toString() =>
      'Pescata(id: $id, data: $data, fasciaOraria: $fasciaOraria, meteo: $meteo, spotNome: $spotNome)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Pescata &&
        other.id == id &&
        other.data == data &&
        other.fasciaOraria == fasciaOraria &&
        other.meteo == meteo &&
        other.trasparenza == trasparenza &&
        other.fondo == fondo &&
        other.livello == livello &&
        other.tempAcqua == tempAcqua &&
        other.tempAria == tempAria &&
        other.note == note &&
        other.spotNome == spotNome &&
        _listEquals(other.esche, esche) &&
        _listEquals(other.foto, foto) &&
        _listEquals(other.cattureMemorabili, cattureMemorabili) &&
        _listEquals(other.riepiloghiSpecie, riepiloghiSpecie);
  }

  @override
  int get hashCode => Object.hash(
        id,
        data,
        fasciaOraria,
        meteo,
        trasparenza,
        fondo,
        livello,
        tempAcqua,
        tempAria,
        note,
        spotNome,
        Object.hashAll(esche),
        Object.hashAll(foto),
        Object.hashAll(cattureMemorabili),
        Object.hashAll(riepiloghiSpecie),
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}