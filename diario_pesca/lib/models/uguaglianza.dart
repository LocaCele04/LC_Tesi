/// Confronto elemento per elemento di due liste, usato dagli `operator ==`
/// dei modelli che contengono collezioni. Così i modelli non dipendono da
/// Flutter (`listEquals` di `package:flutter/foundation.dart`).
bool listeUguali<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
