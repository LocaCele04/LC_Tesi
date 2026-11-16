class Foto {
  final int? id;
  final String percorso;
  final String percorsoThumbnail;
  final int? pescataId;
  final int? catturaMemorabileId;

  const Foto({
    this.id,
    required this.percorso,
    required this.percorsoThumbnail,
    this.pescataId,
    this.catturaMemorabileId,
  }) : assert(
          !(pescataId != null && catturaMemorabileId != null),
          'Una foto non può essere associata contemporaneamente a una pescata e a una cattura memorabile',
        );

  Foto copyWith({
    int? id,
    String? percorso,
    String? percorsoThumbnail,
    int? pescataId,
    int? catturaMemorabileId,
  }) {
    return Foto(
      id: id ?? this.id,
      percorso: percorso ?? this.percorso,
      percorsoThumbnail: percorsoThumbnail ?? this.percorsoThumbnail,
      pescataId: pescataId ?? this.pescataId,
      catturaMemorabileId: catturaMemorabileId ?? this.catturaMemorabileId,
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
          catturaMemorabileId == other.catturaMemorabileId;

  @override
  int get hashCode =>
      Object.hash(id, percorso, percorsoThumbnail, pescataId, catturaMemorabileId);
}