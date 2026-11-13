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
          (pescataId != null && catturaMemorabileId == null) ||
              (pescataId == null && catturaMemorabileId != null),
          'Una Foto deve essere collegata esclusivamente a una Pescata o a una CatturaMemorabile.',
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
  String toString() =>
      'Foto(id: $id, percorso: $percorso, pescataId: $pescataId, catturaMemorabileId: $catturaMemorabileId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Foto &&
        other.id == id &&
        other.percorso == percorso &&
        other.percorsoThumbnail == percorsoThumbnail &&
        other.pescataId == pescataId &&
        other.catturaMemorabileId == catturaMemorabileId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        percorso,
        percorsoThumbnail,
        pescataId,
        catturaMemorabileId,
      );
}