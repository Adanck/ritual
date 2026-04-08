import 'package:flutter/material.dart';
import 'package:ritual/app/app_settings_controller.dart';
import 'package:ritual/data/models/app_settings.dart';
import 'package:ritual/features/today/today_page.dart';

class RitualApp extends StatelessWidget {
  const RitualApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsController.instance.settings,
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'Ritual',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(settings.visualStyle),
          home: const TodayPage(),
        );
      },
    );
  }
}

ThemeData _buildTheme(AppVisualStyle visualStyle) {
  switch (visualStyle) {
    case AppVisualStyle.ios:
      return _buildIosTheme();
    case AppVisualStyle.ritual:
      return _buildRitualTheme();
  }
}

ThemeData _buildRitualTheme() {
  const seedColor = Color(0xFF1A8F8A);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
    surface: const Color(0xFF11181F),
  );

  return _buildSharedThemeShell(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFF091017),
    cardColor: const Color(0xFF11181F),
    cardRadius: 20,
    pageTransitionsTheme: const PageTransitionsTheme(),
  );
}

ThemeData _buildIosTheme() {
  const seedColor = Color(0xFF0A84FF);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
    surface: const Color(0xFF1C1C1E),
  ).copyWith(
    primary: seedColor,
    secondary: const Color(0xFF64D2FF),
    surface: const Color(0xFF1C1C1E),
    surfaceContainerHighest: const Color(0xFF2C2C2E),
  );

  return _buildSharedThemeShell(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFF000000),
    cardColor: const Color(0xFF1C1C1E),
    cardRadius: 26,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  ).copyWith(
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      disabledColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      selectedColor: colorScheme.primary.withValues(alpha: 0.22),
      secondarySelectedColor: colorScheme.primary.withValues(alpha: 0.22),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      side: BorderSide(
        color: Colors.white.withValues(alpha: 0.06),
      ),
      brightness: Brightness.dark,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.24);
          }
          return colorScheme.surfaceContainerHighest;
        }),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        side: WidgetStateProperty.all(
          BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
  );
}

ThemeData _buildSharedThemeShell({
  required ColorScheme colorScheme,
  required Color scaffoldBackgroundColor,
  required Color cardColor,
  required double cardRadius,
  required PageTransitionsTheme pageTransitionsTheme,
}) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    pageTransitionsTheme: pageTransitionsTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Colors.white,
      ),
      toolbarTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 16,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: Colors.white12,
    ),
  );
}
