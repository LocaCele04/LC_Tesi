class Specie {
  final String nome;
  final String? informazioni;

  const Specie({
    required this.nome,
    this.informazioni,
  });

  Specie copyWith({
    String? nome,
    String? informazioni,
  }) {
    return Specie(
      nome: nome ?? this.nome,
      informazioni: informazioni ?? this.informazioni,
    );
  }

  @override
  String toString() => 'Specie(nome: $nome, informazioni: $informazioni)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Specie &&
        other.nome == nome &&
        other.informazioni == informazioni;
  }

  @override
  int get hashCode => Object.hash(nome, informazioni);
}