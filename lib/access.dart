import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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
/// connexion obligatoire → achat → essai de [trialDays] jours → blocage.
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
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide (format : +1 514 555 0123).';
      case 'invalid-verification-code':
        return 'Code de vérification incorrect.';
      case 'session-expired':
        return 'Le code a expiré. Demandez-en un nouveau.';
      case 'quota-exceeded':
        return 'Limite de messages atteinte. Réessayez plus tard.';
      case 'requires-recent-login':
        return 'Pour des raisons de sécurité, déconnectez-vous puis '
            'reconnectez-vous avant de supprimer votre compte.';
      default:
        return 'Une erreur est survenue (${e.code}).';
    }
  }
  return 'Une erreur est survenue.';
}

/// Gère la connexion (Firebase Auth), l'essai gratuit et l'achat unique
/// (Google Play Billing).
class AccessController extends ChangeNotifier with WidgetsBindingObserver {
  static const _kPremium = 'premium_v1';
  static const _kLastServer = 'last_server_ms';

  AccessStatus status = AccessStatus.loading;
  int daysLeft = 0;
  bool premium = false;
  bool busy = false;
  String? message;
  ProductDetails? product;
  bool storeAvailable = true;
  bool phoneCodeSent = false;
  User? user;

  String? _verificationId;
  int? _resendToken;
  Duration _skew = Duration.zero;
  DateTime? _lastServer;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<PurchaseDetails>>? _purchSub;
  Timer? _timer;
  AppState? _app;

  void attach(AppState app) => _app = app;

  String get identifier {
    final u = user;
    if (u == null) return '';
    if ((u.email ?? '').isNotEmpty) return u.email!;
    return u.phoneNumber ?? '';
  }

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
    premium = prefs.getBool(_kPremium) ?? false;
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
        _syncServerTime(u).then((_) => _recompute());
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

  // ---- Décision --------------------------------------------------------------

  Future<void> _onUser(User? u) async {
    user = u;
    phoneCodeSent = false;
    _verificationId = null;
    if (u != null) await _syncServerTime(u);
    _recompute();
  }

  void _recompute() {
    if (status == AccessStatus.devMode || status == AccessStatus.error) return;
    final now = _now();
    final d = decideAccess(
      signedIn: user != null,
      accountCreated: user?.metadata.creationTime,
      now: now,
      premium: premium,
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

  // ---- Achat -----------------------------------------------------------------

  Future<void> loadStore() async {
    try {
      final iap = InAppPurchase.instance;
      storeAvailable = await iap.isAvailable();
      if (storeAvailable) {
        final r = await iap.queryProductDetails({AppConfig.productId});
        product = r.productDetails.isEmpty ? null : r.productDetails.first;
        if (!premium) await iap.restorePurchases();
      }
    } catch (e) {
      storeAvailable = false;
    }
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    final iap = InAppPurchase.instance;
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
          premium = true;
          busy = false;
          message = null;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_kPremium, true);
          } catch (_) {}
          if (p.pendingCompletePurchase) await iap.completePurchase(p);
          break;
        case PurchaseStatus.error:
          busy = false;
          message = p.error?.message ?? "L'achat a échoué.";
          if (p.pendingCompletePurchase) await iap.completePurchase(p);
          break;
        case PurchaseStatus.canceled:
          busy = false;
          break;
      }
    }
    _recompute();
  }

  Future<void> buy() async {
    final prod = product;
    if (prod == null) {
      message = "Le produit n'est pas disponible dans Google Play.";
      notifyListeners();
      return;
    }
    message = null;
    busy = true;
    notifyListeners();
    try {
      await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: prod));
    } catch (e) {
      busy = false;
      message = "Impossible de lancer l'achat.";
      notifyListeners();
    }
  }

  Future<void> restore() async {
    message = null;
    busy = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!premium) {
        message = 'Aucun achat à restaurer pour ce compte Google Play.';
      }
    } catch (e) {
      message = 'Restauration impossible pour le moment.';
    }
    busy = false;
    notifyListeners();
  }

  // ---- Connexion -------------------------------------------------------------

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

  /// Envoie le code SMS. [phone] au format international (+15145550123).
  Future<String?> startPhone(String phone, {bool resend = false}) async {
    final completer = Completer<String?>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: resend ? _resendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          // Récupération automatique du SMS sur Android.
          try {
            await FirebaseAuth.instance.signInWithCredential(cred);
          } catch (_) {}
          if (!completer.isCompleted) completer.complete(null);
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) completer.complete(authErrorMessage(e));
        },
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          phoneCodeSent = true;
          notifyListeners();
          if (!completer.isCompleted) completer.complete(null);
        },
        codeAutoRetrievalTimeout: (id) {
          _verificationId = id;
        },
      );
    } catch (e) {
      if (!completer.isCompleted) completer.complete(authErrorMessage(e));
    }
    return completer.future;
  }

  Future<String?> confirmCode(String code) async {
    final id = _verificationId;
    if (id == null) return 'Demandez d\'abord un code.';
    try {
      final cred =
          PhoneAuthProvider.credential(verificationId: id, smsCode: code.trim());
      await FirebaseAuth.instance.signInWithCredential(cred);
      return null;
    } catch (e) {
      return authErrorMessage(e);
    }
  }

  void resetPhoneFlow() {
    phoneCodeSent = false;
    _verificationId = null;
    notifyListeners();
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  /// Supprime le compte (et efface les données locales de l'appareil).
  Future<String?> deleteAccount() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    try {
      await u.delete();
      await _app?.eraseAll();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kPremium);
      } catch (_) {}
      premium = false;
      return null;
    } catch (e) {
      return authErrorMessage(e);
    }
  }
}
