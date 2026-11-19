import '../enums.dart';
import '../uguaglianza.dart';
import 'coordinata.dart';

class Spot {
  final String nome;
  final String ambiente;
  final double? lunghezzaMetri;
  final double? voto;
  final Difficolta? difficolta;
  final String? esposizioneSole;
  final String? noteOstacoli;
  final String? note;
  final bool battuto;
  final Accessibilita accessibilita;
  final String? linkParcheggio;
  final String categoriaNome;
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
    this.accessibilita = Accessibilita.accessibile,
    this.linkParcheggio,
    required this.categoriaNome,
    this.coordinate = const [],
  });

  Spot copyWith({
    String? nome,
    String? ambiente,
    double? lunghezzaMetri,
    double? voto,
    Difficolta? difficolta,
    String? esposizioneSole,
    String? noteOstacoli,
    String? note,
    bool? battuto,
    Accessibilita? accessibilita,
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
      accessibilita: accessibilita ?? this.accessibilita,
      linkParcheggio: linkParcheggio ?? this.linkParcheggio,
      categoriaNome: categoriaNome ?? this.categoriaNome,
      coordinate: coordinate ?? this.coordinate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Spot &&
          runtimeType == other.runtimeType &&
          nome == other.nome &&
          ambiente == other.ambiente &&
          lunghezzaMetri == other.lunghezzaMetri &&
          voto == other.voto &&
          difficolta == other.difficolta &&
          esposizioneSole == other.esposizioneSole &&
          noteOstacoli == other.noteOstacoli &&
          note == other.note &&
          battuto == other.battuto &&
          accessibilita == other.accessibilita &&
          linkParcheggio == other.linkParcheggio &&
          categoriaNome == other.categoriaNome &&
          listeUguali(coordinate, other.coordinate);

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
        accessibilita,
        linkParcheggio,
        categoriaNome,
        Object.hashAll(coordinate),
      );
}