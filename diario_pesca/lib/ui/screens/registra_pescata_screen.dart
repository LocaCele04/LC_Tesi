import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalogo/esca.dart';
import '../../models/catalogo/specie.dart';
import '../../models/enums.dart';
import '../../models/territorio/spot.dart';
import '../state/catalogo_state.dart';
import '../state/dipendenze.dart';
import '../state/modulo_pescata_state.dart';
import '../state/spot_state.dart';
import '../widgets/dialoghi.dart';
import '../widgets/dialogo_nome.dart';
import '../widgets/etichette.dart';
import '../widgets/vista_asincrona.dart';
import 'modulo_spot_screen.dart';

/// Modulo per registrare una nuova pescata ([REQ-FUN-06] e [REQ-FUN-07]):
/// spot, data, fascia oraria, condizioni dell'ambiente dello spot,
/// temperature, esche usate, catture per specie con le caratteristiche e note.
///
/// Il contenuto del modulo sta in [moduloPescataProvider]; questa schermata
/// lo mostra e inoltra le modifiche. Le foto e le catture memorabili si
/// aggiungeranno quando sarà pronto il `FotoService`.
class RegistraPescataScreen extends ConsumerStatefulWidget {
  const RegistraPescataScreen({super.key, this.apertura, this.spotIniziale});

  /// Pescata da modificare; `null` per registrarne una nuova.
  final AperturaPescata? apertura;

  /// Spot già scelto per una pescata nuova (es. aperta dalla mappa).
  final ({String nome, String ambiente})? spotIniziale;

  @override
  ConsumerState<RegistraPescataScreen> createState() => _RegistraPescataScreenState();
}

class _RegistraPescataScreenState extends ConsumerState<RegistraPescataScreen> {
  bool _salvataggioInCorso = false;

