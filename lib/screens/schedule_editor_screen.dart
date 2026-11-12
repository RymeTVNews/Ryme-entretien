import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../util.dart';

/// Permet d'activer/désactiver, d'ajuster ou d'ajouter des entretiens au
/// calendrier d'un véhicule.
class ScheduleEditorScreen extends StatelessWidget {
  final String vehicleId;
  const ScheduleEditorScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final v = state.vehicleById(vehicleId);
    if (v == null) return const Scaffold(body: SizedBox.shrink());
    final s = state.settings;

    String intervalText(ScheduleItem it) {
      final p = <String>[];
      if (it.intervalKm != null) p.add('tous les ${fmtDist(it.intervalKm!, s)}');
      if (it.intervalMonths != null) p.add('tous les ${it.intervalMonths} mois');
      return p.isEmpty ? 'Aucun intervalle' : p.join(' ou ');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Calendrier d'entretien"),
        actions: [
          IconButton(
            tooltip: 'Réinitialiser selon le catalogue',
            icon: const Icon(Icons.restore),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Réinitialiser le calendrier ?'),
                  content: const Text(
                      'Les intervalles seront remplacés par ceux du catalogue. '
                      "L'historique est conservé."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Réinitialiser')),
                  ],
                ),
              );
              if (ok == true) await state.resetSchedule(v);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editItem(context, v, null),
        icon: const Icon(Icons.add),
        label: const Text('Entretien personnalisé'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final it in v.schedule)
            SwitchListTile(
              value: it.enabled,
              title: Text(it.name),
              subtitle: Text(
                  '${it.category} · ${intervalText(it)}${it.note != null ? '\n${it.note}' : ''}'),
              isThreeLine: it.note != null,
              onChanged: (val) {
                it.enabled = val;
                state.updateVehicle(v);
              },
              secondary: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editItem(context, v, it),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editItem(
      BuildContext context, Vehicle v, ScheduleItem? existing) async {
    final state = context.read<AppState>();
    final s = state.settings;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final kmC = TextEditingController(
        text: existing?.intervalKm == null
            ? ''
            : toDisplayDist(existing!.intervalKm!, s).toString());
    final monthsC = TextEditingController(
        text: existing?.intervalMonths?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nouvel entretien' : 'Modifier'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameC,
                readOnly: existing != null && !existing.custom,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (t) =>
                    (t == null || t.trim().isEmpty) ? 'Requis' : null,
              ),
              TextFormField(
                controller: kmC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Tous les (${unitLabel(s)}) — optionnel'),
                validator: (t) {
                  if (t == null || t.trim().isEmpty) return null;
                  final n = int.tryParse(t.trim());
                  return (n == null || n <= 0) ? 'Nombre invalide' : null;
                },
              ),
              TextFormField(
                controller: monthsC,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Tous les (mois) — optionnel'),
                validator: (t) {
                  if (t == null || t.trim().isEmpty) return null;
                  final n = int.tryParse(t.trim());
                  return (n == null || n <= 0) ? 'Nombre invalide' : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final km = kmC.text.trim().isEmpty
                  ? null
                  : fromDisplayDist(int.parse(kmC.text.trim()), s);
              final months = monthsC.text.trim().isEmpty
                  ? null
                  : int.parse(monthsC.text.trim());
              if (km == null && months == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Indiquez au moins un intervalle.')));
                return;
              }
              Navigator.pop(ctx);
              if (existing == null) {
                v.schedule.add(ScheduleItem(
                  id: 'custom_${newId()}',
                  name: nameC.text.trim(),
                  category: 'Personnalisé',
                  intervalKm: km,
                  intervalMonths: months,
                  custom: true,
                ));
              } else {
                if (existing.custom) existing.name = nameC.text.trim();
                existing.intervalKm = km;
                existing.intervalMonths = months;
              }
              await state.updateVehicle(v);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
