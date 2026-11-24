/// Una bozza di modulo (pescata, spot…) ha dei [problemi] che ne impediscono
/// il salvataggio, già scritti in parole per l'utente.
class BozzaNonValida implements Exception {
  final List<String> problemi;
  const BozzaNonValida(this.problemi);

  @override
  String toString() => 'BozzaNonValida: ${problemi.join(' ')}';
}
