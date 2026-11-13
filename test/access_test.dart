import 'package:flutter_test/flutter_test.dart';
import 'package:ryme_entretien/access.dart';

void main() {
  final created = DateTime(2026, 11, 1, 12);

  AccessDecision d(
    DateTime now, {
    bool signedIn = true,
    bool premium = false,
    DateTime? createdAt,
  }) =>
      decideAccess(
        signedIn: signedIn,
        accountCreated: createdAt ?? created,
        now: now,
        premium: premium,
      );

  test('sans connexion : écran de connexion, même si achat en cache', () {
    expect(d(created, signedIn: false).status, AccessStatus.signedOut);
    expect(d(created, signedIn: false, premium: true).status,
        AccessStatus.signedOut);
  });

  test("le jour de l'inscription : 7 jours d'essai", () {
    final r = d(created);
    expect(r.status, AccessStatus.trial);
    expect(r.daysLeft, 7);
  });

  test('dernier jour : 1 jour restant', () {
    final r = d(created.add(const Duration(days: 6, hours: 12)));
    expect(r.status, AccessStatus.trial);
    expect(r.daysLeft, 1);
  });

  test('après 7 jours : accès bloqué', () {
    expect(d(created.add(const Duration(days: 7))).status, AccessStatus.expired);
    expect(d(created.add(const Duration(days: 30))).status, AccessStatus.expired);
  });

  test('essai natif Play (0 jour dans l\'application) : bloqué sans abonnement', () {
    final r = decideAccess(
        signedIn: true,
        accountCreated: created,
        now: created,
        premium: false,
        trialDays: 0);
    expect(r.status, AccessStatus.expired);
  });

  test("l'achat débloque l'application après l'essai", () {
    final r = d(created.add(const Duration(days: 30)), premium: true);
    expect(r.status, AccessStatus.premium);
  });

  group("validité de l'abonnement", () {
    final now = DateTime(2026, 11, 20);

    test('jamais confirmé : inactif', () {
      expect(entitlementValid(verifiedAt: null, now: now), isFalse);
    });

    test('confirmé il y a 2 jours : actif', () {
      expect(
          entitlementValid(
              verifiedAt: now.subtract(const Duration(days: 2)), now: now),
          isTrue);
    });

    test('confirmé il y a 8 jours (hors ligne) : inactif', () {
      expect(
          entitlementValid(
              verifiedAt: now.subtract(const Duration(days: 8)), now: now),
          isFalse);
    });

    test('confirmation datée du futur (horloge reculée) : inactif', () {
      expect(
          entitlementValid(
              verifiedAt: now.add(const Duration(days: 1)), now: now),
          isFalse);
    });
  });

  test("date de création inconnue : essai complet", () {
    final r = decideAccess(
      signedIn: true,
      accountCreated: null,
      now: created,
      premium: false,
    );
    expect(r.status, AccessStatus.trial);
    expect(r.daysLeft, 7);
  });
}
