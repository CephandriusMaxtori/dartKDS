import 'dart:io' if (dart.library.js_interop) '../../../web_io_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/host_store_provider.dart';
import '../../../models/database.dart';
import '../../../models/connected_client.dart';
import '../../../services/host_server.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final clientsAsync = ref.watch(hostClientsProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader(context, 'CONNECTED CLIENTS'),
        _buildCard(
          theme,
          Column(
            children: [
              clientsAsync.when(
                data: (clients) {
                  if (clients.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.tablet_android, color: theme.hintColor),
                          const SizedBox(width: 12),
                          Text(
                            'No kitchen displays connected',
                            style: TextStyle(color: theme.hintColor),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: clients
                        .map(
                          (client) => ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.tablet_android,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              client.deviceName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('Station: ${client.currentStation}'),
                            trailing: TextButton(
                              onPressed: () =>
                                  _showReassignDialog(context, ref, client),
                              child: const Text('REASSIGN'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error loading clients: $e'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Color(0xFF2AA31F),
                ),
                title: const Text(
                  'Pair New Device',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Show connection QR code'),
                onTap: () => _showPairingQRCode(context, ref),
              ),
            ],
          ),
        ),
        _buildSectionHeader(context, 'NETWORK & BLUETOOTH'),
        _buildCard(
          theme,
          FutureBuilder<List<NetworkInterface>>(
            future: NetworkInterface.list(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final interfaces = snapshot.data!;
              final addresses = interfaces
                  .expand((i) => i.addresses)
                  .where((a) => a.type == InternetAddressType.IPv4 && !a.isLoopback)
                  .toList();
              // Ranked by the same function the host uses to advertise itself,
              // so the address shown here is the one a display should be pointed
              // at. These were two independent copies that could rank
              // differently, so the pairing QR code could hand a display an
              // address the host had not chosen for itself.
              addresses.sort(
                (a, b) => HostServer.rankLanAddress(
                  a.address,
                ).compareTo(HostServer.rankLanAddress(b.address)),
              );
              return Column(
                children: [
                  ...addresses.map(
                        (addr) => ListTile(
                          leading: Icon(
                            addr.address.startsWith('192.168.44')
                                ? Icons.bluetooth_audio
                                : Icons.wifi,
                            color: const Color(0xFF2AA31F),
                          ),
                          title: Text(
                            addr.address,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          subtitle: Text(
                            'Network Interface: ${addr.address.startsWith('192.168.44') ? "Bluetooth PAN" : "Local Network"}',
                          ),
                        ),
                      ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.wifi_tethering),
                    title: const Text(
                      'Wi-Fi Hotspot',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Share network via Wi-Fi Hotspot'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openHotspotSettings(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_bluetooth),
                    title: const Text(
                      'Bluetooth Tethering (PAN)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Share network via Bluetooth'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openBluetoothSettings(),
                  ),
                ],
              );
            },
          ),
        ),
        _buildSectionHeader(context, 'DISPLAY'),
        _buildCard(
          theme,
          SwitchListTile(
            title: const Text(
              'Keep Screen On',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Prevent the host screen from sleeping'),
            value: settings.keepScreenOn,
            onChanged: (val) => notifier.setKeepScreenOn(val),
            secondary: const Icon(
              Icons.wb_sunny_rounded,
              color: Color(0xFF2AA31F),
            ),
          ),
        ),
        _buildSectionHeader(context, 'FORMAT'),
        _buildCard(
          theme,
          Column(
            children: [
              SwitchListTile(
                title: const Text(
                  'Use 24-Hour Format',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('e.g. 14:30 instead of 2:30 PM'),
                value: settings.use24HourFormat,
                onChanged: (val) => notifier.setUse24HourFormat(val),
                secondary: const Icon(Icons.schedule_rounded),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text(
                  'Enable Confetti',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Show animations on order completion'),
                value: settings.enableConfetti,
                onChanged: (val) => notifier.setEnableConfetti(val),
                secondary: const Icon(
                  Icons.celebration_rounded,
                  color: Color(0xFF2AA31F),
                ),
              ),
            ],
          ),
        ),
        _buildSectionHeader(context, 'THEME'),
        _buildCard(
          theme,
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text(
              'Appearance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(settings.themeMode.name.toUpperCase()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context, ref),
          ),
        ),
        _buildSectionHeader(context, 'MORE'),
        _buildCard(
          theme,
          Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About KDS'),
                subtitle: const Text('Version 1.0.0'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Custom Offline KDS',
                    applicationVersion: '1.0.0',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.refresh, color: Color(0xFFDC2626)),
                title: const Text(
                  'Reset Application',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
                subtitle: const Text('Clear all orders and library data'),
                onTap: () => _showResetConfirmation(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCard(ThemeData theme, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          // Secondary label, so it follows the theme. A fixed mid-grey stayed
          // mid-grey in the high contrast KDS mode, where it all but vanished.
          color: Theme.of(context).hintColor,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showPairingQRCode(BuildContext context, WidgetRef ref) async {
    final interfaces = await NetworkInterface.list();
    final ips = interfaces
        .expand((i) => i.addresses)
        .where((a) => a.type == InternetAddressType.IPv4 && !a.isLoopback)
        .map((a) => a.address)
        .toList();

    if (ips.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No network connection found')),
        );
      }
      return;
    }

    // Same ranking the host applies to the address it advertises, so the pairing
    // code always points at the address the host itself would have chosen.
    ips.sort(
      (a, b) =>
          HostServer.rankLanAddress(a).compareTo(HostServer.rankLanAddress(b)),
    );

    String selectedIp = ips.first;

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            final pairingUrl = 'dartkds://connect?ip=$selectedIp&port=8080';
            return AlertDialog(
              title: const Text(
                'PAIR NEW DEVICE',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan this QR code from the KDS client to pair automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: pairingUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (ips.length > 1) ...[
                    const Text(
                      'Select Host IP:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<String>(
                      value: selectedIp,
                      isExpanded: true,
                      items: ips
                          .map(
                            (ip) => DropdownMenuItem(
                              value: ip,
                              child: Text(
                                ip,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedIp = val!),
                    ),
                  ] else
                    Text(
                      'HOST IP: $selectedIp',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  void _showReassignDialog(
    BuildContext context,
    WidgetRef ref,
    ConnectedClient client,
  ) {
    final store = ref.read(hostStoreProvider);

    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<StationData>>(
        stream: store.watchStations(),
        builder: (context, snapshot) {
          final stations = snapshot.data ?? [];
          return AlertDialog(
            title: Text('Reassign ${client.deviceName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: stations
                  .map(
                    (s) => ListTile(
                      title: Text(s.name),
                      onTap: () {
                        store.sendToClient(client.id, {
                          'type': 'SetStation',
                          'station': s.name,
                        });
                        Navigator.pop(context);
                      },
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openHotspotSettings() async {
    const String url =
        'intent:#Intent;action=android.settings.WIFI_TETHER_SETTINGS;end';
    try {
      await launchUrl(Uri.parse(url));
    } catch (_) {
      await launchUrl(Uri.parse('package:com.android.settings'));
    }
  }

  Future<void> _openBluetoothSettings() async {
    const String url =
        'intent:#Intent;action=android.settings.TETHER_SETTINGS;end';
    try {
      await launchUrl(Uri.parse(url));
    } catch (_) {
      await launchUrl(Uri.parse('package:com.android.settings'));
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'APPEARANCE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.2,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
            _themeTile(
              context,
              ref,
              'Light Mode',
              Icons.light_mode_outlined,
              ThemeMode.light,
              settings.themeMode,
            ),
            _themeTile(
              context,
              ref,
              'Dark Mode',
              Icons.dark_mode_outlined,
              ThemeMode.dark,
              settings.themeMode,
            ),
            _themeTile(
              context,
              ref,
              'System Default',
              Icons.settings_suggest_outlined,
              ThemeMode.system,
              settings.themeMode,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _themeTile(
    BuildContext context,
    WidgetRef ref,
    String label,
    IconData icon,
    ThemeMode mode,
    ThemeMode current,
  ) {
    final selected = current == mode;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.radio_button_unchecked, color: Color(0xFFB0B0B0)),
      onTap: () {
        ref.read(settingsProvider.notifier).setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text(
              'Reset Everything?',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete all menu items and your order history. This cannot be undone.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            // This used to only dismiss the dialog, so a button whose copy
            // promised to erase the kitchen's menu and history did nothing at
            // all. Wired to the real reset.
            onPressed: () async {
              Navigator.pop(context);
              await _resetEverything(context, ref);
            },
            child: const Text(
              'RESET',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Clears the menu library and order history, then tells the kitchen displays
  /// to drop what they are showing.
  ///
  /// The displays hold their tickets in memory and are not re-synced until they
  /// re-register, so without the broadcast every tablet keeps serving a board
  /// the host no longer has any record of.
  Future<void> _resetEverything(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text(
              'Delete for good?',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Menu items, stations and order history will be deleted, and every '
          'connected display will clear its board. This cannot be undone.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(hostStoreProvider).clearLibrary();
      await ref.read(hostStoreProvider).clearSalesAndHistory();
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'RESET COMPLETE',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          backgroundColor: Color(0xFF2AA31F),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      // Reported rather than swallowed: a reset that silently failed leaves the
      // host holding data the operator believes they destroyed.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'RESET FAILED: $e',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
