import '../catalogo/caratteristica.dart';
import '../catalogo/esca.dart';
import '../foto.dart';
import '../uguaglianza.dart';

class CatturaMemorabile {
  final int? id;
  final String? descrizione;
  final int? pescataId;
  final String specieNome;
  final Esca? esca;
  final List<Caratteristica> caratteristiche;
  final List<Foto> foto;

  const CatturaMemorabile({
    this.id,
    this.descrizione,
    this.pescataId,
    required this.specieNome,
    this.esca,
    this.caratteristiche = const [],
    this.foto = const [],
  });

  /// `true` se l'oggetto non è ancora stato salvato nel database: l'id lo
  /// assegna SQLite all'inserimento. I repository restituiscono sempre
  /// oggetti con l'id valorizzato.
  bool get isNuovo => id == null;

  CatturaMemorabile copyWith({
    int? id,
    String? descrizione,
    int? pescataId,
    String? specieNome,
    Esca? esca,
    List<Caratteristica>? caratteristiche,
    List<Foto>? foto,
  }) {
    return CatturaMemorabile(
      id: id ?? this.id,
      descrizione: descrizione ?? this.descrizione,
      pescataId: pescataId ?? this.pescataId,
      specieNome: specieNome ?? this.specieNome,
      esca: esca ?? this.esca,
      caratteristiche: caratteristiche ?? this.caratteristiche,
      foto: foto ?? this.foto,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatturaMemorabile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          descrizione == other.descrizione &&
          pescataId == other.pescataId &&
          specieNome == other.specieNome &&
          esca == other.esca &&
          listeUguali(caratteristiche, other.caratteristiche) &&
          listeUguali(foto, other.foto);

  @override
  int get hashCode => Object.hash(
        id,
        descrizione,
        pescataId,
        specieNome,
        esca,
        Object.hashAll(caratteristiche),
        Object.hashAll(foto),
      );
}