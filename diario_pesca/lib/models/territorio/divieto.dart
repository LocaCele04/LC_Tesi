import '../uguaglianza.dart';
import 'coordinata.dart';

/// Tratto in cui la pesca è vietata. Non è uno spot: non ha voto,
/// categoria o ambiente, non compare tra gli spot né nelle pescate e si
/// vede solo sulla mappa.
///
/// Più divieti possono avere lo stesso nome: l'identità è [id] (`null` per
/// un divieto non ancora salvato). Le [coordinate] usano lo stesso modello
/// dei punti degli spot, con `spotNome` sempre `null`.
class Divieto {
  final int? id;
  final String nome;
  final String? note;
  final List<Coordinata> coordinate;

  const Divieto({
    this.id,
    required this.nome,
    this.note,
    this.coordinate = const [],
  });

  Divieto copyWith({
    int? id,
    String? nome,
    String? note,
    List<Coordinata>? coordinate,
  }) {
    return Divieto(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      note: note ?? this.note,
      coordinate: coordinate ?? this.coordinate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Divieto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nome == other.nome &&
          note == other.note &&
          listeUguali(coordinate, other.coordinate);

  @override
  int get hashCode => Object.hash(id, nome, note, Object.hashAll(coordinate));
}
