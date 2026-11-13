# Ryme entretien (Flutter — iOS et Android)

Application de rappels d'entretien automobile par notifications automatiques.

## Fonctionnalités
- **Plusieurs véhicules** : marque, modèle, année, version, carburant (essence, diesel, hybride, hybride rechargeable, électrique), transmission, kilométrage, plaque, NIV, notes, usage annuel estimé, conditions sévères.
- **Calendrier d'entretien généré** selon la marque, le carburant et la transmission (pas de vidange pour un véhicule électrique, etc.), modifiable : activer/désactiver, changer les intervalles (km et/ou mois), ajouter des entretiens personnalisés, réinitialiser.
- **Suivi par kilométrage ET par date** : chaque entretien est dû au premier des deux critères atteint. La date d'un entretien basé sur le kilométrage est estimée à partir de votre rythme réel (historique du compteur) ou de votre usage annuel déclaré.
- **Onglet « À faire »** : entretiens en retard, à prévoir bientôt, et à venir.
- **Validation d'un entretien** (date, kilométrage, coût, garage, notes) : l'échéance suivante est recalculée automatiquement. Possibilité de déclarer un entretien déjà effectué.
- **Historique** par véhicule, coût total, suppression, **export CSV (copie dans le presse-papiers)**.
- **Notifications locales** (sans serveur) : préavis en jours et en km configurables, heure choisie, rappel hebdomadaire tant qu'un entretien est en retard, rappel mensuel de mise à jour du compteur, rappels de pneus saisonniers (optionnels), reprogrammation à chaque modification et après redémarrage du téléphone.
- Unités **km / mi**, thème clair/sombre automatique, données stockées localement.

## Limite importante : données des fabricants
Aucun fabricant ne fournit de base de données ouverte et gratuite de ses calendriers d'entretien pour chaque modèle et chaque année. L'application utilise donc des **intervalles indicatifs par marque** (`lib/catalog.dart`), affichés avec un avertissement et toujours modifiables. Pour un calendrier exact par modèle, ajoutez les valeurs du manuel officiel dans `kModelOverrides` (format documenté dans le fichier), ou branchez une source de données sous licence.

## Mise en ligne sur Google Play
Voir **PLAY_STORE.md** (essai gratuit natif de 7 jours, abonnement annuel de 5 $ CA, compte par courriel, signature, Firebase). Notes techniques : **NOTES_PROJET.md**.

## Compiler
Prérequis : Flutter (stable), Android Studio / Xcode.

```bash
python3 tool/setup_platforms.py   # génère android/ et ios/ et applique les réglages de notifications
flutter pub get
flutter test
flutter run
flutter build apk --release       # Android
flutter build ios --release       # iOS (nécessite un Mac et un compte Apple Developer)
```
Le workflow GitHub Actions (`.github/workflows/build.yml`) compile l'APK et le build iOS (sans signature) à chaque push.

### Ce que fait `tool/setup_platforms.py`
- Android : permissions `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`; récepteurs de notifications programmées (redémarrage compris); desugaring Java requis par `flutter_local_notifications`.
- iOS : délégué `UNUserNotificationCenter` dans `AppDelegate.swift`. Si le script signale une structure inattendue, ajoutez dans `application(_:didFinishLaunchingWithOptions:)`, avant l'enregistrement des plugins :
  `UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate`

## Structure
```
lib/models.dart        modèles + (dé)sérialisation JSON
lib/catalog.dart       calendriers par marque / carburant / transmission
lib/engine.dart        calcul des échéances (km + date), statuts
lib/notifications.dart plan de notifications + service local
lib/state.dart         état, stockage local, export CSV
lib/screens/           écrans
test/engine_test.dart  tests du moteur
```

## Pistes d'évolution
Sauvegarde cloud / synchronisation, import d'un manuel via NIV (API sous licence), photos de factures, rappels d'assurance/immatriculation/inspection, partage entre conducteurs, version anglaise.
