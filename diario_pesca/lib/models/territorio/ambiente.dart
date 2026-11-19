/// Tipologia di corso o specchio d'acqua di uno spot (es. Torrente, Lago).
/// Gli ambienti di base sono creati con il database; l'utente può aggiungerne
/// altri. Il confronto tra nomi non distingue maiuscole e minuscole.
class Ambiente {
  final String nome;

  const Ambiente({required this.nome});

  Ambiente copyWith({String? nome}) {
    return Ambiente(nome: nome ?? this.nome);
  }

  @override
  String toString() => 'Ambiente(nome: $nome)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ambiente &&
        other.nome.toLowerCase() == nome.toLowerCase();
  }

  @override
  int get hashCode => nome.toLowerCase().hashCode;
}
