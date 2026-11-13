# Ryme entretien — notes de projet (à conserver)

Document de référence pour améliorer, modifier et mettre à niveau l'application. Dernière mise à jour : 2026-11-12.

## 1. Vue d'ensemble
- **But** : rappels automatiques d'entretien automobile (notifications locales), suivi par kilométrage et par date, historique, validation des entretiens effectués.
- **Technologie** : Flutter (un seul code pour Android et iOS), données stockées localement (`shared_preferences`, JSON), aucun serveur.
- **Dépôt GitHub** : https://github.com/RymeTVNews/Ryme-entretien (branche `main`).
- **Nom affiché** : « Ryme entretien ». Paquet Dart : `ryme_entretien`. Identifiant d'application : `com.ryme.ryme_entretien` (généré par `flutter create --org com.ryme`).
- **Version d'essai web** (démo dans le navigateur, sans notifications en arrière-plan) : https://claude.ai/artifact/ScmHVyYzFzJAqUrjH5qE7F (artefact « Ryme entretien », page HTML autonome équivalente à la logique de l'app).

## 2. Compiler et installer
- Les dossiers `android/` et `ios/` ne sont PAS versionnés (listés dans `.gitignore`). Ils sont générés par `python3 tool/setup_platforms.py` (qui lance `flutter create`, puis applique les réglages de notifications). Le script est idempotent.
- **CI** : `.github/workflows/build.yml` (à chaque push) : génère les plateformes, `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test`, `flutter build apk --release`, publie l'artefact `ryme-entretien-apk`. Un job iOS compile sans signature (vérification seulement).
- **Récupérer l'APK** : GitHub → Actions → dernier lancement réussi → « Artifacts » → `ryme-entretien-apk` (zip contenant `app-release.apk`). Sur Android : ouvrir l'APK, autoriser l'installation depuis la source.
- L'APK de la CI est signé avec la clé de debug de Flutter : suffisant pour l'essai, mais **pas publiable sur Google Play** (voir §7).
- Le build iOS n'est pas signé : il faut un Mac, Xcode et un compte Apple Developer pour installer sur un iPhone ou publier sur l'App Store.

## 3. Structure du code
```
lib/models.dart         Vehicle, ScheduleItem, ServiceRecord, OdoLog, AppSettings (+ JSON)
lib/catalog.dart        calendriers par marque / carburant / transmission, kModelOverrides
lib/engine.dart         computeDue : échéances (km + date), statuts, kmPerDay, describeDue
lib/notifications.dart  buildPlan (plan de notifications) + NotificationService (local)
lib/state.dart          AppState (ChangeNotifier), stockage, replan(), export CSV (texte), eraseAll()
lib/config.dart         durée d'essai (7 j), id du produit, valeurs Firebase/liens via --dart-define
lib/access.dart         AccessController : compte Firebase (courriel), essai, abonnement Google Play, suppression de compte
lib/screens/auth_screen.dart, paywall_screen.dart   compte par courriel et abonnement annuel
PLAY_STORE.md           guide complet de mise en ligne (Play Console, Firebase, signature, secrets)
docs/                   modèles HTML : politique de confidentialité, suppression de compte
lib/util.dart           unités km/mi, formats, addMonths
lib/screens/            home (4 onglets), détail véhicule, formulaire, éditeur de calendrier, réglages, widgets partagés
test/engine_test.dart   6 tests du moteur et du plan de notifications
tool/setup_platforms.py génération android/ios + réglages natifs
```

## 4. Logique métier à connaître
- **Échéance d'un entretien** = dernière validation de cet entretien (`itemId`) sinon point de départ du véhicule (`acquiredKm`, `acquiredDate`). Échéance km = base + intervalle ; échéance date = base + N mois. Dû au premier des deux.
- **Statuts** : `overdue` (km restants ≤ 0 ou jours ≤ 0), `soon` (km restants ≤ préavis km ou jours ≤ préavis jours), sinon `ok`. Défauts : préavis 14 jours, 1000 km.
- **Date estimée pour un entretien par km** : kilométrage restant / rythme journalier. Rythme = historique du compteur (≥ 2 relevés espacés d'au moins 14 jours), sinon usage annuel déclaré / 365 ; minimum 5 km/jour ; plafond 3650 jours.
- **Conditions sévères** : multiplie par 0,6 l'intervalle en km des entretiens marqués `severeSensitive` (huile, filtre à air, huile de transmission). Les intervalles en mois ne changent pas.
- **Notifications** : à chaque modification, `replan()` annule tout et reprogramme (max 60, car iOS limite à 64 en attente). En retard → rappel hebdomadaire à l'heure choisie ; bientôt → une fois (prochaine occurrence de l'heure choisie) ; à jour → une fois, préavis-jours avant l'échéance effective. S'y ajoutent : rappel mensuel du compteur (le 1er) et rappels de pneus saisonniers optionnels (15 nov. et 16 mars, annuels).
- **Stockage** : clé `data_v1` dans `shared_preferences`, un seul JSON `{vehicles, records, settings}`. Si le format change, prévoir une migration (`data_v2`) plutôt que casser la lecture : `fromJson` tolère déjà les champs manquants avec des valeurs par défaut.
- **Unités** : tout est stocké en km ; conversion à l'affichage et à la saisie (`toDisplayDist`, `fromDisplayDist`).
- **Langue** : interface en français seulement (locale `fr` initialisée dans `main.dart`). Les tests doivent appeler `initializeDateFormatting('fr')`.

