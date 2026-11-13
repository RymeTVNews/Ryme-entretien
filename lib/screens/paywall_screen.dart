import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../access.dart';
import '../config.dart';

/// Écran d'achat. [canClose] = vrai quand on l'ouvre pendant l'essai ;
/// faux quand l'essai est terminé (blocage de l'application).
class PaywallScreen extends StatelessWidget {
  final bool canClose;
  const PaywallScreen({super.key, this.canClose = false});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessController>();
    final scheme = Theme.of(context).colorScheme;
    final unlocked = access.premium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ryme entretien'),
        automaticallyImplyLeading: canClose,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(unlocked ? Icons.verified : Icons.lock_outline,
                size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              unlocked
                  ? 'Merci ! Votre abonnement est actif.'
                  : (canClose
                      ? 'Débloquez Ryme entretien'
                      : 'Votre essai gratuit est terminé'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (!unlocked) ...[
              const Text(
                "Abonnement annuel : accès illimité à tous les véhicules, aux "
                "rappels automatiques et à l'historique d'entretien. Vos "
                "données sont conservées.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        access.product?.price ?? '5,00 \$ CA',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const Text('par an'),
                      const SizedBox(height: 8),
                      Text(
                        "Prix de base : 5,00 \$ CA par an. Hors du Canada, Google "
                        "Play affiche le prix converti dans votre devise selon "
                        "le taux de change en vigueur. L'abonnement est facturé "
                        "à la souscription, puis chaque année, et se renouvelle "
                        "automatiquement jusqu'à son annulation. Annulation à "
                        "tout moment dans Google Play → Paiements et "
                        "abonnements → Abonnements.",
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: access.busy ? null : access.buy,
                icon: access.busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.credit_card),
                label: const Text("S'abonner"),
              ),
              const SizedBox(height: 4),
              Text(
                'Paiement sécurisé par Google Play (carte bancaire, Google Pay…).',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: access.busy ? null : access.restore,
                child: const Text('Restaurer mon abonnement'),
              ),
              if (!access.storeAvailable || access.product == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Text(
                        "La boutique Google Play n'est pas disponible pour le "
                        'moment (connexion, ou application non installée depuis '
                        'Google Play).',
                        style: TextStyle(color: scheme.error),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                          onPressed: access.loadStore,
                          child: const Text('Réessayer')),
                    ],
                  ),
                ),
              if (access.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(access.message!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center),
                ),
            ] else if (canClose)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continuer'),
              ),
            if (!canClose && !unlocked) ...[
              const Divider(height: 32),
              Text(access.identifier,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              TextButton(
                  onPressed: access.signOut,
                  child: const Text('Se déconnecter')),
            ],
            if (AppConfig.privacyUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  'Politique de confidentialité : ${AppConfig.privacyUrl}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
