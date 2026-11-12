import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../util.dart';
import 'schedule_editor_screen.dart';
import 'vehicle_form_screen.dart';
import 'widgets.dart';

class VehicleDetailScreen extends StatelessWidget {
  final String vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final v = state.vehicleById(vehicleId);
    if (v == null) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: Text('Véhicule supprimé')));
    }
    final s = state.settings;
    final due = state.dueFor(v);
    final recs = state.recordsFor(v.id);

    Widget spec(String label, String? value) => value == null || value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 120,
                    child: Text(label,
                        style: Theme.of(context).textTheme.bodySmall)),
                Expanded(child: Text(value)),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text('${v.make} ${v.model}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (a) async {
              if (a == 'edit') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => VehicleFormScreen(vehicle: v)));
              } else if (a == 'schedule') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ScheduleEditorScreen(vehicleId: v.id)));
              } else if (a == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer ce véhicule ?'),
                    content: const Text(
                        "Le véhicule et tout son historique d'entretien seront supprimés."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Supprimer')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  final nav = Navigator.of(context);
                  await state.deleteVehicle(v.id);
                  nav.pop();
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier le véhicule')),
              PopupMenuItem(
                  value: 'schedule', child: Text("Calendrier d'entretien")),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fmtDist(v.odometerKm, s),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            Text('mis à jour le ${fmtDate(v.odometerDate)}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => showOdometerDialog(context, v),
                        icon: const Icon(Icons.speed),
                        label: const Text('Mettre à jour'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  spec('Année', '${v.year}'),
                  spec('Version', v.trim),
                  spec('Carburant', fuelLabel(v.fuel)),
                  spec('Transmission', transmissionLabel(v.transmission)),
                  spec('Plaque', v.plate),
                  spec('NIV', v.vin),
                  spec('Usage annuel',
                      '${fmtDist(v.annualKm, s)}/an${v.severeUse ? ' · conditions sévères' : ''}'),
                  spec('Notes', v.notes),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Les intervalles proposés sont indicatifs (selon la marque). "
                    "Validez-les avec le manuel du propriétaire de votre véhicule "
                    "et ajustez-les au besoin dans « Calendrier d'entretien ».",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Entretiens à venir',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: () => showServiceDialog(context, vehicle: v),
                  icon: const Icon(Icons.add_task),
                  label: const Text('Entretien déjà effectué'),
                ),
              ],
            ),
          ),
          if (due.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Aucun entretien dans le calendrier."),
            ),
          for (final d in due) DueTile(info: d),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text("Historique d'entretien",
                style: Theme.of(context).textTheme.titleMedium),
          ),
          if (recs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Aucun entretien enregistré pour ce véhicule."),
            ),
          for (final r in recs)
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: Text(r.itemName),
              subtitle: Text(
                  '${fmtDate(r.date)} · ${fmtDist(r.km, s)}${r.shop != null ? '\n${r.shop}' : ''}'),
              isThreeLine: r.shop != null,
              trailing: r.cost != null ? Text(fmtMoney(r.cost!)) : null,
            ),
        ],
      ),
    );
  }
}