  @override
  void initState() {
    super.initState();
    final spot = widget.spotIniziale;
    if (spot != null && widget.apertura == null) {
      // Dopo il primo disegno: durante la costruzione dei widget non si
      // può modificare lo stato di un provider.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(moduloPescataProvider(null).notifier)
            ..impostaSpot(spot.nome, spot.ambiente)
            ..fissaComeIniziale();
        }
      });
    }
  }

  Future<void> _salva() async {
    final messaggi = ScaffoldMessenger.of(context);
    final navigatore = Navigator.of(context);
    List<String>? problemi;
    setState(() => _salvataggioInCorso = true);
    try {
      await ref.read(moduloPescataProvider(widget.apertura).notifier).salva();
      messaggi..clearSnackBars()..showSnackBar(const SnackBar(content: Text('Pescata salvata')));
      navigatore.pop();
    } on BozzaNonValida catch (e) {
      problemi = e.problemi;
    } catch (e) {
      messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text('Salvataggio non riuscito: $e')));
    } finally {
      if (mounted) setState(() => _salvataggioInCorso = false);
    }
    // Il dialogo si apre dopo aver tolto l'indicatore di salvataggio, che
    // altrimenti resterebbe a girare dietro al dialogo.
    if (problemi != null && mounted) await mostraProblemi(context, problemi);
  }

  @override
  Widget build(BuildContext context) {
    final bozza = ref.watch(moduloPescataProvider(widget.apertura));
    final modulo = ref.read(moduloPescataProvider(widget.apertura).notifier);

    return UscitaProtetta(
      modificato: modulo.modificato,
      messaggio: 'Le modifiche alla pescata andranno perse.',
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.apertura == null ? 'Nuova pescata' : 'Modifica pescata'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SizedBox(height: 8),
            _SceltaSpot(widget.apertura),
            const SizedBox(height: 12),
            _CampoData(widget.apertura),
            const _Titolo('Fascia oraria'),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final f in FasciaOraria.values)
                  ChoiceChip(
                    label: Text(etichettaFascia(f)),
                    selected: bozza.fasciaOraria == f,
                    onSelected: (_) => modulo.impostaFascia(f),
                  ),
              ],
            ),
            const _Titolo('Condizioni'),
            _Condizioni(widget.apertura),
            const _Titolo('Temperatura dell\'acqua'),
            TextFormField(
              initialValue: bozza.tempAcqua,
              decoration: const InputDecoration(
                labelText: 'Gradi (°C), facoltativa',
                helperText: 'L\'aria la ricava il meteo scaricato.',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: modulo.impostaTempAcqua,
            ),
            const _Titolo('Esche usate'),
            _Esche(widget.apertura),
            const _Titolo('Catture'),
            for (final c in bozza.catture)
              _SchedaCattura(key: ValueKey(c.chiave), chiave: c.chiave, apertura: widget.apertura),
            OutlinedButton.icon(
              onPressed: modulo.aggiungiCattura,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi specie'),
            ),
            const SizedBox(height: 20),
            Text(
              'Totale pescata: ${bozza.totaleCatture} '
              '${bozza.totaleCatture == 1 ? 'cattura' : 'catture'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const _Titolo('Note'),
            TextFormField(
              initialValue: bozza.note,
              decoration: const InputDecoration(
                labelText: 'Note (facoltative)',
                border: OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onChanged: modulo.impostaNote,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _salvataggioInCorso ? null : _salva,
              icon: _salvataggioInCorso
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Salva pescata'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Titolo extends StatelessWidget {
  const _Titolo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 32, bottom: 12),
        child: Text(testo, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _SceltaSpot extends ConsumerWidget {
  const _SceltaSpot(this.apertura);

  final AperturaPescata? apertura;

  /// Crea uno spot al momento ([REQ-FUN-06]) e lo sceglie per la pescata.
  Future<void> _nuovoSpot(BuildContext context, WidgetRef ref) async {
    final modulo = ref.read(moduloPescataProvider(apertura).notifier);
    final nuovo = await Navigator.of(context).push<Spot>(
      MaterialPageRoute(builder: (_) => const ModuloSpotScreen()),
    );
    if (nuovo != null) modulo.impostaSpot(nuovo.nome, nuovo.ambiente);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotNome = ref.watch(moduloPescataProvider(apertura).select((b) => b.spotNome));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sezioneAsincrona<List<Spot>>(ref.watch(elencoSpotProvider), (spot) {
          if (spot.isEmpty) {
            return const Text('Nessuno spot salvato: creane uno con il pulsante qui sotto.');
          }
          Spot? scelto;
          for (final s in spot) {
            if (s.nome == spotNome) scelto = s;
          }
          return DropdownMenu<Spot>(
            // Ricostruito quando lo spot viene scelto da fuori (spot nuovo).
            key: ValueKey('spot-$spotNome'),
            expandedInsets: EdgeInsets.zero,
            label: const Text('Spot'),
            hintText: 'Scrivi per cercare',
            enableFilter: true,
            requestFocusOnTap: true,
            menuHeight: 320,
            initialSelection: scelto,
            dropdownMenuEntries: [
              for (final s in spot) DropdownMenuEntry(value: s, label: s.nome),
            ],
            onSelected: (s) {
              if (s != null) ref.read(moduloPescataProvider(apertura).notifier).impostaSpot(s.nome, s.ambiente);
            },
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _nuovoSpot(context, ref),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Nuovo spot'),
          ),
        ),
      ],
    );
  }
}

class _CampoData extends ConsumerWidget {
  const _CampoData(this.apertura);

  final AperturaPescata? apertura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(moduloPescataProvider(apertura).select((b) => b.data));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: const Text('Data'),
      subtitle: Text(formattaData(data)),
      trailing: const Icon(Icons.edit_calendar),
      onTap: () async {
        final oggi = ref.read(orologioProvider)();
        final scelta = await showDatePicker(
          context: context,
          initialDate: data,
          firstDate: DateTime(2000),
          lastDate: oggi,
        );
        if (scelta != null) ref.read(moduloPescataProvider(apertura).notifier).impostaData(scelta);
      },
    );
  }
}

class _Condizioni extends ConsumerWidget {
  const _Condizioni(this.apertura);

  final AperturaPescata? apertura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bozza = ref.watch(moduloPescataProvider(apertura));
    final ambiente = bozza.ambiente;
    if (ambiente == null) {
      return const Text('Scegli lo spot per vedere le condizioni del suo ambiente.');
    }
    return sezioneAsincrona(ref.watch(
      condizioniPerFormProvider((ambiente: ambiente, pescataId: bozza.originale?.id)),
    ), (condizioni) {
      if (condizioni.isEmpty) {
        return Text('Nessuna condizione prevista per l\'ambiente $ambiente.');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in condizioni) ...[
            Text(c.nome),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final v in c.valori)
                  ChoiceChip(
                    label: Text(v.nome),
                    selected: bozza.valori[c.id]?.id == v.id,
                    onSelected: (_) =>
                        ref.read(moduloPescataProvider(apertura).notifier).impostaValore(c, v),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ],
      );
    });
  }
}