## 4 bis. Modèle économique et accès (mis à jour le 2026-11-13)
- **Décision** : application gratuite à télécharger + **abonnement annuel** `ryme_entretien_annuel` (forfait de base `annuel`, renouvellement automatique) à **5,00 CAD par an** (Google Play Billing) ; essai gratuit de 7 jours NATIF de Google Play (offre `essai7j` sur le forfait `annuel`, carte exigée, prélèvement au 8e jour ; interrupteur `AppConfig.nativeTrial`). Historique : essai compté dans l'application sans carte (conservé dans le code, `nativeTrial = false`). Historique : une première version prévoyait un achat unique de 5 $ ; remplacée par l'abonnement annuel à la demande de l'utilisateur.
- **Compte par courriel seulement** (Firebase Authentication, courriel + mot de passe ; connexion par téléphone retirée → plus besoin du forfait Firebase Blaze ni des empreintes SHA). (Mode essai interne : démarre à `user.metadata.creationTime`, heure serveur.)
- **Règle d'accès** (`decideAccess`, testée) : non connecté → écran de connexion ; connecté + abonnement actif → accès ; connecté sans abonnement et < 7 jours → essai (bandeau) ; sinon écran d'abonnement bloquant. Notifications coupées quand l'accès est bloqué (`AppState.allowNotifications`).
- **Abonnement actif** (`entitlementValid`, testée) : à chaque ouverture et au plus 1 fois/heure, `restorePurchases()` interroge Google Play (un abonnement expiré n'est plus renvoyé). Confirmation mémorisée (`premium_verified_ms`) valable 7 jours si Google Play ne répond pas (hors ligne). L'achat doit être acquitté (`completePurchase`) sinon remboursement automatique après 3 jours.
- **Anti-triche horloge** : décalage mesuré avec `getIdTokenResult(true).issuedAtTime` + mémorisation de la dernière heure vue (on ne peut pas reculer la date).
- **Mode développement** : sans valeurs Firebase (`--dart-define`), pas de connexion ni d'abonnement, tout est débloqué. Les builds de la CI sans secrets GitHub sont donc en mode développement.
- **Devises** : prix de base CAD dans Play Console ; Google convertit par pays et l'application affiche `ProductDetails.price` (déjà localisé). Commission Google : 15 % sur les abonnements à renouvellement automatique (vérifier le barème en vigueur).
- **Compte bancaire de versement** : géré uniquement dans le profil de paiements de Play Console, jamais dans l'application ni dans le dépôt.
- **Suppression de compte** : dans l'application (Réglages → Compte) + page web (`docs/suppression-compte.html`), exigées par Google Play. Elle n'annule pas l'abonnement (message affiché à l'utilisateur).
- Choix de l'utilisateur (2026-11-13) : essai natif Play plutôt que l'essai dans l'application. Le code choisit l'offre avec phase à 0 (`pickOffer`) ; sans droit à l'essai, l'abonnement normal est proposé.

