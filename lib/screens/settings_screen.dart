import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notifications.dart';
import '../state.dart';
import '../util.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final time = TimeOfDay(hour: s.hour, minute: s.minute);

    return ListView(
      children: [
        const _Section('Notifications'),
        SwitchListTile(
          title: const Text('Activer les rappels'),
          subtitle: const Text("Notifications automatiques d'entretien"),
          value: s.notificationsEnabled,
          onChanged: (v) async {
            if (v) {
              final ok = await NotificationService.requestPermission();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Autorisation refusée : activez les notifications dans les réglages du téléphone.')));
              }
            }
            s.notificationsEnabled = v;
            await state.saveSettings();
          },
        ),
        ListTile(
          title: const Text('Heure des rappels'),
          subtitle: Text(time.format(context)),
          trailing: const Icon(Icons.schedule),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) {
              s.hour = t.hour;
              s.minute = t.minute;
              await state.saveSettings();
            }
          },
        ),
        ListTile(
          title: const Text("Préavis (jours)"),
          subtitle: Text('${s.leadDays} jours avant la date d\'échéance'),
        ),
        Slider(
          value: s.leadDays.toDouble(),
          min: 1,
          max: 60,
          divisions: 59,
          label: '${s.leadDays}',
          onChanged: (v) {
            s.leadDays = v.round();
            state.touch();
          },
          onChangeEnd: (_) => state.saveSettings(),
        ),
        ListTile(
          title: Text('Préavis (${unitLabel(s)})'),
          subtitle: Text(
              '${fmtDist(s.leadKm, s)} avant le kilométrage d\'échéance'),
        ),
        Slider(
          value: s.leadKm.toDouble().clamp(100.0, 3000.0).toDouble(),
          min: 100,
          max: 3000,
          divisions: 29,
          label: '${s.leadKm}',
          onChanged: (v) {
            s.leadKm = v.round();
            state.touch();
          },
          onChangeEnd: (_) => state.saveSettings(),
        ),
        SwitchListTile(
          title: const Text('Rappel mensuel du kilométrage'),
          subtitle: const Text(
              'Le 1er de chaque mois : pensez à mettre le compteur à jour'),
          value: s.odometerReminder,
          onChanged: (v) {
            s.odometerReminder = v;
            state.saveSettings();
          },
        ),
        SwitchListTile(
          title: const Text('Pneus saisonniers'),
          subtitle: const Text(
              "Rappels le 15 novembre (pneus d'hiver) et le 16 mars (pneus d'été)"),
          value: s.seasonalTires,
          onChanged: (v) {
            s.seasonalTires = v;
            state.saveSettings();
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Envoyer une notification de test'),
          onTap: () async {
            final ok = await NotificationService.requestPermission();
            if (ok) {
              await NotificationService.showNow(
                  'Ryme entretien', 'Les notifications fonctionnent.');
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Notifications non autorisées sur cet appareil.')));
            }
          },
        ),
        const Divider(),
        const _Section('Unités'),
        ListTile(
          title: const Text('Distance'),
          trailing: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('km')),
              ButtonSegment(value: true, label: Text('mi')),
            ],
            selected: {s.useMiles},
            onSelectionChanged: (v) {
              s.useMiles = v.first;
              state.saveSettings();
            },
          ),
        ),
        const Divider(),
        const _Section('À propos'),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Text(
            "Les données sont stockées localement sur votre appareil. "
            "Les intervalles d'entretien fournis sont indicatifs : référez-vous "
            "toujours au manuel du propriétaire et aux recommandations de votre "
            "concessionnaire, notamment pour les véhicules sous garantie.",
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );
}
