import 'package:flutter/foundation.dart';

import 'foto.dart';

class Esca {
  final int? id;
  final String nome;
  final String? descrizione;
  final List<Foto> foto;

  const Esca({
    this.id,
    required this.nome,
    this.descrizione,
    this.foto = const [],
  });

  Esca copyWith({
    int? id,
    String? nome,
    String? descrizione,
    List<Foto>? foto,
  }) {
    return Esca(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descrizione: descrizione ?? this.descrizione,
      foto: foto ?? this.foto,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Esca &&
        other.id == id &&
        other.nome == nome &&
        other.descrizione == descrizione &&
        listEquals(other.foto, foto);
  }

  @override
  int get hashCode => Object.hash(
        id,
        nome,
        descrizione,
        Object.hashAll(foto),
      );

  @override
  String toString() =>
      'Esca(id: $id, nome: $nome, descrizione: $descrizione, foto: ${foto.length})';
}