import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine.dart';
import '../state.dart';
import '../util.dart';
import 'settings_screen.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending =
        state.allDue().where((d) => d.status != DueStatus.ok).length;

    final pages = <Widget>[
      const _VehiclesTab(),
      const _PendingTab(),
      const _HistoryTab(),
      const SettingsScreen(),
    ];
    const titles = ['Mes véhicules', 'À faire', 'Historique', 'Réglages'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: state.loaded
          ? pages[_tab]
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un véhicule'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car),
              label: 'Véhicules'),
          NavigationDestination(
            icon: Badge(
                isLabelVisible: pending > 0,
                label: Text('$pending'),
                child: const Icon(Icons.build_outlined)),
            selectedIcon: Badge(
                isLabelVisible: pending > 0,
                label: Text('$pending'),
                child: const Icon(Icons.build)),
            label: 'À faire',
          ),
          const NavigationDestination(
              icon: Icon(Icons.history), label: 'Historique'),
          const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Réglages'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _VehiclesTab extends StatelessWidget {
  const _VehiclesTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.vehicles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_filled,
                  size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('Aucun véhicule',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Ajoutez votre voiture pour recevoir des rappels '
                "d'entretien selon son kilométrage et son âge.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final v in state.vehicles)
          Builder(builder: (context) {
            final due = state.dueFor(v);
            final overdue =
                due.where((d) => d.status == DueStatus.overdue).length;
            final soon = due.where((d) => d.status == DueStatus.soon).length;
            return Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                title: Text(v.displayName),
                subtitle: Text(
                  '${fmtDist(v.odometerKm, state.settings)}'
                  '${v.plate != null && v.plate!.isNotEmpty ? ' · ${v.plate}' : ''}',
                ),
                trailing: overdue > 0
                    ? Chip(
                        label: Text('$overdue en retard'),
                        backgroundColor: Colors.red.shade100)
                    : (soon > 0
                        ? Chip(
                            label: Text('$soon bientôt'),
                            backgroundColor: Colors.orange.shade100)
                        : Chip(
                            label: const Text('À jour'),
                            backgroundColor: Colors.green.shade100)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => VehicleDetailScreen(vehicleId: v.id)),
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _PendingTab extends StatelessWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.vehicles.isEmpty) {
      return const Center(child: Text('Ajoutez d\'abord un véhicule.'));
    }
    final all = state.allDue();
    final overdue = all.where((d) => d.status == DueStatus.overdue).toList();
    final soon = all.where((d) => d.status == DueStatus.soon).toList();
    final ok = all.where((d) => d.status == DueStatus.ok).toList();

    Widget header(String text, Color c) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: c, fontSize: 15)),
        );

    return ListView(
      children: [
        if (overdue.isEmpty && soon.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Aucun entretien en attente. Tout est à jour !',
                textAlign: TextAlign.center),
          ),
        if (overdue.isNotEmpty) ...[
          header('En retard (${overdue.length})', Colors.red.shade700),
          for (final d in overdue) DueTile(info: d, showVehicle: true),
        ],
        if (soon.isNotEmpty) ...[
          header('À prévoir bientôt (${soon.length})', Colors.orange.shade800),
          for (final d in soon) DueTile(info: d, showVehicle: true),
        ],
        if (ok.isNotEmpty)
          ExpansionTile(
            title: Text('À venir (${ok.length})'),
            children: [
              for (final d in ok) DueTile(info: d, showVehicle: true),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String? _vehicleId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final vehicleId =
        (_vehicleId != null && state.vehicleById(_vehicleId!) != null)
            ? _vehicleId
            : null;
    final recs = state.recordsFor(vehicleId);
    final total = recs.fold<double>(0, (a, r) => a + (r.cost ?? 0));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: vehicleId,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Tous les véhicules')),
                    for (final v in state.vehicles)
                      DropdownMenuItem(value: v.id, child: Text(v.displayName)),
                  ],
                  onChanged: (v) => setState(() => _vehicleId = v),
                ),
              ),
              IconButton(
                tooltip: 'Exporter en CSV',
                icon: const Icon(Icons.ios_share),
                onPressed: recs.isEmpty
                    ? null
                    : () => state.exportCsv(vehicleId),
              ),
            ],
          ),
        ),
        if (recs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${recs.length} entretien(s) · total ${fmtMoney(total)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        Expanded(
          child: recs.isEmpty
              ? const Center(child: Text("Aucun entretien enregistré."))
              : ListView.separated(
                  itemCount: recs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = recs[i];
                    final v = state.vehicleById(r.vehicleId);
                    return Dismissible(
                      key: ValueKey(r.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async =>
                          await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Supprimer cet entretien ?'),
                              content: const Text(
                                  "L'échéance du prochain entretien sera recalculée."),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Annuler')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Supprimer')),
                              ],
                            ),
                          ) ??
                          false,
                      onDismissed: (_) => state.deleteRecord(r.id),
                      child: ListTile(
                        leading: const Icon(Icons.task_alt),
                        title: Text(r.itemName),
                        subtitle: Text([
                          if (vehicleId == null && v != null) v.displayName,
                          '${fmtDate(r.date)} · ${fmtDist(r.km, state.settings)}',
                          if (r.shop != null) r.shop!,
                          if (r.notes != null) r.notes!,
                        ].join('\n')),
                        isThreeLine: true,
                        trailing: r.cost != null ? Text(fmtMoney(r.cost!)) : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
