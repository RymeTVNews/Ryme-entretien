import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'state.dart';

enum AccessStatus { loading, signedOut, trial, expired, premium, devMode, error }

class AccessDecision {
  final AccessStatus status;
  final int daysLeft;
  const AccessDecision(this.status, this.daysLeft);
}

/// Règle d'accès (pure, testable) :
/// connexion obligatoire → abonnement actif → essai de [trialDays] jours →
/// blocage.
AccessDecision decideAccess({
  required bool signedIn,
  required DateTime? accountCreated,
  required DateTime now,
  required bool premium,
  int trialDays = AppConfig.trialDays,
}) {
  if (!signedIn) return const AccessDecision(AccessStatus.signedOut, 0);
  if (premium) return const AccessDecision(AccessStatus.premium, 0);
  final start = accountCreated ?? now;
  final end = start.add(Duration(days: trialDays));
  if (now.isBefore(end)) {
    final left = (end.difference(now).inHours / 24).ceil();
    return AccessDecision(AccessStatus.trial, left < 1 ? 1 : left);
  }
  return const AccessDecision(AccessStatus.expired, 0);
}

/// L'abonnement est considéré actif si Google Play l'a confirmé il y a moins
/// de [graceDays] jours (tolère un téléphone hors ligne).
bool entitlementValid({
  required DateTime? verifiedAt,
  required DateTime now,
  int graceDays = AppConfig.entitlementGraceDays,
}) {
  if (verifiedAt == null) return false;
  final age = now.difference(verifiedAt);
  return !age.isNegative && age < Duration(days: graceDays);
}

String authErrorMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'Adresse courriel invalide.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Courriel ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec ce courriel.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Pas de connexion internet.';
      case 'requires-recent-login':
        return 'Pour des raisons de sécurité, déconnectez-vous puis '
            'reconnectez-vous avant de supprimer votre compte.';
      default:
        return 'Une erreur est survenue (${e.code}).';
    }
  }
  return 'Une erreur est survenue.';
}

/// Gère la connexion par courriel (Firebase Auth), l'essai gratuit et
/// l'abonnement annuel (Google Play Billing).
class AccessController extends ChangeNotifier with WidgetsBindingObserver {
  static const _kVerified = 'premium_verified_ms';
  static const _kLastServer = 'last_server_ms';

  AccessStatus status = AccessStatus.loading;
  int daysLeft = 0;
  bool premium = false;
  bool busy = false;
  String? message;
  ProductDetails? product;
  bool storeAvailable = true;
  User? user;

  Duration _skew = Duration.zero;
  DateTime? _lastServer;
  DateTime? _verifiedAt;
  DateTime? _lastCheck;
  Completer<bool>? _verifyCompleter;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<PurchaseDetails>>? _purchSub;
  Timer? _timer;
  AppState? _app;

  void attach(AppState app) => _app = app;

  String get identifier => user?.email ?? '';

