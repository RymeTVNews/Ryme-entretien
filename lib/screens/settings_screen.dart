import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../access.dart';
import '../config.dart';
import '../notifications.dart';
import '../state.dart';
import '../util.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final time = TimeOfDay(hour: s.hour, minute: s.minute);

    return ListView(
      children: [
        const _AccountSection(),
        const Divider(),
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


class _AccountSection extends StatelessWidget {
  const _AccountSection();

  Future<void> _confirmDelete(BuildContext context) async {
    final access = context.read<AccessController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte ?'),
        content: const Text(
            'Votre compte et les données de cet appareil (véhicules, '
            'historique, réglages) seront supprimés définitivement. '
            'Cette action est irréversible. Un achat déjà effectué reste '
            'associé à votre compte Google Play.'),
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
    if (ok != true) return;
    final err = await access.deleteAccount();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessController>();
    String statusText;
    switch (access.status) {
      case AccessStatus.premium:
        statusText = 'Version complète (achat effectué)';
        break;
      case AccessStatus.trial:
        statusText =
            'Essai gratuit : ${access.daysLeft} jour${access.daysLeft > 1 ? 's' : ''} restant${access.daysLeft > 1 ? 's' : ''}';
        break;
      case AccessStatus.devMode:
        statusText = 'Mode développement (connexion et achat non configurés)';
        break;
      default:
        statusText = '';
    }
    final isDev = access.status == AccessStatus.devMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section('Compte'),
        if (!isDev)
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(access.identifier.isEmpty ? 'Connecté' : access.identifier),
            subtitle: Text(statusText),
          )
        else
          ListTile(
            leading: const Icon(Icons.developer_mode),
            title: Text(statusText),
          ),
        if (!isDev && access.status == AccessStatus.trial)
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Acheter la version complète'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PaywallScreen(canClose: true)),
            ),
          ),
        if (!isDev && access.status != AccessStatus.premium)
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restaurer mon achat'),
            onTap: access.busy ? null : access.restore,
          ),
        if (!isDev)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            onTap: access.signOut,
          ),
        if (!isDev)
          ListTile(
            leading: Icon(Icons.delete_forever,
                color: Theme.of(context).colorScheme.error),
            title: Text('Supprimer mon compte',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _confirmDelete(context),
          ),
        if (AppConfig.privacyUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(
                'Politique de confidentialité : ${AppConfig.privacyUrl}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        if (AppConfig.deletionUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SelectableText(
                'Demande de suppression en ligne : ${AppConfig.deletionUrl}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        if (AppConfig.supportEmail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SelectableText('Assistance : ${AppConfig.supportEmail}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}
