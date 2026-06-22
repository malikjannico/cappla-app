import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'color_schemes.dart';
import 'theme_extensions.dart';
import 'typography.dart';

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: lightColorScheme,
      textTheme: appTextTheme.apply(
        bodyColor: lightColorScheme.primary,
        displayColor: lightColorScheme.primary,
      ),
      iconTheme: IconThemeData(
        color: lightColorScheme.primary,
      ),
      primaryIconTheme: IconThemeData(
        color: lightColorScheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: lightColorScheme.primary),
        floatingLabelStyle: TextStyle(color: lightColorScheme.primary),
        hintStyle: TextStyle(color: lightColorScheme.primary.withValues(alpha: 0.5)),
        prefixStyle: TextStyle(color: lightColorScheme.primary),
        suffixStyle: TextStyle(color: lightColorScheme.primary),
        iconColor: lightColorScheme.primary,
        prefixIconColor: lightColorScheme.primary,
        suffixIconColor: lightColorScheme.primary,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: lightColorScheme.primary, width: 1.0),
          borderRadius: BorderRadius.circular(12.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: lightColorScheme.primary, width: 2.0),
          borderRadius: BorderRadius.circular(12.0),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: lightColorScheme.primary, width: 1.0),
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      scaffoldBackgroundColor: const Color(
        0xFFFAF8FF,
      ), // Background color from M3 spec
      pageTransitionsTheme: kIsWeb
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: NoTransitionsBuilder(),
                TargetPlatform.iOS: NoTransitionsBuilder(),
                TargetPlatform.macOS: NoTransitionsBuilder(),
                TargetPlatform.windows: NoTransitionsBuilder(),
                TargetPlatform.linux: NoTransitionsBuilder(),
                TargetPlatform.fuchsia: NoTransitionsBuilder(),
              },
            )
          : null,
      appBarTheme: AppBarTheme(
        backgroundColor: lightColorScheme.surface,
        foregroundColor: lightColorScheme.onSurface,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: lightColorScheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // M3 Corner/Medium
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightColorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0), // M3 Corner/Extra-large
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          fixedSize: WidgetStateProperty.all(const Size.fromWidth(250)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFBFFF00),
          foregroundColor: const Color(0xFF001450),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBFFF00),
          foregroundColor: const Color(0xFF001450),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: lightColorScheme.secondary,
        checkmarkColor: Colors.white,
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: Colors.white);
          }
          return TextStyle(color: lightColorScheme.primary);
        }),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: lightColorScheme.primary,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      extensions: const [AppColorsExtension.light],
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      textTheme: appTextTheme,
      scaffoldBackgroundColor: const Color(
        0xFF121318,
      ), // Dark Background color from M3 spec
      pageTransitionsTheme: kIsWeb
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: NoTransitionsBuilder(),
                TargetPlatform.iOS: NoTransitionsBuilder(),
                TargetPlatform.macOS: NoTransitionsBuilder(),
                TargetPlatform.windows: NoTransitionsBuilder(),
                TargetPlatform.linux: NoTransitionsBuilder(),
                TargetPlatform.fuchsia: NoTransitionsBuilder(),
              },
            )
          : null,
      appBarTheme: AppBarTheme(
        backgroundColor: darkColorScheme.surface,
        foregroundColor: darkColorScheme.onSurface,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: darkColorScheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // M3 Corner/Medium
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkColorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0), // M3 Corner/Extra-large
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          fixedSize: WidgetStateProperty.all(const Size.fromWidth(250)),
        ),
      ),
      extensions: const [AppColorsExtension.dark],
    );
  }
}