  Future<void> init({String? initError}) async {
    if (initError != null) {
      status = AccessStatus.error;
      message = initError;
      notifyListeners();
      return;
    }
    if (!AppConfig.firebaseConfigured) {
      status = AccessStatus.devMode;
      _apply();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kVerified);
    if (v != null) _verifiedAt = DateTime.fromMillisecondsSinceEpoch(v);
    final ms = prefs.getInt(_kLastServer);
    if (ms != null) _lastServer = DateTime.fromMillisecondsSinceEpoch(ms);

    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
    _purchSub = InAppPurchase.instance.purchaseStream
        .listen(_onPurchases, onError: (Object _) {});
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _recompute());
    unawaited(loadStore());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final u = user;
      if (u != null) {
        _syncServerTime(u).then((_) {
          _recompute();
          unawaited(verifyEntitlement());
        });
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _purchSub?.cancel();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---- Temps ---------------------------------------------------------------

  Future<void> _syncServerTime(User u) async {
    try {
      final r = await u.getIdTokenResult(true);
      final iat = r.issuedAtTime;
      if (iat != null) _skew = iat.difference(DateTime.now());
    } catch (_) {
      // Hors ligne : on garde le dernier décalage connu.
    }
  }

  /// Heure « de confiance » : horloge de l'appareil corrigée par l'heure du
  /// serveur, et jamais antérieure à la dernière heure vue (empêche de
  /// reculer la date du téléphone pour prolonger l'essai).
  DateTime _now() {
    var n = DateTime.now().add(_skew);
    final last = _lastServer;
    if (last != null && n.isBefore(last)) n = last;
    return n;
  }

  Future<void> _remember(DateTime t) async {
    if (_lastServer == null || t.isAfter(_lastServer!)) {
      _lastServer = t;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kLastServer, t.millisecondsSinceEpoch);
      } catch (_) {}
    }
  }

  Future<void> _setVerified(DateTime? t) async {
    _verifiedAt = t;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (t == null) {
        await prefs.remove(_kVerified);
      } else {
        await prefs.setInt(_kVerified, t.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  // ---- Décision --------------------------------------------------------------

  Future<void> _onUser(User? u) async {
    user = u;
    if (u != null) await _syncServerTime(u);
    _recompute();
    if (u != null) unawaited(verifyEntitlement());
  }

  void _recompute() {
    if (status == AccessStatus.devMode || status == AccessStatus.error) return;
    final now = _now();
    premium = entitlementValid(verifiedAt: _verifiedAt, now: now);
    final d = decideAccess(
      signedIn: user != null,
      accountCreated: user?.metadata.creationTime,
      now: now,
      premium: premium,
      trialDays: AppConfig.nativeTrial ? 0 : AppConfig.trialDays,
    );
    status = d.status;
    daysLeft = d.daysLeft;
    unawaited(_remember(now));
    _apply();
  }

  void _apply() {
    final allowed = status == AccessStatus.trial ||
        status == AccessStatus.premium ||
        status == AccessStatus.devMode;
    _app?.setAllowNotifications(allowed);
    notifyListeners();
  }

  // ---- Abonnement ---------------------------------------------------------

  /// Offre d'essai gratuit disponible pour ce compte Google Play ?
  bool get trialOffered => hasFreeTrial(product);

  /// Prix récurrent (dernière phase de l'offre), pas « Gratuit ».
  String? get recurringPrice => recurringPriceOf(product);

  Future<void> loadStore() async {
    try {
      final iap = InAppPurchase.instance;
      storeAvailable = await iap.isAvailable();
      if (storeAvailable) {
        final r = await iap.queryProductDetails({AppConfig.productId});
        product = pickOffer(r.productDetails);
      }
    } catch (e) {
      storeAvailable = false;
    }
    notifyListeners();
    if (storeAvailable) await verifyEntitlement(force: true);
  }

  /// Demande à Google Play les abonnements actifs du compte Google de
  /// l'appareil. Un abonnement annulé ou expiré n'y figure plus.
  /// Hors ligne ou sans réponse, la dernière confirmation reste valable
  /// [AppConfig.entitlementGraceDays] jours.
  Future<void> verifyEntitlement({bool force = false}) async {
    if (!AppConfig.firebaseConfigured) return;
    final now = _now();
    final last = _lastCheck;
    if (!force && last != null && now.difference(last) < const Duration(hours: 1)) {
      return;
    }
    _lastCheck = now;
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return;
      final c = Completer<bool>();
      _verifyCompleter = c;
      await iap.restorePurchases();
      final found = await c.future
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
      final answered = c.isCompleted;
      _verifyCompleter = null;
      if (found == true) {
        await _setVerified(_now());
      } else if (answered) {
        // Réponse de Google Play sans abonnement actif.
        await _setVerified(null);
      }
      // Pas de réponse : résultat non concluant, on garde la confirmation
      // précédente jusqu'à la fin du délai de tolérance.
    } catch (_) {
      _verifyCompleter = null;
    }
    _recompute();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    final iap = InAppPurchase.instance;
    var foundActive = false;
    for (final p in list) {
      if (p.productID != AppConfig.productId) {
        if (p.pendingCompletePurchase) await iap.completePurchase(p);
        continue;
      }
      switch (p.status) {
        case PurchaseStatus.pending:
          busy = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          foundActive = true;
          busy = false;
          message = null;
          await _setVerified(_now());
          // Obligatoire : sans accusé de réception, Google rembourse
          // l'achat après 3 jours.
          if (p.pendingCompletePurchase) await iap.completePurchase(p);
          break;
        case PurchaseStatus.error:
          busy = false;
          message = p.error?.message ?? "L'abonnement a échoué.";
          if (p.pendingCompletePurchase) await iap.completePurchase(p);
          break;
        case PurchaseStatus.canceled:
          busy = false;
          break;
      }
    }
    final c = _verifyCompleter;
    if (c != null && !c.isCompleted) c.complete(foundActive);
    _recompute();
  }

  Future<void> buy() async {
    final prod = product;
    if (prod == null) {
      message = "L'abonnement n'est pas disponible dans Google Play.";
      notifyListeners();
      return;
    }
    message = null;
    busy = true;
    notifyListeners();
    try {
      // Pour un abonnement, le plugin utilise aussi buyNonConsumable.
      await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: prod));
    } catch (e) {
      busy = false;
      message = "Impossible de lancer l'abonnement.";
      notifyListeners();
    }
  }

  Future<void> restore() async {
    message = null;
    busy = true;
    notifyListeners();
    try {
      await verifyEntitlement(force: true);
      if (!premium) {
        message = 'Aucun abonnement actif trouvé pour ce compte Google Play.';
      }
    } catch (e) {
      message = 'Restauration impossible pour le moment.';
    }
    busy = false;
    notifyListeners();
  }

  // ---- Connexion (courriel seulement) -------------------------------------

  /// Retourne un message d'erreur, ou null en cas de succès.
  Future<String?> signInEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return null;
    } catch (e) {
      return authErrorMessage(e);
    }
  }

  Future<String?> registerEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      return null;
    } catch (e) {
      return authErrorMessage(e);
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } catch (e) {
      return authErrorMessage(e);
    }
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  /// Supprime le compte (et efface les données locales de l'appareil).
  /// L'abonnement Google Play, lui, doit être annulé dans Google Play.
  Future<String?> deleteAccount() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    try {
      await u.delete();
      await _app?.eraseAll();
      await _setVerified(null);
      premium = false;
      return null;
    } catch (e) {
      return authErrorMessage(e);
    }
  }
}

List<PricingPhaseWrapper> _phases(ProductDetails? p) {
  if (p is! GooglePlayProductDetails) return const [];
  final i = p.subscriptionIndex;
  final offers = p.productDetails.subscriptionOfferDetails;
  if (i == null || offers == null || i >= offers.length) return const [];
  return offers[i].pricingPhases;
}

/// Google Play ne renvoie l'offre d'essai qu'aux comptes qui y ont droit
/// (nouveaux abonnés). On la choisit si elle est présente ; sinon on prend
/// le forfait de base.
ProductDetails? pickOffer(List<ProductDetails> list) {
  if (list.isEmpty) return null;
  for (final p in list) {
    if (hasFreeTrial(p)) return p;
  }
  return list.first;
}

bool hasFreeTrial(ProductDetails? p) =>
    _phases(p).any((f) => f.priceAmountMicros == 0);

String? recurringPriceOf(ProductDetails? p) {
  final ph = _phases(p);
  if (ph.isNotEmpty) return ph.last.formattedPrice;
  return p?.price;
}
