import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/service_providers.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hostIdentity = ref.watch(hostIdentityProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              // Branding Block - Minimalist & Industrial
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      color: theme.colorScheme.surface,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DARTKDS',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const Text(
                        'Go Warriors',
                        style: TextStyle(
                          color: Color(0xFF522323),
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'ASSIGN DEVICE ROLE',
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              // Server Host Card
              _buildRoleOption(
                context: context,
                title: 'PRIMARY HOST',
                subtitle: 'Order Intake & Local Server',
                description:
                    'This device will host the database and manage all connected displays.',
                icon: Icons.dns_outlined,
                accentColor: const Color(0xFF2563EB),
                onTap: () async {
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                          strokeWidth: 3,
                        ),
                      ),
                    );

                    final db = ref.read(databaseProvider);
                    await ref.read(hostServerProvider).start(db);
                    await Future.delayed(const Duration(milliseconds: 600));
                    ref
                        .read(hostIdentityProvider.notifier)
                        .setRole(HostRole.primary);
                    final identity = ref.read(hostIdentityProvider);
                    await ref
                        .read(discoveryServiceProvider)
                        .register(
                          8080,
                          hostId: identity.hostId,
                          role: 'primary',
                        );
                    ref
                        .read(syncServiceProvider)
                        .start(
                          identity.hostId,
                          ref.read(discoveryServiceProvider).discover(),
                        );
                    ref
                        .read(hostServerProvider)
                        .setIdentity(identity.hostId, 'primary');
                    ref.read(hostServerProvider).knownPeersProvider = () => ref
                        .read(syncServiceProvider)
                        .peers
                        .map(
                          (p) => {
                            'hostId': p.hostId,
                            'role': p.role,
                            'url': 'http://${p.address}:${p.port}',
                          },
                        )
                        .toList();

                    if (context.mounted) {
                      Navigator.pop(context);
                      ref.read(deviceRoleProvider.notifier).state =
                          DeviceRole.host;
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'INIT FAILED: $e',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFDC2626) : const Color(0xFF111111),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              // Backup Host Card
              _buildRoleOption(
                context: context,
                title: 'BACKUP HOST',
                subtitle: 'Failover & Sync Peer',
                description:
                    'Syncs all data from the primary host. Takes over if primary goes offline.',
                icon: Icons.sync_rounded,
                accentColor: const Color(0xFF7C3AED),
                onTap: () async {
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                          strokeWidth: 3,
                        ),
                      ),
                    );

                    final db = ref.read(databaseProvider);
                    await ref.read(hostServerProvider).start(db);
                    await Future.delayed(const Duration(milliseconds: 600));
                    ref
                        .read(hostIdentityProvider.notifier)
                        .setRole(HostRole.backup);
                    final identity = ref.read(hostIdentityProvider);
                    await ref
                        .read(discoveryServiceProvider)
                        .register(
                          8080,
                          hostId: identity.hostId,
                          role: 'backup',
                        );
                    ref
                        .read(syncServiceProvider)
                        .start(
                          identity.hostId,
                          ref.read(discoveryServiceProvider).discover(),
                        );
                    ref
                        .read(hostServerProvider)
                        .setIdentity(identity.hostId, 'backup');
                    ref.read(hostServerProvider).knownPeersProvider = () => ref
                        .read(syncServiceProvider)
                        .peers
                        .map(
                          (p) => {
                            'hostId': p.hostId,
                            'role': p.role,
                            'url': 'http://${p.address}:${p.port}',
                          },
                        )
                        .toList();

                    if (context.mounted) {
                      Navigator.pop(context);
                      ref.read(deviceRoleProvider.notifier).state =
                          DeviceRole.host;
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'INIT FAILED: $e',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFDC2626) : const Color(0xFF111111),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              // Kitchen Display Card
              _buildRoleOption(
                context: context,
                title: 'DISPLAY CLIENT',
                subtitle: 'Kitchen Prep / Expo Screen',
                description:
                    'Connects to a Host to view, track, and bump incoming orders.',
                icon: Icons.tablet_android_rounded,
                accentColor: const Color(0xFF059669),
                onTap: () {
                  ref.read(deviceRoleProvider.notifier).state =
                      DeviceRole.client;
                },
              ),
              const Spacer(flex: 2),
              const Align(
                alignment: Alignment.center,
                child: Text(
                  'STABLE BUILD v1.0.1',
                  style: TextStyle(
                    color: Color(0xFFBBBBBB),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.onSurface, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.hintColor,
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
