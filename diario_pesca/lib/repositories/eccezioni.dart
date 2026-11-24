/// Lanciata quando si crea al volo un elemento del catalogo (esca o
/// caratteristica) con un nome già usato e il nuovo elemento porta dati
/// diversi da quello esistente (descrizione, foto).
///
/// Riusare l'elemento esistente farebbe perdere quei dati senza avvisare,
/// quindi il salvataggio viene annullato: l'interfaccia può chiedere
/// all'utente se usare l'elemento esistente ([idEsistente]) oppure scegliere
/// un altro nome. Per controllare prima del salvataggio si possono usare
/// `CatalogoRepository.getEscaPerNome` e `getCaratteristicaPerNome`.
class NomeDuplicatoException implements Exception {
  /// Tipo di elemento: `'Esca'` o `'Caratteristica'`.
  final String tipo;
  final String nome;
  final int idEsistente;

  const NomeDuplicatoException({
    required this.tipo,
    required this.nome,
    required this.idEsistente,
  });

  @override
  String toString() =>
      'NomeDuplicatoException: esiste già un elemento $tipo chiamato "$nome" '
      '(id $idEsistente) con dati diversi da quelli inseriti';
}
