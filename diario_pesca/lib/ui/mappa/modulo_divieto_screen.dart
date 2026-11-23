import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/territorio/coordinata.dart';
import '../../models/territorio/divieto.dart';
import '../../repositories/territorio_repository.dart';
import '../state/mappa_state.dart';
import '../widgets/dialoghi.dart';
import 'disegna_tratto_screen.dart';

/// Problemi che impediscono di salvare un divieto, in parole per l'utente.
List<String> problemiDivieto(String nome, List<Coordinata> punti) => [
      if (nome.trim().isEmpty) 'Scrivi il nome del divieto.',
      if (punti.isEmpty) 'Disegna il divieto sulla mappa.',
    ];

/// Modulo di un divieto: nome, note e tratto. [divieto] con `id` nullo per
/// uno nuovo (di solito appena disegnato sulla mappa).
class ModuloDivietoScreen extends ConsumerStatefulWidget {
  const ModuloDivietoScreen({super.key, required this.divieto});

  final Divieto divieto;

  @override
  ConsumerState<ModuloDivietoScreen> createState() => _ModuloDivietoScreenState();
}

class _ModuloDivietoScreenState extends ConsumerState<ModuloDivietoScreen> {
  late final _nome = TextEditingController(text: widget.divieto.nome);
  late final _note = TextEditingController(text: widget.divieto.note ?? '');
  late List<Coordinata> _punti = widget.divieto.coordinate;
  bool _inCorso = false;

  bool get _nuovo => widget.divieto.id == null;

  @override
  void dispose() {
    _nome.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _disegna() async {
    final punti = await Navigator.of(context).push<List<Coordinata>>(
      MaterialPageRoute(
        builder: (_) => DisegnaTrattoScreen(
          titolo: _nome.text.trim().isEmpty ? 'Tratto del divieto' : _nome.text.trim(),
          puntiIniziali: _punti,
          divieto: true,
          escludiDivieto: widget.divieto.id,
        ),
      ),
    );
    if (punti != null) setState(() => _punti = punti);
  }

  Future<void> _salva() async {
    final problemi = problemiDivieto(_nome.text, _punti);
    if (problemi.isNotEmpty) {
      await mostraProblemi(context, problemi);
      return;
    }
    final messaggi = ScaffoldMessenger.of(context);
    final navigatore = Navigator.of(context);
    setState(() => _inCorso = true);
    try {
      await ref.read(divietiProvider.notifier).salva(
            Divieto(
              id: widget.divieto.id,
              nome: _nome.text,
              note: _note.text,
              coordinate: _punti,
            ),
          );
      messaggi..clearSnackBars()..showSnackBar(const SnackBar(content: Text('Divieto salvato')));
      navigatore.pop();
    } catch (e) {
      messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text('Salvataggio non riuscito: $e')));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _elimina() async {
    final messaggi = ScaffoldMessenger.of(context);
    final navigatore = Navigator.of(context);
    final conferma = await chiediConferma(
      context,
      titolo: 'Eliminare il divieto "${widget.divieto.nome}"?',
      messaggio: 'Il divieto sparirà dalla mappa.',
      conferma: 'Elimina',
    );
    if (!conferma) return;
    setState(() => _inCorso = true);
    try {
      await ref.read(divietiProvider.notifier).elimina(widget.divieto.id!);
      messaggi..clearSnackBars()..showSnackBar(const SnackBar(content: Text('Divieto eliminato')));
      navigatore.pop();
    } catch (e) {
      messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text('Eliminazione non riuscita: $e')));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lunghezza = TerritorioRepository.calcolaLunghezzaMetri(_punti);
    return Scaffold(
      appBar: AppBar(title: Text(_nuovo ? 'Nuovo divieto' : 'Modifica divieto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _nome,
            decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Es. dall\'incubatoio fino al terzo ponte',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          Text(
            _punti.isEmpty
                ? 'Nessun punto: disegna il divieto sulla mappa.'
                : '${_punti.length == 1 ? '1 punto' : '${_punti.length} punti'}'
                    '${lunghezza == null ? '' : ' · ${lunghezza.round()} m'}',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _inCorso ? null : _disegna,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: Text(_punti.isEmpty ? 'Disegna sulla mappa' : 'Modifica sulla mappa'),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _inCorso ? null : _salva,
            icon: const Icon(Icons.save),
            label: const Text('Salva divieto'),
          ),
          if (!_nuovo) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: _inCorso ? null : _elimina,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Elimina divieto'),
            ),
          ],
        ],
      ),
    );
  }
}
