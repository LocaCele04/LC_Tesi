import '../statistiche/caratteristica.dart';
import 'foto.dart';

/**Prima del salvataggio (in memoria):
 *  Quando l'utente compila un form per creare un nuovo record (ad esempio un nuovo Obiettivo), 
 * l'ID non esiste ancora, quindi istanzi l'oggetto con id: null */


class CatturaMemorabile {
  final int? id;
  final String? descrizione;
  final int pescataId;
  final String specieNome;
  final int? escaId;
  final List<Caratteristica> caratteristiche;
  final List<Foto> foto;

  const CatturaMemorabile({
    this.id,
    this.descrizione,
    required this.pescataId,
    required this.specieNome,
    this.escaId,
    this.caratteristiche = const [],
    this.foto = const [],
  });

  CatturaMemorabile copyWith({
    int? id,
    String? descrizione,
    int? pescataId,
    String? specieNome,
    int? escaId,
    List<Caratteristica>? caratteristiche,
    List<Foto>? foto,
  }) {
    return CatturaMemorabile(
      id: id ?? this.id,
      descrizione: descrizione ?? this.descrizione,
      pescataId: pescataId ?? this.pescataId,
      specieNome: specieNome ?? this.specieNome,
      escaId: escaId ?? this.escaId,
      caratteristiche: caratteristiche ?? this.caratteristiche,
      foto: foto ?? this.foto,
    );
  }

  @override
  String toString() =>
      'CatturaMemorabile(id: $id, pescataId: $pescataId, specieNome: $specieNome, escaId: $escaId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CatturaMemorabile &&
        other.id == id &&
        other.descrizione == descrizione &&
        other.pescataId == pescataId &&
        other.specieNome == specieNome &&
        other.escaId == escaId &&
        _listEquals(other.caratteristiche, caratteristiche) &&
        _listEquals(other.foto, foto);
  }

  @override
  int get hashCode => Object.hash(
        id,
        descrizione,
        pescataId,
        specieNome,
        escaId,
        Object.hashAll(caratteristiche),
        Object.hashAll(foto),
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