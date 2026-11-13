import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'access.dart';
import 'config.dart';
import 'notifications.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/paywall_screen.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Initialisation des notifications impossible : $e');
  }
  String? initError;
  if (AppConfig.firebaseConfigured) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseSenderId,
          projectId: AppConfig.firebaseProjectId,
        ),
      );
    } catch (e) {
      initError = "Impossible d'initialiser la connexion ($e).";
    }
  }
  final state = AppState();
  await state.load();
  final access = AccessController()..attach(state);
  await access.init(initError: initError);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<AccessController>.value(value: access),
      ],
      child: const EntretienApp(),
    ),
  );
}

/// Aiguille vers l'écran voulu selon l'état d'accès :
/// connexion par courriel → essai de 7 jours → abonnement annuel.
class AccessGate extends StatelessWidget {
  const AccessGate({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessController>();
    switch (access.status) {
      case AccessStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AccessStatus.signedOut:
        return const AuthScreen();
      case AccessStatus.expired:
        return const PaywallScreen();
      case AccessStatus.error:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(access.message ?? 'Erreur',
                  textAlign: TextAlign.center),
            ),
          ),
        );
      case AccessStatus.trial:
      case AccessStatus.premium:
      case AccessStatus.devMode:
        return const HomeScreen();
    }
  }
}

class EntretienApp extends StatelessWidget {
  const EntretienApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ryme entretien',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AccessGate(),
    );
  }
}
