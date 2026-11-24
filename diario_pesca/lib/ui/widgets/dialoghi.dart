import 'package:flutter/material.dart';

/// Elenca i problemi che impediscono di salvare un modulo.
Future<void> mostraProblemi(BuildContext context, List<String> problemi) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Controlla i dati'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in problemi)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $p'),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

/// Chiede conferma prima di un'operazione che non si può annullare.
/// Restituisce `true` solo se l'utente conferma.
Future<bool> chiediConferma(
  BuildContext context, {
  required String titolo,
  required String messaggio,
  required String conferma,
}) async {
  final risposta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titolo),
      content: Text(messaggio),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(conferma),
        ),
      ],
    ),
  );
  return risposta ?? false;
}

/// Avvisa prima di uscire da un modulo con modifiche non salvate.
///
/// Con [modificato] `false` si esce come sempre; altrimenti il tasto
/// indietro (o la freccia in alto) chiede conferma. Le uscite fatte dal
/// codice con `Navigator.pop`, come dopo un salvataggio, non vengono
/// fermate.
class UscitaProtetta extends StatelessWidget {
  const UscitaProtetta({
    super.key,
    required this.modificato,
    required this.child,
    this.messaggio = 'Le modifiche fatte andranno perse.',
  });

  final bool modificato;
  final String messaggio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !modificato,
      onPopInvokedWithResult: (uscito, _) async {
        if (uscito) return;
        final navigatore = Navigator.of(context);
        final esci = await chiediConferma(
          context,
          titolo: 'Uscire senza salvare?',
          messaggio: messaggio,
          conferma: 'Esci',
        );
        if (esci) navigatore.pop();
      },
      child: child,
    );
  }
}
