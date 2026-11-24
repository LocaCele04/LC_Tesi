/// Valore ammesso di una [Condizione] (es. "Morbida" per il Livello).
/// [ordine] è la posizione nella scala della condizione; un valore già usato
/// in qualche pescata non si elimina ma si disattiva ([attivo] = false).
class ValoreCondizione {
  final int? id;
  final int? condizioneId;
  final String nome;
  final int ordine;
  final bool attivo;

  const ValoreCondizione({
    this.id,
    this.condizioneId,
    required this.nome,
    this.ordine = 0,
    this.attivo = true,
  });

  /// `true` se l'oggetto non è ancora stato salvato nel database: l'id lo
  /// assegna SQLite all'inserimento. I repository restituiscono sempre
  /// oggetti con l'id valorizzato.
  bool get isNuovo => id == null;

  ValoreCondizione copyWith({
    int? id,
    int? condizioneId,
    String? nome,
    int? ordine,
    bool? attivo,
  }) {
    return ValoreCondizione(
      id: id ?? this.id,
      condizioneId: condizioneId ?? this.condizioneId,
      nome: nome ?? this.nome,
      ordine: ordine ?? this.ordine,
      attivo: attivo ?? this.attivo,
    );
  }

  @override
  String toString() =>
      'ValoreCondizione(id: $id, condizioneId: $condizioneId, nome: $nome, ordine: $ordine, attivo: $attivo)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValoreCondizione &&
          other.id == id &&
          other.condizioneId == condizioneId &&
          other.nome == nome &&
          other.ordine == ordine &&
          other.attivo == attivo;

  @override
  int get hashCode => Object.hash(id, condizioneId, nome, ordine, attivo);
}