class _Esche extends ConsumerStatefulWidget {
  const _Esche(this.apertura);

  final AperturaPescata? apertura;

  @override
  ConsumerState<_Esche> createState() => _EscheState();
}

class _EscheState extends ConsumerState<_Esche> {
  String _filtro = '';

  Future<void> _nuovaEsca(List<Esca> catalogo) async {
    final nome = await chiediNome(context, titolo: 'Nuova esca', etichetta: 'Nome dell\'esca');
    if (nome != null) {
      ref.read(moduloPescataProvider(widget.apertura).notifier).aggiungiEscaNuova(nome, catalogo);
    }
  }

  /// Seleziona o toglie un'esca. Togliere un'esca nuova, non ancora nel
  /// catalogo, la scarta: prima si chiede conferma.
  Future<void> _alterna(Esca esca, bool selezionata) async {
    if (esca.isNuovo && selezionata) {
      final conferma = await chiediConferma(
        context,
        titolo: 'Scartare l\'esca "${esca.nome}"?',
        messaggio: 'L\'esca "${esca.nome}" è nuova: entra nel catalogo solo salvando la pescata. '
            'Togliendola dalla selezione viene scartata.',
        conferma: 'Scarta',
      );
      if (!conferma) return;
    }
    ref.read(moduloPescataProvider(widget.apertura).notifier).alternaEsca(esca);
  }

  @override
  Widget build(BuildContext context) {
    final bozza = ref.watch(moduloPescataProvider(widget.apertura));
    return sezioneAsincrona<List<Esca>>(ref.watch(escheProvider), (catalogo) {
      // Le esche scritte ora (non ancora nel catalogo) compaiono per prime.
      final tutte = [
        ...bozza.esche.where((e) => e.isNuovo),
        ...catalogo,
      ];
      final filtro = _filtro.trim().toLowerCase();
      final visibili = filtro.isEmpty
          ? tutte
          : tutte.where((e) => e.nome.toLowerCase().contains(filtro)).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cerca esca',
              border: OutlineInputBorder(),
            ),
            onChanged: (testo) => setState(() => _filtro = testo),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '${bozza.esche.length} selezionate su ${tutte.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (visibili.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(tutte.isEmpty ? 'Nessuna esca nel catalogo.' : 'Nessuna esca trovata.'),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  shrinkWrap: true,
                  // Non è la lista principale: scorre solo se le esche non
                  // ci stanno, altrimenti il trascinamento passa al modulo.
                  primary: false,
                  children: [
                    for (final e in visibili)
                      CheckboxListTile(
                        dense: true,
                        value: bozza.contieneEsca(e),
                        title: Text(e.nome),
                        subtitle: e.isNuovo ? const Text('nuova') : null,
                        onChanged: (_) => _alterna(e, bozza.contieneEsca(e)),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _nuovaEsca(catalogo),
            icon: const Icon(Icons.add),
            label: const Text('Nuova esca'),
          ),
        ],
      );
    });
  }
}

class _SchedaCattura extends ConsumerStatefulWidget {
  const _SchedaCattura({super.key, required this.chiave, required this.apertura});

  final int chiave;
  final AperturaPescata? apertura;

  @override
  ConsumerState<_SchedaCattura> createState() => _SchedaCatturaState();
}

class _SchedaCatturaState extends ConsumerState<_SchedaCattura> {
  /// Cambia quando l'utente annulla la scelta di un'altra specie, per
  /// ridisegnare il menu con la specie di prima.
  int _versioneMenu = 0;

  int get chiave => widget.chiave;
  ModuloPescataNotifier get _modulo => ref.read(moduloPescataProvider(widget.apertura).notifier);

