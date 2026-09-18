import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_state_providers.dart';
import 'providers/settings_provider.dart';
import 'ui/host/host_home.dart';
import 'ui/client/client_home.dart';
import 'ui/shared/role_selection_screen.dart';
import 'ui/webhost/web_host_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(deviceRoleProvider);
    final settings = ref.watch(settingsProvider);

    ThemeData buildTheme(Brightness brightness) {
      final isDark = brightness == Brightness.dark;
      final baseTextTheme = (isDark ? ThemeData.dark() : ThemeData.light())
          .textTheme
          .apply(
            fontFamily: 'Lexend',
            bodyColor: isDark
                ? const Color(0xFFF1F5F9)
                : const Color(0xFF0F172A),
            displayColor: isDark
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0F172A),
          );

      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        fontFamily: 'Lexend',
        scaffoldBackgroundColor: isDark
            ? const Color(0xFF020617)
            : const Color(0xFFF8FAFC),
        cardColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        dividerColor: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFE2E8F0),

        textTheme: baseTextTheme.copyWith(
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(letterSpacing: -0.1),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(letterSpacing: -0.1),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            letterSpacing: -0.5,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            letterSpacing: 0.2,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: brightness,
          surface: isDark ? const Color(0xFF0F172A) : Colors.white,
          outline: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          primary: const Color(0xFF3B82F6),
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: isDark
              ? const Color(0xFF020617)
              : const Color(0xFFF8FAFC),
          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            fontFamily: 'Lexend',
            color: Colors
                .white, // Will be overridden by buildTheme usage if needed
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          hintStyle: TextStyle(
            fontWeight: FontWeight.normal,
            color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            backgroundColor: isDark
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0F172A),
            foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isDark
              ? const Color(0xFFF8FAFC)
              : const Color(0xFF0F172A),
          contentTextStyle: const TextStyle(
            fontFamily: 'Lexend',
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    final hostLightTheme = buildTheme(Brightness.light);
    final hostDarkTheme = buildTheme(Brightness.dark);

    final kitchenTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Lexend',
      scaffoldBackgroundColor: const Color(0xFF020617),
      cardColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF10B981),
        surface: Color(0xFF0F172A),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0F172A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF1E293B), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    return MaterialApp(
      title: 'DartKDS',
      debugShowCheckedModeBanner: false,
      theme: role == DeviceRole.client ? kitchenTheme : hostLightTheme,
      darkTheme: role == DeviceRole.client ? kitchenTheme : hostDarkTheme,
      themeMode: role == DeviceRole.client
          ? ThemeMode.dark
          : settings.themeMode,
      home: _getHome(role),
    );
  }

  Widget _getHome(DeviceRole role) {
    switch (role) {
      case DeviceRole.host:
        // On web, the browser cannot run the Shelf server/Drift — route to the
        // web host UI which connects back to the native host over WebSocket.
        if (kIsWeb) return const WebHostHome();
        return const HostHome();
      case DeviceRole.client:
        return const ClientHome();
      case DeviceRole.unset:
      default:
        return const RoleSelectionScreen();
    }
  }
}
