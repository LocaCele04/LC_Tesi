import '../../models/territorio/coordinata.dart';
import '../../repositories/territorio_repository.dart';

/// Tratto che l'utente sta disegnando sulla mappa: i punti in ordine e la
/// cronologia per annullare. Non dipende dalla mappa (solo coordinate),
/// così si prova con i test unitari; la schermata di disegno traduce i
/// gesti in queste operazioni.
///
/// Ogni operazione salva lo stato precedente, tranne gli spostamenti
/// successivi al primo di un trascinamento: si annulla l'intero
/// trascinamento, non ogni suo piccolo passo.
class TrattoInModifica {
  TrattoInModifica([List<Coordinata> iniziali = const []])
      : _punti = [for (final p in iniziali) _punto(p.latitudine, p.longitudine)],
        _iniziali = [for (final p in iniziali) _punto(p.latitudine, p.longitudine)];

  List<Coordinata> _punti;
  final List<Coordinata> _iniziali;
  final List<List<Coordinata>> _cronologia = [];

  static Coordinata _punto(double lat, double lon) =>
      Coordinata(ordine: 0, latitudine: lat, longitudine: lon);

  /// Punti nell'ordine del tratto, con `ordine` = posizione.
  List<Coordinata> get punti => [
        for (var i = 0; i < _punti.length; i++) _punti[i].copyWith(ordine: i),
      ];

  int get numeroPunti => _punti.length;

  bool get puoAnnullare => _cronologia.isNotEmpty;

  /// `true` se i punti sono diversi da quelli di partenza.
  bool get modificato {
    if (_punti.length != _iniziali.length) return true;
    for (var i = 0; i < _punti.length; i++) {
      if (_punti[i].latitudine != _iniziali[i].latitudine ||
          _punti[i].longitudine != _iniziali[i].longitudine) {
        return true;
      }
    }
    return false;
  }

  /// Lunghezza in metri lungo i punti, `null` con meno di due punti.
  double? get lunghezzaMetri => TerritorioRepository.calcolaLunghezzaMetri(_punti);

  void _registra() => _cronologia.add(List.of(_punti));

  /// Aggiunge un punto in fondo al tratto.
  void aggiungi(double latitudine, double longitudine) {
    _registra();
    _punti = [..._punti, _punto(latitudine, longitudine)];
  }

  /// Punto a metà tra il punto [indice] e il successivo, dove la mappa
  /// mostra il pulsante per inserirne uno nuovo.
  Coordinata puntoMedio(int indice) {
    final a = _punti[indice];
    final b = _punti[indice + 1];
    return _punto((a.latitudine + b.latitudine) / 2, (a.longitudine + b.longitudine) / 2);
  }

  /// Inserisce un punto a metà tra il punto [indice] e il successivo.
  void inserisciInMezzo(int indice) {
    final medio = puntoMedio(indice);
    _registra();
    _punti = [..._punti]..insert(indice + 1, medio);
  }

  /// Da chiamare quando inizia il trascinamento del punto: salva lo stato
  /// per poter annullare l'intero spostamento.
  void iniziaSpostamento() => _registra();

  /// Sposta il punto [indice]. Non salva lo stato: vedi [iniziaSpostamento].
  void sposta(int indice, double latitudine, double longitudine) {
    _punti = [..._punti]..[indice] = _punto(latitudine, longitudine);
  }

  void rimuovi(int indice) {
    _registra();
    _punti = [..._punti]..removeAt(indice);
  }

  /// Toglie tutti i punti (si può annullare).
  void svuota() {
    if (_punti.isEmpty) return;
    _registra();
    _punti = const [];
  }

  /// Annulla l'ultima operazione.
  void annulla() {
    if (_cronologia.isEmpty) return;
    _punti = _cronologia.removeLast();
  }
}
