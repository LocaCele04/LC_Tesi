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
