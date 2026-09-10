import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';

enum DeviceRole { unset, host, client }

final deviceRoleProvider = StateProvider<DeviceRole>((ref) => DeviceRole.unset);

class StationTagNotifier extends StateNotifier<String?> {
  final SharedPreferences prefs;

  StationTagNotifier(this.prefs) : super(_loadStation(prefs));

  static String? _loadStation(SharedPreferences prefs) {
    final saved = prefs.getString('client_station');
    if (saved == null || saved.isEmpty) return null;
    return saved.toUpperCase();
  }

  void set(String station) {
    final normalized = station.trim().toUpperCase();
    state = normalized.isEmpty ? null : normalized;
    prefs.setString('client_station', normalized);
  }
}

final stationTagProvider =
    StateNotifierProvider<StationTagNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return StationTagNotifier(prefs);
});

final hostTabIndexProvider = StateProvider<int>((ref) => 0);
