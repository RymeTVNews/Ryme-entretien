# Mise en ligne sur Google Play — guide pas à pas

Ce document décrit ce qui est déjà configuré dans le code et ce que vous devez faire dans Google Play Console, Firebase et GitHub. Dernière mise à jour : 2026-11-12.

## 1. Modèle économique retenu (et pourquoi)

| Votre demande | Ce qui est mis en place |
|---|---|
| Essai de 7 jours | Compté **dans l'application**, depuis la création du compte. Google Play ne permet les essais gratuits que pour les **abonnements** ; une application payante ou un achat unique ne peut pas avoir d'essai. Détourner un abonnement en achat unique est interdit par la politique de Google. |
| Ensuite, un seul paiement de 5 $ CA | **Application gratuite à télécharger** + **produit à achat unique** « `ryme_entretien_premium` » à **5,00 CAD**, vendu par Google Play Billing. Après 7 jours sans achat, l'application se verrouille (écran d'achat) et n'envoie plus de notifications ; les données restent conservées. |
| Paiement en devise étrangère selon le taux en vigueur | Google Play affiche automatiquement le prix converti dans la devise de chaque pays à partir du prix de base en CAD. Vous pouvez vérifier et ajuster le prix de chaque pays dans Play Console. |
| Paiement par carte bancaire | Géré par Google Play (cartes de crédit/débit, Google Pay, etc., selon le pays de l'acheteur). L'application ne voit jamais de numéro de carte. |
| Connexion par courriel ou numéro de téléphone après le téléchargement | **Firebase Authentication** : courriel + mot de passe, ou code reçu par SMS. Connexion obligatoire au premier lancement. |
| Fournir et modifier le compte qui reçoit les paiements | **Se fait dans Play Console, pas dans l'application** (voir §2). |

Commission de Google : 15 % sur les premiers 1 M$ US de revenus par an, puis 30 %.

## 2. Compte bancaire de versement (modifiable à tout moment)

C'est Google qui vous verse l'argent, sur le compte bancaire enregistré dans votre **profil de paiements**. Il n'existe aucun moyen sûr ni autorisé de faire saisir un numéro de compte dans l'application, et l'application ne le gère donc pas.

1. Ouvrez Play Console (play.google.com/console).
2. Dans le menu, ouvrez la configuration du compte (« Configuration » / « Setup »), puis « Profil de paiements ». Le lien mène au Centre de paiements Google.
3. Ajoutez ou modifiez le **compte bancaire** (compte canadien en dollars canadiens) et les **informations fiscales** demandées. Google peut demander une vérification (petit dépôt ou document). Les libellés exacts peuvent varier un peu.
4. Les revenus sont versés chaque mois lorsque le solde atteint le seuil minimum de versement.

Ne partagez jamais votre numéro de compte dans une conversation, un courriel ou le dépôt GitHub.

## 3. Ce qui est configuré dans le code

- `lib/config.dart` : durée de l'essai (7 jours), identifiant du produit (`ryme_entretien_premium`), liens et clés Firebase fournis à la compilation (`--dart-define`).
- `lib/access.dart` : règle d'accès (connexion → achat → essai → blocage), connexion, achat, suppression de compte. L'heure du serveur Firebase corrige l'horloge de l'appareil, et l'application ignore un recul de la date du téléphone.
- Écrans : connexion (`auth_screen.dart`), achat (`paywall_screen.dart`), section « Compte » dans Réglages (restaurer l'achat, se déconnecter, **supprimer mon compte**), bandeau « Essai gratuit : X jours restants ».
- `tool/setup_platforms.py` : minSdk 23 (exigé par Firebase), signature de production à partir de `android/key.properties`.
- `.github/workflows/build.yml` : produit l'**APK** (test) et le **fichier AAB** (publication, seulement si la clé de signature est fournie).
- Sans configuration Firebase, l'application démarre en « mode développement » : aucune connexion, aucun achat, tout est débloqué. C'est le cas des APK construits tant que vous n'avez pas ajouté les secrets ci-dessous.

## 4. Étape A — Compte développeur Google Play

1. Créez un compte sur play.google.com/console (frais **uniques de 25 $ US**).
2. Choisissez le type de compte :
   - **Personnel** : si le compte a été créé après le 13 novembre 2023, Google exige, avant la publication, un **test fermé avec au moins 12 testeurs inscrits en continu pendant 14 jours**. Prévoyez environ 3 semaines pour la première publication.
   - **Organisation** : pas de test obligatoire, mais demande un numéro D-U-N-S et des documents d'entreprise.

## 5. Étape B — Firebase (connexion)

1. Allez sur console.firebase.google.com → « Ajouter un projet ».
2. Ajoutez une application **Android** avec le nom de paquet exact : `com.ryme.ryme_entretien`.
3. **Authentication → Méthode de connexion** : activez « Adresse e-mail/Mot de passe » et « Téléphone ».
4. **Téléphone = forfait Blaze obligatoire** (paiement à l'usage, carte requise) depuis septembre 2024. Chaque SMS est facturé et le prix varie selon le pays (de l'ordre de 0,01 $ US aux États-Unis, plus ailleurs). Dans Authentication → Paramètres → « Politique de région SMS », n'autorisez que les pays visés pour limiter les abus et les coûts. La connexion par courriel est gratuite.
5. **Numéros de test** : dans la méthode « Téléphone », ajoutez un numéro fictif avec un code fixe pour les réviseurs de Google.
6. **Empreintes SHA** : dans Paramètres du projet → votre application Android, ajoutez les empreintes SHA-1 et SHA-256 de votre clé d'envoi (voir étape C), puis, après le premier envoi dans Play Console, celles de la **clé de signature de l'application** (Play Console → Test et publication → Intégrité de l'application → Signature d'application). Sans elles, la connexion par téléphone échoue sur la version téléchargée depuis Google Play.
7. Téléchargez `google-services.json` et relevez 4 valeurs :
   - `current_key` (dans `api_key`) → **FIREBASE_API_KEY**
   - `mobilesdk_app_id` → **FIREBASE_APP_ID**
   - `project_number` → **FIREBASE_MESSAGING_SENDER_ID**
   - `project_id` → **FIREBASE_PROJECT_ID**

## 6. Étape C — Clé de signature et secrets GitHub

Sur un ordinateur avec Java (JDK) installé :

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks      # sur Mac : base64 -i upload-keystore.jks
keytool -list -v -keystore upload-keystore.jks -alias upload   # affiche SHA-1 et SHA-256
```

**Sauvegardez `upload-keystore.jks` et ses mots de passe** dans un endroit sûr (hors GitHub). Ne les envoyez à personne, y compris à Claude.

Dans GitHub : dépôt → Settings → Secrets and variables → Actions.

**Secrets** (onglet « Secrets ») :

| Nom | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | résultat de la commande `base64` |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du fichier de clés |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID` | valeurs de l'étape B |

**Variables** (onglet « Variables ») :

| Nom | Contenu |
|---|---|
| `PRIVACY_URL` | adresse publique de la politique de confidentialité (voir §8) |
| `DELETION_URL` | adresse de la page de demande de suppression de compte |
| `SUPPORT_EMAIL` | courriel d'assistance |

Relancez ensuite la compilation (Actions → Build → « Re-run all jobs »). Elle produit alors `ryme-entretien-aab` (fichier `app-release.aab`, à envoyer à Google Play) et un APK verrouillé (connexion + essai + achat actifs). Le numéro de version s'incrémente automatiquement.

## 7. Étape D — Play Console : application et produit

1. **Créer l'application** : nom « Ryme entretien », langue par défaut français (Canada), type **Application**, **Gratuite** (le prix gratuit/payant ne se change pas ensuite ; l'achat de 5 $ passe par le produit intégré).
2. **Envoyer le premier AAB** dans une version de test **interne** (jusqu'à 100 testeurs, disponible rapidement). Activez la signature d'application par Google Play (par défaut).
3. **Créer le produit** : Monétiser → Produits → **Produits uniques** → Créer.
   - ID du produit : `ryme_entretien_premium` (exactement, il ne pourra pas être modifié)
   - Nom : « Ryme entretien — version complète »
   - Option d'achat « Acheter » : prix de base **5,00 CAD**, puis vérifiez les prix des autres pays (convertis automatiquement ; modifiables pays par pays).
   - **Activer** le produit. L'achat ne fonctionne qu'avec une version installée depuis Google Play (test interne compris).
4. **Testeurs de licence** : Paramètres → Test de licence → ajoutez vos adresses Gmail de test : leurs achats sont gratuits et simulés, parfait pour essayer le paiement.
5. **Contenu de l'application** (obligatoire avant publication) :
   - Politique de confidentialité : `PRIVACY_URL`
   - Sécurité des données : l'application collecte l'**adresse courriel** et/ou le **numéro de téléphone** (connexion, via Firebase), les achats sont traités par Google Play ; les données d'entretien restent sur l'appareil ; pas de publicité ; pas de partage avec des tiers à des fins commerciales. Indiquez que l'**utilisateur peut demander la suppression** et collez `DELETION_URL`.
   - **Accès à l'application** : connexion requise. Indiquez que les réviseurs peuvent **créer un compte courriel eux-mêmes** (chaque nouveau compte reçoit 7 jours d'essai complet) ou utiliser le numéro de test Firebase (étape B, point 5).
   - Classification du contenu (questionnaire), public cible (adultes), annonces (aucune).
6. **Fiche Play Store** : description courte et longue, icône 512 × 512, image de présentation 1024 × 500, au moins 2 captures d'écran de téléphone.
7. **Publication** :
   - Compte personnel récent : lancez un **test fermé** avec 12 testeurs ou plus (14 jours continus), puis cliquez sur « Demander l'accès à la production ».
   - Sinon : créez une version de production avec l'AAB et envoyez-la en examen.

## 8. Politique de confidentialité et suppression de compte

Les dossiers `docs/` contiennent deux pages HTML modèles : `politique-confidentialite.html` et `suppression-compte.html`. **Complétez les passages marqués « À COMPLÉTER »** (nom, courriel, adresse) et faites-les relire : ce sont des modèles, pas un avis juridique (Loi 25 au Québec, LPRPDE au Canada, selon votre cas).

Pour les rendre publiques gratuitement : GitHub → dépôt → Settings → Pages → source « Deploy from a branch » → branche `main`, dossier `/docs`. Les adresses ressembleront à :
- `https://rymetvnews.github.io/Ryme-entretien/politique-confidentialite.html`
- `https://rymetvnews.github.io/Ryme-entretien/suppression-compte.html`

## 9. Limites connues de cette mise en œuvre

- **Vérification de l'achat côté application seulement.** L'état « acheté » est lu par l'application depuis Google Play et mémorisé sur l'appareil. Un appareil modifié (« rooté ») pourrait le contourner, et un remboursement n'est pas détecté automatiquement. Pour une protection complète : vérification côté serveur avec l'API Google Play Developer (Cloud Functions) et notifications temps réel de remboursement.
- **Essai et comptes multiples.** L'essai est lié au compte : quelqu'un peut créer plusieurs comptes courriel pour renouveler l'essai. Le numéro de téléphone limite l'abus, mais n'est pas infaillible.
- **Android seulement.** L'achat intégré est configuré pour Google Play. Pour l'App Store (iPhone) il faut un compte Apple Developer (99 $ US/an) et un produit équivalent dans App Store Connect.
- **Jamais testé de bout en bout sur un téléphone** au moment de cette note : la compilation, l'analyse et les tests automatiques de la CI sont vérifiés, mais l'achat réel et la connexion par SMS ne peuvent l'être qu'avec vos comptes Firebase et Google Play.
- Les menus de Play Console et de Firebase évoluent : si un libellé diffère, cherchez le mot-clé dans l'aide de la console.
