# Mise en ligne sur Google Play — guide pas à pas

Ce document décrit ce qui est déjà configuré dans le code et ce que vous devez faire dans Google Play Console, Firebase et GitHub. Dernière mise à jour : 2026-11-13.

## 1. Modèle économique retenu (et pourquoi)

| Votre demande | Ce qui est mis en place |
|---|---|
| Essai de 7 jours | Compté **dans l'application**, depuis la création du compte, **sans carte bancaire**. |
| Ensuite, 5 $ CA par année | **Application gratuite à télécharger** + **abonnement annuel à renouvellement automatique** « `ryme_entretien_annuel` » à **5,00 CAD par an**, vendu par Google Play Billing. Après 7 jours sans abonnement actif, l'application se verrouille (écran d'abonnement) et n'envoie plus de notifications ; les données restent conservées. |
| Paiement en devise étrangère selon le taux en vigueur | Google Play affiche automatiquement le prix converti dans la devise de chaque pays à partir du prix de base en CAD. Vous pouvez vérifier et ajuster le prix de chaque pays dans Play Console. |
| Paiement par carte bancaire | Géré par Google Play (cartes de crédit/débit, Google Pay, etc., selon le pays de l'acheteur). L'application ne voit jamais de numéro de carte. |
| Ouverture de compte uniquement par courriel | **Firebase Authentication, courriel + mot de passe** seulement (création de compte, connexion, mot de passe oublié). Aucune connexion par téléphone. |
| Fournir et modifier le compte qui reçoit les paiements | **Se fait dans Play Console, pas dans l'application** (voir §2). |

Commission de Google : **15 % sur les abonnements à renouvellement automatique, quel que soit le revenu annuel**. Les barèmes évoluent : vérifiez la page officielle des frais de service de Google Play avant le lancement.

Variante possible : Google Play permet aussi d'ajouter un **essai gratuit natif de 7 jours à l'abonnement**, mais il exige alors une carte dès le début de l'essai et facture automatiquement au 8ᵉ jour. J'ai gardé l'essai dans l'application (sans carte) ; dites-moi si vous préférez la variante native.

## 2. Compte bancaire de versement (modifiable à tout moment)

C'est Google qui vous verse l'argent, sur le compte bancaire enregistré dans votre **profil de paiements**. Il n'existe aucun moyen sûr ni autorisé de faire saisir un numéro de compte dans l'application, et l'application ne le gère donc pas.

1. Ouvrez Play Console (play.google.com/console).
2. Dans le menu, ouvrez la configuration du compte (« Configuration » / « Setup »), puis « Profil de paiements ». Le lien mène au Centre de paiements Google.
3. Ajoutez ou modifiez le **compte bancaire** (compte canadien en dollars canadiens) et les **informations fiscales** demandées. Google peut demander une vérification (petit dépôt ou document). Les libellés exacts peuvent varier un peu.
4. Les revenus sont versés chaque mois lorsque le solde atteint le seuil minimum de versement.

Ne partagez jamais votre numéro de compte dans une conversation, un courriel ou le dépôt GitHub.

## 3. Ce qui est configuré dans le code

- `lib/config.dart` : durée de l'essai (7 jours), identifiant de l'abonnement (`ryme_entretien_annuel`), tolérance hors ligne (7 jours), liens et clés Firebase fournis à la compilation (`--dart-define`).
- `lib/access.dart` : règle d'accès (connexion → abonnement actif → essai → blocage), connexion par courriel, abonnement, suppression de compte. L'heure du serveur Firebase corrige l'horloge de l'appareil, et l'application ignore un recul de la date du téléphone.
- **Vérification de l'abonnement** : à chaque ouverture (et au plus une fois par heure ensuite), l'application demande à Google Play les abonnements actifs du compte Google de l'appareil. Un abonnement annulé qui est arrivé à échéance n'y figure plus et l'accès se verrouille. Hors ligne, la dernière confirmation reste valable 7 jours.
- Écrans : création de compte / connexion (`auth_screen.dart`), abonnement (`paywall_screen.dart`, avec prix, durée, renouvellement automatique et comment annuler, comme l'exige Google), section « Compte » dans Réglages (restaurer l'abonnement, se déconnecter, **supprimer mon compte**), bandeau « Essai gratuit : X jours restants ».
- `tool/setup_platforms.py` : minSdk 23 (exigé par Firebase), signature de production à partir de `android/key.properties`.
- `.github/workflows/build.yml` : produit l'**APK** (test) et le **fichier AAB** (publication, seulement si la clé de signature est fournie).
- Sans configuration Firebase, l'application démarre en « mode développement » : aucune connexion, aucun abonnement, tout est débloqué. C'est le cas des APK construits tant que vous n'avez pas ajouté les secrets ci-dessous.

## 4. Étape A — Compte développeur Google Play

1. Créez un compte sur play.google.com/console (frais **uniques de 25 $ US**).
2. Choisissez le type de compte :
   - **Personnel** : si le compte a été créé après le 13 novembre 2023, Google exige, avant la publication, un **test fermé avec au moins 12 testeurs inscrits en continu pendant 14 jours**. Prévoyez environ 3 semaines pour la première publication.
   - **Organisation** : pas de test obligatoire, mais demande un numéro D-U-N-S et des documents d'entreprise.

## 5. Étape B — Firebase (comptes par courriel)

1. Allez sur console.firebase.google.com → « Ajouter un projet ».
2. Ajoutez une application **Android** avec le nom de paquet exact : `com.ryme.ryme_entretien`.
3. **Authentication → Méthode de connexion** : activez uniquement « Adresse e-mail/Mot de passe » (lien par courriel non nécessaire). Cette méthode n'exige pas le forfait payant de Firebase.
4. Téléchargez `google-services.json` et relevez 4 valeurs :
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

Relancez ensuite la compilation (Actions → Build → « Re-run all jobs »). Elle produit alors `ryme-entretien-aab` (fichier `app-release.aab`, à envoyer à Google Play) et un APK verrouillé (connexion + essai + abonnement actifs). Le numéro de version s'incrémente automatiquement.

## 7. Étape D — Play Console : application et abonnement

1. **Créer l'application** : nom « Ryme entretien », langue par défaut français (Canada), type **Application**, **Gratuite** (le prix gratuit/payant ne se change pas ensuite ; l'abonnement passe par un produit intégré).
2. **Envoyer le premier AAB** dans une version de test **interne** (jusqu'à 100 testeurs, disponible rapidement). Activez la signature d'application par Google Play (par défaut).
3. **Créer l'abonnement** : Monétiser → Produits → **Abonnements** → Créer un abonnement.
   - ID du produit : `ryme_entretien_annuel` (exactement, il ne pourra pas être modifié)
   - Nom : « Ryme entretien — abonnement annuel »
   - Ajoutez un **forfait de base** (« base plan ») : ID `annuel`, **renouvellement automatique**, période de facturation **1 an**, prix de base **5,00 CAD**. Vérifiez ensuite les prix des autres pays (convertis automatiquement ; modifiables pays par pays).
   - Ne créez **pas** d'offre d'essai gratuit (l'essai est dans l'application), sauf si vous choisissez la variante native.
   - Activez la période de grâce / récupération des paiements échoués si Play Console la propose, puis **activez** le forfait de base.
   - L'abonnement ne fonctionne qu'avec une version installée depuis Google Play (test interne compris).
4. **Testeurs de licence** : Paramètres → Test de licence → ajoutez vos adresses Gmail de test : leurs achats sont simulés (sans frais) et leurs abonnements se renouvellent à un rythme accéléré, parfait pour essayer le paiement et l'annulation.
5. **Contenu de l'application** (obligatoire avant publication) :
   - Politique de confidentialité : `PRIVACY_URL`
   - Sécurité des données : l'application collecte l'**adresse courriel** (connexion, via Firebase) ; les paiements sont traités par Google Play ; les données d'entretien restent sur l'appareil ; pas de publicité ; pas de partage avec des tiers à des fins commerciales. Indiquez que l'**utilisateur peut demander la suppression** et collez `DELETION_URL`.
   - **Accès à l'application** : connexion requise. Indiquez que les réviseurs peuvent **créer un compte courriel eux-mêmes** (chaque nouveau compte reçoit 7 jours d'essai complet).
   - Classification du contenu (questionnaire), public cible (adultes), annonces (aucune).
