/// Configuration de l'application.
///
/// Les valeurs Firebase et les liens ne sont PAS écrits dans le code : ils
/// sont fournis à la compilation avec `--dart-define` (la CI les lit dans les
/// secrets GitHub). Sans configuration Firebase, l'application démarre en
/// « mode développement » : aucune connexion, aucun achat, tout est débloqué.
class AppConfig {
  /// Durée de l'essai gratuit.
  static const int trialDays = 7;

  /// true : l'essai de 7 jours est une offre NATIVE de Google Play sur
  /// l'abonnement (carte exigée dès le début, facturation automatique au
  /// 8e jour sauf annulation). false : essai compté dans l'application,
  /// depuis la création du compte, sans carte.
  static const bool nativeTrial = true;

  /// Identifiant de l'ABONNEMENT annuel créé dans Play Console
  /// (Monétiser → Produits → Abonnements). Forfait de base annuel,
  /// renouvellement automatique, prix de base : 5,00 CAD par an.
  static const String productId = 'ryme_entretien_annuel';

  /// Si Google Play n'a pas pu être interrogé (hors ligne), la dernière
  /// confirmation d'abonnement actif reste valable ce nombre de jours.
  static const int entitlementGraceDays = 7;

  static const String firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseAppId =
      String.fromEnvironment('FIREBASE_APP_ID');
  static const String firebaseSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');

  /// Politique de confidentialité et page de demande de suppression de compte
  /// (liens publics exigés par Google Play).
  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL');
  static const String deletionUrl = String.fromEnvironment('DELETION_URL');
  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  static bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
