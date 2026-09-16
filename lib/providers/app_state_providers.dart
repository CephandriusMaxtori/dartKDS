import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'settings_provider.dart';

enum DeviceRole { unset, host, client }

enum HostRole { primary, backup }

class DeviceRoleNotifier extends StateNotifier<DeviceRole> {
  final SharedPreferences prefs;

  DeviceRoleNotifier(this.prefs) : super(_load(prefs));

  static DeviceRole _load(SharedPreferences prefs) {
    final roleIndex = prefs.getInt('device_role') ?? DeviceRole.unset.index;
    if (roleIndex >= DeviceRole.values.length) return DeviceRole.unset;
    return DeviceRole.values[roleIndex];
  }

  void setRole(DeviceRole role) {
    state = role;
    prefs.setInt('device_role', role.index);
  }
}

final deviceRoleProvider =
    StateNotifierProvider<DeviceRoleNotifier, DeviceRole>((ref) {
      final prefs = ref.watch(sharedPrefsProvider);
      return DeviceRoleNotifier(prefs);
    });

class HostIdentityNotifier extends StateNotifier<HostIdentity> {
  final SharedPreferences prefs;

  HostIdentityNotifier(this.prefs) : super(_load(prefs));

  static HostIdentity _load(SharedPreferences prefs) {
    var hostId = prefs.getString('host_id');
    if (hostId == null || hostId.isEmpty) {
      hostId = const Uuid().v4();
      prefs.setString('host_id', hostId);
    }
    final roleStr = prefs.getString('host_role');
    final role = roleStr == 'backup' ? HostRole.backup : HostRole.primary;
    return HostIdentity(hostId: hostId, role: role);
  }

  void setRole(HostRole role) {
    state = HostIdentity(hostId: state.hostId, role: role);
    prefs.setString(
      'host_role',
      role == HostRole.backup ? 'backup' : 'primary',
    );
  }
}

class HostIdentity {
  final String hostId;
  final HostRole role;
  const HostIdentity({required this.hostId, required this.role});
}

final hostIdentityProvider =
    StateNotifierProvider<HostIdentityNotifier, HostIdentity>((ref) {
      final prefs = ref.watch(sharedPrefsProvider);
      return HostIdentityNotifier(prefs);
    });

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

final stationTagProvider = StateNotifierProvider<StationTagNotifier, String?>((
  ref,
) {
  final prefs = ref.watch(sharedPrefsProvider);
  return StationTagNotifier(prefs);
});

final hostTabIndexProvider = StateProvider<int>((ref) => 0);
final libraryTabIndexProvider = StateProvider<int>((ref) => 0);
final rushModeProvider = StateProvider<bool>((ref) => false);

final globalPulseProvider = StreamProvider<double>((ref) {
  return Stream.periodic(const Duration(milliseconds: 50), (count) {
    final progress = (count % 16) / 16.0;
    return progress < 0.5 ? progress * 2 : (1.0 - progress) * 2;
  });
});
