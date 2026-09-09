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

    final hostTheme = ThemeData(
      useMaterial3: true,
      brightness: settings.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: settings.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        surface: settings.themeMode == ThemeMode.dark ? const Color(0xFF1F2937) : Colors.white,
        background: settings.themeMode == ThemeMode.dark ? const Color(0xFF030712) : const Color(0xFFF9FAFB),
      ),
      scaffoldBackgroundColor: settings.themeMode == ThemeMode.dark ? const Color(0xFF030712) : const Color(0xFFF9FAFB),
      appBarTheme: AppBarTheme(
        backgroundColor: settings.themeMode == ThemeMode.dark ? const Color(0xFF1F2937) : Colors.white,
        foregroundColor: settings.themeMode == ThemeMode.dark ? Colors.white : const Color(0xFF111827),
        elevation: 0,
      ),
    );

    final kitchenTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF030712),
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
      theme: role == DeviceRole.client ? kitchenTheme : hostTheme,
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
