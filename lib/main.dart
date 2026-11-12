import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'notifications.dart';
import 'screens/home_screen.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Initialisation des notifications impossible : $e');
  }
  final state = AppState();
  await state.load();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const EntretienApp()),
  );
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
      home: const HomeScreen(),
    );
  }
}
