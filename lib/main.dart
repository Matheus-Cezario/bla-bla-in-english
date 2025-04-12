import 'package:bla_bla_in_english/pages/home_page.dart';
import 'package:bla_bla_in_english/providers/cards_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
      contrastLevel: 0,
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CardsStateProvider(),
        )
      ],
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: colorScheme,
          appBarTheme: AppBarTheme(
            color: colorScheme.onPrimaryFixed,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'Poppins',
            ),
          ),
          textTheme: TextTheme(
              bodyMedium: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              bodyLarge: TextStyle(
                color: Colors.white,
                fontSize: 22,
              )).apply(
            fontFamily: 'Poppins',
          ),
          useMaterial3: true,
        ),
        home: HomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
