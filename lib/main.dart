import 'package:bla_bla_in_english/pages/home_page.dart';
import 'package:bla_bla_in_english/providers/carts_state_provider.dart';
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
          create: (_) => CartsStateProvider(),
        )
      ],
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: colorScheme,
          appBarTheme: AppBarTheme(
            color: colorScheme.onPrimary,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          useMaterial3: true,
        ),
        home: const HomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
