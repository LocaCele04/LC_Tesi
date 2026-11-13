import '../enums.dart';

class Pianificazione {
  final int? id;
  final DateTime data;
  final FasciaOraria fasciaOraria;
  final String? note;
  final String? spotNome;

  const Pianificazione({
    this.id,
    required this.data,
    required this.fasciaOraria,
    this.note,
    this.spotNome,
  });

  Pianificazione copyWith({
    int? id,
    DateTime? data,
    FasciaOraria? fasciaOraria,
    String? note,
    String? spotNome,
  }) {
    return Pianificazione(
      id: id ?? this.id,
      data: data ?? this.data,
      fasciaOraria: fasciaOraria ?? this.fasciaOraria,
      note: note ?? this.note,
      spotNome: spotNome ?? this.spotNome,
    );
  }

  @override
  String toString() =>
      'Pianificazione(id: $id, data: $data, fasciaOraria: $fasciaOraria, spotNome: $spotNome)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Pianificazione &&
        other.id == id &&
        other.data == data &&
        other.fasciaOraria == fasciaOraria &&
        other.note == note &&
        other.spotNome == spotNome;
  }

  @override
  int get hashCode => Object.hash(id, data, fasciaOraria, note, spotNome);
}