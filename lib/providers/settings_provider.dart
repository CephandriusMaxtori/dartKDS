import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final ThemeMode themeMode;
  final bool use24HourFormat;
  final String stationName;
  
  // Client specific settings
  final double clientTextScale;
  final double clientVolume;
  final bool clientHighContrast;

  AppSettings({
    this.themeMode = ThemeMode.light,
    this.use24HourFormat = false,
    this.stationName = 'Host',
    this.clientTextScale = 1.0,
    this.clientVolume = 1.0,
    this.clientHighContrast = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? use24HourFormat,
    String? stationName,
    double? clientTextScale,
    double? clientVolume,
    bool? clientHighContrast,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      stationName: stationName ?? this.stationName,
      clientTextScale: clientTextScale ?? this.clientTextScale,
      clientVolume: clientVolume ?? this.clientVolume,
      clientHighContrast: clientHighContrast ?? this.clientHighContrast,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences prefs;

  SettingsNotifier(this.prefs) : super(AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final themeIndex = prefs.getInt('themeMode') ?? 1; // Default to Light
    final use24h = prefs.getBool('use24HourFormat') ?? false;
    final name = prefs.getString('stationName') ?? 'Host';
    final textScale = prefs.getDouble('clientTextScale') ?? 1.0;
    final volume = prefs.getDouble('clientVolume') ?? 1.0;
    final highContrast = prefs.getBool('clientHighContrast') ?? false;

    state = AppSettings(
      themeMode: ThemeMode.values[themeIndex],
      use24HourFormat: use24h,
      stationName: name,
      clientTextScale: textScale,
      clientVolume: volume,
      clientHighContrast: highContrast,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> setUse24HourFormat(bool value) async {
    state = state.copyWith(use24HourFormat: value);
    await prefs.setBool('use24HourFormat', value);
  }

  Future<void> setStationName(String name) async {
    state = state.copyWith(stationName: name);
    await prefs.setString('stationName', name);
  }

  Future<void> setClientTextScale(double value) async {
    state = state.copyWith(clientTextScale: value);
    await prefs.setDouble('clientTextScale', value);
  }

  Future<void> setClientVolume(double value) async {
    state = state.copyWith(clientVolume: value);
    await prefs.setDouble('clientVolume', value);
  }

  Future<void> setClientHighContrast(bool value) async {
    state = state.copyWith(clientHighContrast: value);
    await prefs.setBool('clientHighContrast', value);
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return SettingsNotifier(prefs);
});
