import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/pages/add_cards_form_page.dart';
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
    final ColorScheme colorScheme = ColorScheme(
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
            color: colorScheme.primary,
            shape: Border(
              bottom: BorderSide(
                color: Colors.black,
                width: 1,
              ),
            ),
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontFamily: 'Poppins',
            ),
          ),
          textTheme: TextTheme(
              bodyMedium: TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
              bodyLarge: TextStyle(
                color: Colors.black,
                fontSize: 22,
              )).apply(
            fontFamily: 'Poppins',
          ),
          iconTheme: IconThemeData(
            color: Colors.black,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              textStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              backgroundColor: primaryColor,
            ),
          ),
          useMaterial3: true,
        ),
        routes: {
          '/': (ctx) => HomePage(),
          'add-cards': (ctx) => AddCartsFormPage()
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
