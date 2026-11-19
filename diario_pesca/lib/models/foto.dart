class Foto {
  final int? id;
  final String percorso;
  final String percorsoThumbnail;
  final int? pescataId;
  final int? catturaMemorabileId;
  final int? escaId;

  const Foto({
    this.id,
    required this.percorso,
    required this.percorsoThumbnail,
    this.pescataId,
    this.catturaMemorabileId,
    this.escaId,
  }) : assert(
  (pescataId != null ? 1 : 0) +
            (catturaMemorabileId != null ? 1 : 0) +
            (escaId != null ? 1 : 0) <=
        1,
    'Una foto non può essere associata contemporaneamente a più di un elemento tra pescata, cattura memorabile ed esca',
  );

  Foto copyWith({
    int? id,
    String? percorso,
    String? percorsoThumbnail,
    int? pescataId,
    int? catturaMemorabileId,
    int? escaId
  }) {
    return Foto(
      id: id ?? this.id,
      percorso: percorso ?? this.percorso,
      percorsoThumbnail: percorsoThumbnail ?? this.percorsoThumbnail,
      pescataId: pescataId ?? this.pescataId,
      catturaMemorabileId: catturaMemorabileId ?? this.catturaMemorabileId,
      escaId: escaId ?? this.escaId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Foto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          percorso == other.percorso &&
          percorsoThumbnail == other.percorsoThumbnail &&
          pescataId == other.pescataId &&
          catturaMemorabileId == other.catturaMemorabileId &&
          escaId == other.escaId;

  @override
  int get hashCode =>
      Object.hash(id, percorso, percorsoThumbnail, pescataId, catturaMemorabileId, escaId);
}