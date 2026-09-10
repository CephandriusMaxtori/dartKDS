import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../models/database.dart';
import '../../../models/connected_client.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final clientsAsync = ref.watch(connectedClientsProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader('CONNECTED CLIENTS'),
        _buildCard(
          theme,
          clientsAsync.when(
            data: (clients) {
              if (clients.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.tablet_android, color: Color(0xFF6B7280)),
                      SizedBox(width: 12),
                      Text('No kitchen displays connected', style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                );
              }
              return Column(
                children: clients.map((client) => ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                    child: const Icon(Icons.tablet_android, color: Colors.white, size: 18),
                  ),
                  title: Text(client.deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Station: ${client.currentStation}'),
                  trailing: TextButton(
                    onPressed: () => _showReassignDialog(context, ref, client),
                    child: const Text('REASSIGN'),
                  ),
                )).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => Text('Error loading clients: $e'),
          ),
        ),
        _buildSectionHeader('NETWORK & BLUETOOTH'),
        _buildCard(
          theme,
          FutureBuilder<List<NetworkInterface>>(
            future: NetworkInterface.list(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final interfaces = snapshot.data!;
              return Column(
                children: [
                  ...interfaces.expand((i) => i.addresses).where((a) => a.type == InternetAddressType.IPv4).map((addr) => ListTile(
                    leading: Icon(
                      addr.address.startsWith('192.168.44') ? Icons.bluetooth_audio : Icons.wifi,
                      color: const Color(0xFF2563EB),
                    ),
                    title: Text(addr.address, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    subtitle: Text('Network Interface: ${addr.address.startsWith('192.168.44') ? "Bluetooth PAN" : "Local Network"}'),
                  )),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.wifi_tethering),
                    title: const Text('Wi-Fi Hotspot', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Share network via Wi-Fi Hotspot'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openHotspotSettings(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_bluetooth),
                    title: const Text('Bluetooth Tethering (PAN)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Share network via Bluetooth'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openBluetoothSettings(),
                  ),
                ],
              );
            },
          ),
        ),
        _buildSectionHeader('FORMAT'),
        _buildCard(
          theme,
          Column(
            children: [
              SwitchListTile(
                title: const Text('Use 24-Hour Format', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('e.g. 14:30 instead of 2:30 PM'),
                value: settings.use24HourFormat,
                onChanged: (val) => notifier.setUse24HourFormat(val),
                secondary: const Icon(Icons.schedule_rounded),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Enable Confetti', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Show animations on order completion'),
                value: settings.enableConfetti,
                onChanged: (val) => notifier.setEnableConfetti(val),
                secondary: const Icon(Icons.celebration_rounded, color: Color(0xFF2563EB)),
              ),
            ],
          ),
        ),
        _buildSectionHeader('THEME'),
        _buildCard(
          theme,
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(settings.themeMode.name.toUpperCase()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context, ref),
          ),
        ),
        _buildSectionHeader('MORE'),
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
                title: const Text('Reset Application', style: TextStyle(color: Color(0xFFDC2626))),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showReassignDialog(BuildContext context, WidgetRef ref, ConnectedClient client) {
    final db = ref.read(databaseProvider);
    
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<StationData>>(
        stream: db.select(db.stations).watch(),
        builder: (context, snapshot) {
          final stations = snapshot.data ?? [];
          return AlertDialog(
            title: Text('Reassign ${client.deviceName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: stations.map((s) => ListTile(
                title: Text(s.name),
                onTap: () {
                  ref.read(hostServerProvider).sendToClient(client.id, {
                    'type': 'SetStation',
                    'station': s.name,
                  });
                  Navigator.pop(context);
                },
              )).toList(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openHotspotSettings() async {
    const String url = 'intent:#Intent;action=android.settings.WIFI_TETHER_SETTINGS;end';
    try {
      await launchUrl(Uri.parse(url));
    } catch (_) {
      await launchUrl(Uri.parse('package:com.android.settings'));
    }
  }

  Future<void> _openBluetoothSettings() async {
    const String url = 'intent:#Intent;action=android.settings.TETHER_SETTINGS;end';
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
                child: Text('APPEARANCE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: Color(0xFF6B7280))),
              ),
            ),
            _themeTile(context, ref, 'Light Mode', Icons.light_mode_outlined, ThemeMode.light, settings.themeMode),
            _themeTile(context, ref, 'Dark Mode', Icons.dark_mode_outlined, ThemeMode.dark, settings.themeMode),
            _themeTile(context, ref, 'System Default', Icons.settings_suggest_outlined, ThemeMode.system, settings.themeMode),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _themeTile(BuildContext context, WidgetRef ref, String label, IconData icon, ThemeMode mode, ThemeMode current) {
    final selected = current == mode;
    return ListTile(
      leading: Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : null),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
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
            Text('Reset Everything?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: const Text('This will permanently delete all menu items and your order history. This cannot be undone.', style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('RESET', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