6. **Fiche Play Store** : description courte et longue (mentionnez l'essai de 7 jours puis l'abonnement annuel de 5 $ CA), icône 512 × 512, image de présentation 1024 × 500, au moins 2 captures d'écran de téléphone.
7. **Publication** :
   - Compte personnel récent : lancez un **test fermé** avec 12 testeurs ou plus (14 jours continus), puis cliquez sur « Demander l'accès à la production ».
   - Sinon : créez une version de production avec l'AAB et envoyez-la en examen.

## 8. Politique de confidentialité et suppression de compte

Les dossiers `docs/` contiennent deux pages HTML modèles : `politique-confidentialite.html` et `suppression-compte.html`. **Complétez les passages marqués « À COMPLÉTER »** (nom, courriel, adresse) et faites-les relire : ce sont des modèles, pas un avis juridique (Loi 25 au Québec, LPRPDE au Canada, selon votre cas).

Pour les rendre publiques gratuitement : GitHub → dépôt → Settings → Pages → source « Deploy from a branch » → branche `main`, dossier `/docs`. Les adresses ressembleront à :
- `https://rymetvnews.github.io/Ryme-entretien/politique-confidentialite.html`
- `https://rymetvnews.github.io/Ryme-entretien/suppression-compte.html`

## 9. Limites connues de cette mise en œuvre

- **Vérification de l'abonnement côté application seulement.** L'état « abonné » est lu par l'application depuis Google Play et mémorisé 7 jours. Un appareil modifié (« rooté ») pourrait le contourner, et un abonnement annulé ou remboursé peut rester actif jusqu'à 7 jours si le téléphone reste hors ligne. Pour une protection complète : vérification côté serveur avec l'API Google Play Developer (Cloud Functions) et notifications temps réel d'abonnement.
- **L'abonnement suit le compte Google Play, pas le compte courriel.** Un abonnement acheté avec un compte Google Play débloque l'application pour tout compte courriel connecté sur ce même téléphone.
- **Supprimer le compte n'annule pas l'abonnement** : l'utilisateur doit l'annuler dans Google Play (le message est affiché dans l'application).
- **Essai et comptes multiples.** L'essai est lié au compte courriel : quelqu'un peut créer plusieurs comptes pour renouveler l'essai.
- **Android seulement.** L'abonnement est configuré pour Google Play. Pour l'App Store (iPhone) il faut un compte Apple Developer (99 $ US/an) et un abonnement équivalent dans App Store Connect.
- **Jamais testé de bout en bout sur un téléphone** au moment de cette note : la compilation, l'analyse et les tests automatiques de la CI sont vérifiés, mais l'abonnement réel et la création de compte ne peuvent l'être qu'avec vos comptes Firebase et Google Play.
- Les menus de Play Console et de Firebase évoluent : si un libellé diffère, cherchez le mot-clé dans l'aide de la console.