## 5. Limites connues
- **Données des fabricants** : aucune base ouverte et gratuite des calendriers officiels par modèle et par année. Le catalogue donne des intervalles INDICATIFS par marque (huile : 8 000 km / 6 mois pour la plupart, 12 000 km / 12 mois pour GM, 15 000 km / 12 mois pour les marques allemandes et Volvo). Toujours à valider avec le manuel du propriétaire. L'application affiche cet avertissement.
- **Pas de calendrier propre à chaque modèle** : `kModelOverrides` (clé `marque|modèle` en minuscules, valeurs par id d'entretien) est vide, à remplir avec les données du manuel.
- **Pas de sauvegarde ni de synchronisation** : désinstaller l'application efface les données. Pas d'import, seulement un export CSV (copie dans le presse-papiers).
- Notifications programmées avec `AndroidScheduleMode.inexactAllowWhileIdle` : l'heure peut varier de quelques minutes ; certaines marques de téléphones (économie de batterie agressive) peuvent retarder ou bloquer les rappels.
- Fuseau horaire : détecté sans plugin en cherchant un fuseau IANA dont les décalages saisonniers correspondent à ceux de l'appareil (`_detectLocation`). Approximation fiable pour l'heure locale, mais le nom du fuseau peut différer du vrai (ex. un voisin avec les mêmes règles).
- Jamais testée sur un vrai téléphone au moment de cette note (compilation, analyse et tests de la CI réussis). Création de compte et abonnement réel non testés (ils demandent vos comptes Firebase et Google Play).
- **Abonnement vérifié côté appareil seulement** : état lu depuis Google Play et mis en cache 7 jours ; un abonnement annulé/remboursé peut rester actif jusqu'à 7 jours hors ligne ; appareils modifiés contournables. L'abonnement suit le compte Google Play, pas le compte courriel. Amélioration : vérification serveur (API Google Play Developer + Cloud Functions + notifications temps réel).
- **Comptes multiples** : on peut créer d'autres comptes pour renouveler l'essai.
- **iOS** : pas d'achat intégré configuré (il faudrait StoreKit via `in_app_purchase`, un produit App Store Connect et un compte Apple Developer).

## 6. Historique des problèmes rencontrés (pour ne pas les refaire)
1. `flutter create` génère `test/widget_test.dart` qui référence `MyApp` : il faisait échouer `flutter analyze`. Le script `setup_platforms.py` le supprime.
2. Test de plan de notifications : `LocaleDataException` → appeler `initializeDateFormatting('fr')` dans `setUpAll`.
3. **Compilation Android** : le plugin `flutter_timezone` 3.x échouait (« Inconsistent JVM Target Compatibility », Kotlin 1.8 vs Java 11) avec le Flutter stable récent (3.50 sur la CI). `share_plus` et `flutter_timezone` appliquent le plugin Kotlin (KGP) ; Flutter annonce que les futures versions refuseront de compiler avec de tels plugins. Solution retenue : retirer `flutter_timezone`, `share_plus` et `path_provider`. Leur remplacement : détection du fuseau interne, export CSV via `Clipboard`.
4. `flutter analyze` (Flutter récent) signale en « info » : `package:flutter/material.dart` déprécié au profit de `material_ui`, et `value` déprécié au profit de `initialValue` dans `DropdownButtonFormField`. Ce ne sont pas des erreurs ; la CI utilise `--no-fatal-infos`. À migrer lors d'une mise à niveau.
5. `flutter_local_notifications` ^17 exige le desugaring Java 8+ (ajouté par `setup_platforms.py` dans `build.gradle(.kts)`), les permissions `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` et les récepteurs de redémarrage dans `AndroidManifest.xml`.
6. **Lint Android** : avec `in_app_purchase_android` et `firebase_core`, la tâche `lintVitalAnalyzeRelease` plantait (NoSuchMethodError interne à lint). `setup_platforms.py` désactive les tâches `lintVital*` des sous-projets.
7. **Chaînes Dart** : un `$` isolé doit être échappé (`'5,00 \$ CA'`), sinon erreur « Expected an identifier ».
8. Dépendances Firebase et achat déclarées en `any` dans `pubspec.yaml` (versions résolues par la CI). Pour figer les versions, commiter `pubspec.lock` et remplacer `any` par des plages `^`.
9. L'API GitHub de la session de Claude est limitée aux dépôts attachés : la création d'un dépôt doit se faire par l'utilisateur, et l'écriture exige que l'application GitHub de Claude ait accès au dépôt.

## 7. Mises à niveau recommandées (par priorité)
1. **Tester sur téléphone** et corriger : notification de test, rappels programmés, redémarrage du téléphone, optimisation de batterie.
2. **Mise en ligne Google Play** : suivre `PLAY_STORE.md` (clé de signature + secrets GitHub, Firebase, abonnement annuel, fiche, test fermé 12 testeurs / 14 jours si compte personnel récent). La signature de production et l'AAB sont déjà gérés par la CI quand les secrets existent.
3. **Icône et écran de démarrage** personnalisés (`flutter_launcher_icons`, `flutter_native_splash`) : l'icône actuelle est celle par défaut de Flutter.
4. **Données de calendriers par modèle** : remplir `kModelOverrides` à partir des manuels, ou utiliser une source sous licence (décodage du NIV).
5. **Sauvegarde / restauration** : export et import JSON ; plus tard, synchronisation cloud.
6. **Mettre à jour les dépendances** : `flutter_local_notifications` (version ≥ 18 : `uiLocalNotificationDateInterpretation` retiré à partir de la 19 ; vérifier le journal des changements), migrer vers `material_ui`/`initialValue` quand les avertissements le demanderont. Si le partage natif du CSV ou le vrai fuseau horaire sont souhaités, ajouter des versions récentes de `share_plus` et `flutter_timezone` compatibles avec Kotlin intégré (vérifier d'abord que la CI compile).
7. **Fonctions possibles** : photos de factures, rappels d'assurance / immatriculation / inspection, plusieurs conducteurs, rappel selon la saison, widget d'accueil, version anglaise (extraire les textes en fichiers de traduction), tests d'interface.

## 8. Rappels pratiques
- Après chaque modification : `flutter test`, puis pousser sur `main` ; surveiller l'onglet Actions. Pour lire une erreur de CI sans ouvrir le navigateur : `gh api repos/RymeTVNews/Ryme-entretien/actions/runs/<id>/jobs` puis `.../actions/jobs/<id>/logs`.
- Ne pas versionner `android/` et `ios/` sans raison : ils sont régénérés. Si des réglages natifs supplémentaires sont nécessaires, les ajouter dans `tool/setup_platforms.py`, pas à la main.
- Le fichier de la démo web est indépendant du code Flutter : toute règle métier modifiée dans `engine.dart` ou `catalog.dart` doit être répercutée à la main dans la page si l'on veut garder la démo fidèle.
