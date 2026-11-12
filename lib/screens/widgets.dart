import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine.dart';
import '../models.dart';
import '../state.dart';
import '../util.dart';

Color statusColor(BuildContext context, DueStatus s) {
  switch (s) {
    case DueStatus.overdue:
      return Colors.red.shade700;
    case DueStatus.soon:
      return Colors.orange.shade800;
    case DueStatus.ok:
      return Colors.green.shade700;
  }
}

String statusLabel(DueStatus s) {
  switch (s) {
    case DueStatus.overdue:
      return 'En retard';
    case DueStatus.soon:
      return 'Bientôt';
    case DueStatus.ok:
      return 'À jour';
  }
}

class DueTile extends StatelessWidget {
  final DueInfo info;
  final bool showVehicle;
  const DueTile({super.key, required this.info, this.showVehicle = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final color = statusColor(context, info.status);
    return ListTile(
      leading: Icon(
        info.status == DueStatus.ok
            ? Icons.check_circle_outline
            : Icons.build_circle_outlined,
        color: color,
      ),
      title: Text(info.item.name),
      subtitle: Text([
        if (showVehicle) info.vehicle.displayName,
        describeDue(info, state.settings),
      ].join('\n')),
      isThreeLine: showVehicle,
      trailing: TextButton(
        onPressed: () => showServiceDialog(
          context,
          vehicle: info.vehicle,
          item: info.item,
        ),
        child: const Text('Valider'),
      ),
    );
  }
}

/// Boîte de dialogue de validation d'un entretien (ou d'ajout d'un entretien
/// ponctuel quand [item] est null).
Future<void> showServiceDialog(
  BuildContext context, {
  required Vehicle vehicle,
  ScheduleItem? item,
}) async {
  final state = context.read<AppState>();
  final s = state.settings;
  final nameC = TextEditingController(text: item?.name ?? '');
  final kmC = TextEditingController(
      text: toDisplayDist(vehicle.odometerKm, s).toString());
  final costC = TextEditingController();
  final shopC = TextEditingController();
  final notesC = TextEditingController();
  var date = dateOnly(DateTime.now());
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(item == null ? 'Entretien effectué' : 'Valider l\'entretien'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameC,
                  readOnly: item != null,
                  decoration: const InputDecoration(labelText: 'Entretien'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(fmtDate(date)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setLocal(() => date = picked);
                  },
                ),
                TextFormField(
                  controller: kmC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Kilométrage (${unitLabel(s)})'),
                  validator: (v) =>
                      int.tryParse((v ?? '').trim()) == null ? 'Nombre requis' : null,
                ),
                TextFormField(
                  controller: costC,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Coût (optionnel)'),
                ),
                TextFormField(
                  controller: shopC,
                  decoration:
                      const InputDecoration(labelText: 'Garage (optionnel)'),
                ),
                TextFormField(
                  controller: notesC,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optionnel)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final km = fromDisplayDist(int.parse(kmC.text.trim()), s);
              final cost = double.tryParse(costC.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx);
              await state.completeService(
                vehicle: vehicle,
                item: item,
                name: nameC.text.trim(),
                date: date,
                km: km,
                cost: cost,
                shop: shopC.text.trim().isEmpty ? null : shopC.text.trim(),
                notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
}

/// Boîte de dialogue de mise à jour du kilométrage.
Future<void> showOdometerDialog(BuildContext context, Vehicle v) async {
  final state = context.read<AppState>();
  final s = state.settings;
  final c = TextEditingController(text: toDisplayDist(v.odometerKm, s).toString());
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mettre à jour le kilométrage'),
      content: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(labelText: 'Compteur (${unitLabel(s)})'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            final n = int.tryParse(c.text.trim());
            if (n == null) return;
            final err = await state.updateOdometer(v, fromDisplayDist(n, s));
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (err != null && context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(err)));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}
