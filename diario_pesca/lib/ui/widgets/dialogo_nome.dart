import 'package:flutter/material.dart';

/// Chiede un nome all'utente (es. una nuova esca o specie). Restituisce il
/// testo senza spazi iniziali e finali, oppure `null` se l'utente annulla o
/// non scrive nulla.
Future<String?> chiediNome(
  BuildContext context, {
  required String titolo,
  required String etichetta,
}) async {
  final nome = await showDialog<String>(
    context: context,
    builder: (_) => _DialogoNome(titolo: titolo, etichetta: etichetta),
  );
  final pulito = nome?.trim();
  return pulito == null || pulito.isEmpty ? null : pulito;
}

class _DialogoNome extends StatefulWidget {
  const _DialogoNome({required this.titolo, required this.etichetta});

  final String titolo;
  final String etichetta;

  @override
  State<_DialogoNome> createState() => _DialogoNomeState();
}

class _DialogoNomeState extends State<_DialogoNome> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _conferma() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titolo),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.etichetta),
        onSubmitted: (_) => _conferma(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _conferma, child: const Text('Aggiungi')),
      ],
    );
  }
}
