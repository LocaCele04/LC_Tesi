import '../enums.dart';
import 'coordinata.dart';

class Spot {
  final String nome;
  final String ambiente;
  final double? lunghezzaMetri;
  final int? voto;
  final Difficolta? difficolta;
  final String? esposizioneSole;
  final String? noteOstacoli;
  final String? note;
  final bool battuto;
  final String? linkParcheggio;
  final String? categoriaNome;
  final List<Coordinata> coordinate;

  const Spot({
    required this.nome,
    required this.ambiente,
    this.lunghezzaMetri,
    this.voto,
    this.difficolta,
    this.esposizioneSole,
    this.noteOstacoli,
    this.note,
    this.battuto = false,
    this.linkParcheggio,
    this.categoriaNome,
    this.coordinate = const [],
  });

  Spot copyWith({
    String? nome,
    String? ambiente,
    double? lunghezzaMetri,
    int? voto,
    Difficolta? difficolta,
    String? esposizioneSole,
    String? noteOstacoli,
    String? note,
    bool? battuto,
    String? linkParcheggio,
    String? categoriaNome,
    List<Coordinata>? coordinate,
  }) {
    return Spot(
      nome: nome ?? this.nome,
      ambiente: ambiente ?? this.ambiente,
      lunghezzaMetri: lunghezzaMetri ?? this.lunghezzaMetri,
      voto: voto ?? this.voto,
      difficolta: difficolta ?? this.difficolta,
      esposizioneSole: esposizioneSole ?? this.esposizioneSole,
      noteOstacoli: noteOstacoli ?? this.noteOstacoli,
      note: note ?? this.note,
      battuto: battuto ?? this.battuto,
      linkParcheggio: linkParcheggio ?? this.linkParcheggio,
      categoriaNome: categoriaNome ?? this.categoriaNome,
      coordinate: coordinate ?? this.coordinate,
    );
  }

  @override
  String toString() =>
      'Spot(nome: $nome, ambiente: $ambiente, voto: $voto, difficolta: $difficolta, battuto: $battuto, categoriaNome: $categoriaNome)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Spot &&
        other.nome == nome &&
        other.ambiente == ambiente &&
        other.lunghezzaMetri == lunghezzaMetri &&
        other.voto == voto &&
        other.difficolta == difficolta &&
        other.esposizioneSole == esposizioneSole &&
        other.noteOstacoli == noteOstacoli &&
        other.note == note &&
        other.battuto == battuto &&
        other.linkParcheggio == linkParcheggio &&
        other.categoriaNome == categoriaNome &&
        _listEquals(other.coordinate, coordinate);
  }

  @override
  int get hashCode => Object.hash(
        nome,
        ambiente,
        lunghezzaMetri,
        voto,
        difficolta,
        esposizioneSole,
        noteOstacoli,
        note,
        battuto,
        linkParcheggio,
        categoriaNome,
        Object.hashAll(coordinate),
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