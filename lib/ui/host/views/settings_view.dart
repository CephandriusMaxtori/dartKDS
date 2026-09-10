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

    return ListView(
      children: [
        _buildSectionHeader('CONNECTED CLIENTS'),
        clientsAsync.when(
          data: (clients) {
            if (clients.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No kitchen displays connected', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              children: clients.map((client) => ListTile(
                leading: const Icon(Icons.tablet_android, color: Color(0xFF22C55E)),
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
        const Divider(),
        _buildSectionHeader('NETWORK & BLUETOOTH'),
        FutureBuilder<List<NetworkInterface>>(
          future: NetworkInterface.list(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final interfaces = snapshot.data!;
            
            bool hasBluetoothPan = interfaces.any((i) => 
                i.name.toLowerCase().contains('bt') || 
                i.name.toLowerCase().contains('bnep') || 
                i.name.toLowerCase().contains('pan'));

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
                ListTile(
                  leading: const Icon(Icons.wifi_tethering),
                  title: const Text('Wi-Fi Hotspot', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Share network via Wi-Fi Hotspot'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openHotspotSettings(),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_bluetooth),
                  title: const Text('Bluetooth Tethering (PAN)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Share network via Bluetooth'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openBluetoothSettings(),
                ),
              ],
            );
          },
        ),
        const Divider(),
        _buildSectionHeader('FORMAT'),
        SwitchListTile(
          title: const Text('Use 24-Hour Format', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('e.g. 14:30 instead of 2:30 PM'),
          value: settings.use24HourFormat,
          onChanged: (val) => notifier.setUse24HourFormat(val),
          activeColor: const Color(0xFF2563EB),
        ),
        SwitchListTile(
          title: const Text('Enable Confetti', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Show animations on order completion'),
          value: settings.enableConfetti,
          onChanged: (val) => notifier.setEnableConfetti(val),
          activeColor: const Color(0xFF2563EB),
        ),
        const Divider(),
        _buildSectionHeader('THEME'),
        ListTile(
          title: const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(settings.themeMode.name.toUpperCase()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showThemePicker(context, ref),
        ),
        const Divider(),
        _buildSectionHeader('MORE'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About KDS'),
          subtitle: const Text('Version 1.0.0'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Custom Offline KDS',
              applicationVersion: '1.0.0',
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.refresh, color: Color(0xFFDC2626)),
          title: const Text('Reset Application', style: TextStyle(color: Color(0xFFDC2626))),
          subtitle: const Text('Clear all orders and library data'),
          onTap: () => _showResetConfirmation(context, ref),
        ),
      ],
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Light Mode'),
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Dark Mode'),
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('System Default'),
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Everything?'),
        content: const Text('This will permanently delete all menu items and your order history. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              // Implementation of full reset logic
              Navigator.pop(context);
            },
            child: const Text('RESET', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }
}
