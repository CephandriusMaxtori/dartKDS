import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DeviceRole { unset, host, client }

final deviceRoleProvider = StateProvider<DeviceRole>((ref) => DeviceRole.unset);

final stationTagProvider = StateProvider<String?>((ref) => null);
