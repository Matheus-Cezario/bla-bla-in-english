import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/data/app_database.dart';
import 'package:bla_bla_in_english/pages/practice_page.dart';
import 'package:bla_bla_in_english/providers/session_provider.dart';
import 'package:bla_bla_in_english/repositories/session_repository.dart';
import 'package:bla_bla_in_english/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Opening the database copies the bundled dictionary on first run, so it has
  // to finish before the first frame asks for a session.
  final database = await AppDatabase.open();
  runApp(BlaBlaApp(database: database));
}

class BlaBlaApp extends StatelessWidget {
  const BlaBlaApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsRepository(database.db);
    final sessions = SessionRepository(database.db);

    return MultiProvider(
      providers: [
        Provider.value(value: settings),
        Provider.value(value: sessions),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(sessions: sessions, settings: settings),
        ),
      ],
      child: MaterialApp(
        title: 'Blá Blá in English',
        theme: _theme(),
        home: const PracticePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

ThemeData _theme() {
  const colorScheme = ColorScheme(
    primary: Colors.white70,
    secondary: Colors.black,
    surface: Colors.white,
    error: Colors.red,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    onSurface: Colors.black,
    onError: Colors.white,
    brightness: Brightness.light,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      shape: Border(bottom: BorderSide(color: Colors.black, width: 1)),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 24,
        fontFamily: 'Poppins',
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.black, fontSize: 16),
      bodyLarge: TextStyle(color: Colors.black, fontSize: 22),
    ).apply(fontFamily: 'Poppins'),
    iconTheme: const IconThemeData(color: Colors.black),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          fontFamily: 'Poppins',
        ),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: primaryColor,
      thumbColor: primaryColor,
    ),
    useMaterial3: true,
  );
}
