import '../uguaglianza.dart';
import 'valore_condizione.dart';

/// Condizione personalizzabile che il pescatore registra nelle pescate
/// (es. Livello, Trasparenza, Meteo, o per il mare Stato del mare), con
/// l'elenco ordinato dei suoi valori ammessi.
///
/// Le condizioni vengono collegate agli ambienti per decidere quali
/// proporre nel form di una pescata; il collegamento non vincola i dati.
class Condizione {
  final int? id;
  final String nome;

  /// Posizione della condizione nel form della pescata.
  final int ordine;

  /// Una condizione disattivata non viene più proposta nelle nuove pescate,
  /// ma resta visibile in quelle che la usano.
  final bool attiva;

  /// Valori ammessi, nell'ordine della scala.
  final List<ValoreCondizione> valori;

  const Condizione({
    this.id,
    required this.nome,
    this.ordine = 0,
    this.attiva = true,
    this.valori = const [],
  });

  /// `true` se l'oggetto non è ancora stato salvato nel database: l'id lo
  /// assegna SQLite all'inserimento. I repository restituiscono sempre
  /// oggetti con l'id valorizzato.
  bool get isNuovo => id == null;

  /// Valori proponibili nelle nuove pescate.
  List<ValoreCondizione> get valoriAttivi =>
      valori.where((v) => v.attivo).toList();

  Condizione copyWith({
    int? id,
    String? nome,
    int? ordine,
    bool? attiva,
    List<ValoreCondizione>? valori,
  }) {
    return Condizione(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      ordine: ordine ?? this.ordine,
      attiva: attiva ?? this.attiva,
      valori: valori ?? this.valori,
    );
  }

  @override
  String toString() =>
      'Condizione(id: $id, nome: $nome, ordine: $ordine, attiva: $attiva, valori: ${valori.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Condizione &&
          other.id == id &&
          other.nome == nome &&
          other.ordine == ordine &&
          other.attiva == attiva &&
          listeUguali(other.valori, valori);

  @override
  int get hashCode =>
      Object.hash(id, nome, ordine, attiva, Object.hashAll(valori));
}
