class Nota {
  final int? id;
  final String testo;

  Nota({this.id, required this.testo});

  // Converte l'oggetto in Map per SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'testo': testo,
    };
  }

  // Converte la Map di SQLite in oggetto Nota
  factory Nota.fromMap(Map<String, dynamic> map) {
    return Nota(
      id: map['id'] as int?,
      testo: map['testo'] as String,
    );
  }
}