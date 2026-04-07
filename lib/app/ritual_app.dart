import 'package:flutter/material.dart';
import 'package:ritual/features/today/today_page.dart';

class RitualApp extends StatelessWidget {
  const RitualApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF1A8F8A);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF11181F),
    );

    return MaterialApp(
      title: 'Ritual',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF091017),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF11181F),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: colorScheme.primary,
          linearTrackColor: Colors.white12,
        ),
      ),
      home: const TodayPage(),
    );
  }
}