  /// Se l'azione scarta una specie nuova non ancora salvata, chiede conferma.
  Future<bool> _confermaScarto(String? scartata, String azione) async {
    if (scartata == null) return true;
    return chiediConferma(
      context,
      titolo: 'Scartare la specie "$scartata"?',
      messaggio: 'La specie "$scartata" è nuova: entra nel catalogo solo salvando la pescata '
          'con una sua cattura. $azione la specie viene scartata.',
      conferma: 'Scarta',
    );
  }

  Future<void> _scegliSpecie(String nome) async {
    final scartata = _modulo.specieScartata(chiave, altra: nome);
    if (await _confermaScarto(scartata, 'Scegliendo un\'altra specie')) {
      _modulo.impostaSpecie(chiave, nome);
    } else if (mounted) {
      setState(() => _versioneMenu++);
    }
  }

  Future<void> _rimuovi() async {
    final scartata = _modulo.specieScartata(chiave);
    if (await _confermaScarto(scartata, 'Togliendo la riga')) _modulo.rimuoviCattura(chiave);
  }

  Future<void> _nuovaSpecie(List<Specie> catalogo) async {
    final nome = await chiediNome(context, titolo: 'Nuova specie', etichetta: 'Nome della specie');
    if (nome == null || !mounted) return;
    final scartata = _modulo.specieScartata(chiave, altra: nome);
    if (await _confermaScarto(scartata, 'Scegliendo un\'altra specie')) {
      _modulo.aggiungiSpecieNuova(chiave, nome, catalogo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apertura = widget.apertura;
    final cattura = ref.watch(
      moduloPescataProvider(apertura).select((b) => _trova(b.catture, chiave)),
    );
    // La riga è appena stata tolta: la scheda sta per sparire.
    if (cattura == null) return const SizedBox.shrink();
    final nuoveSpecie = ref.watch(moduloPescataProvider(apertura).select((b) => b.nuoveSpecie));
    final modulo = _modulo;
    final specieNome = cattura.specieNome;
    final catalogo = ref.watch(specieProvider).value ?? const <Specie>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: sezioneAsincrona(ref.watch(specieProvider), (specie) {
                    return DropdownMenu<String>(
                      // Ricostruito quando la specie cambia (es. specie nuova)
                      // o quando l'utente annulla un cambio.
                      key: ValueKey('specie-$chiave-$specieNome-$_versioneMenu'),
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Specie'),
                      initialSelection: specieNome,
                      dropdownMenuEntries: [
                        for (final n in nuoveSpecie) DropdownMenuEntry(value: n, label: '$n (nuova)'),
                        for (final s in specie) DropdownMenuEntry(value: s.nome, label: s.nome),
                      ],
                      onSelected: (nome) {
                        if (nome != null && nome != specieNome) _scegliSpecie(nome);
                      },
                    );
                  }),
                ),
                IconButton(
                  tooltip: 'Togli questa specie',
                  onPressed: _rimuovi,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _nuovaSpecie(catalogo),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuova specie'),
              ),
            ),
            TextFormField(
              initialValue: cattura.totale == 0 ? '' : '${cattura.totale}',
              decoration: const InputDecoration(
                labelText: 'Totale catture',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (testo) => modulo.impostaTotale(chiave, int.tryParse(testo.trim()) ?? 0),
            ),
            if (specieNome != null)
              sezioneAsincrona(ref.watch(caratteristicheProvider(specieNome)), (caratteristiche) {
                if (caratteristiche.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Nessuna caratteristica definita per questa specie.'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        'Caratteristiche (facoltative): nessun valore può superare il totale.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    for (final car in caratteristiche)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(child: Text(car.nome)),
                            SizedBox(
                              width: 90,
                              child: TextFormField(
                                key: ValueKey('dettaglio-$chiave-${car.id}'),
                                initialValue: '${cattura.dettagli[car] ?? ''}',
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (testo) => modulo.impostaDettaglio(
                                  chiave,
                                  car,
                                  int.tryParse(testo.trim()) ?? 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

BozzaCattura? _trova(List<BozzaCattura> catture, int chiave) {
  for (final c in catture) {
    if (c.chiave == chiave) return c;
  }
  return null;
}
