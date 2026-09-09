import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_state_providers.dart';
import 'providers/settings_provider.dart';
import 'ui/host/host_home.dart';
import 'ui/client/client_home.dart';
import 'ui/shared/role_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(deviceRoleProvider);
    final settings = ref.watch(settingsProvider);

    ThemeData buildTheme(Brightness brightness) {
      final isDark = brightness == Brightness.dark;
      final baseTextTheme = Typography.material2021().black.apply(
        fontFamily: '-apple-system',
        bodyColor: isDark ? Colors.white : const Color(0xFF111111),
        displayColor: isDark ? Colors.white : const Color(0xFF111111),
      );

      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF9F8F6),
        cardColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        dividerColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E2DC),
        
        // Custom Typography with tight letter spacing
        textTheme: baseTextTheme.copyWith(
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(letterSpacing: -0.2),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(letterSpacing: -0.2),
          titleLarge: baseTextTheme.titleLarge?.copyWith(letterSpacing: -0.4, fontWeight: FontWeight.w800),
          labelLarge: baseTextTheme.labelLarge?.copyWith(letterSpacing: -0.1, fontWeight: FontWeight.w700),
        ),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: brightness,
          surface: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          outline: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E2DC),
        ),

        // Structured component styles
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E2DC), width: 1),
          ),
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        ),
        
        appBarTheme: AppBarTheme(
          backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF9F8F6),
          foregroundColor: isDark ? Colors.white : const Color(0xFF111111),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111111),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
      );
    }

    final hostLightTheme = buildTheme(Brightness.light);
    final hostDarkTheme = buildTheme(Brightness.dark);

    final kitchenTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF030712),
      cardColor: const Color(0xFF1F2937),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF22C55E),
        surface: Color(0xFF1F2937),
        background: Color(0xFF030712),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1F2937),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFF374151), width: 1),
        ),
      ),
    );

    return MaterialApp(
      title: 'DartKDS',
      debugShowCheckedModeBanner: false,
      theme: role == DeviceRole.client ? kitchenTheme : hostLightTheme,
      darkTheme: role == DeviceRole.client ? kitchenTheme : hostDarkTheme,
      themeMode: role == DeviceRole.client ? ThemeMode.dark : settings.themeMode,
      home: _getHome(role),
    );
  }

  Widget _getHome(DeviceRole role) {
    switch (role) {
      case DeviceRole.host:
        return const HostHome();
      case DeviceRole.client:
        return const ClientHome();
      case DeviceRole.unset:
      default:
        return const RoleSelectionScreen();
    }
  }
}
