import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/service_providers.dart';
import 'responsive_utils.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTablet =
        Responsive.isTablet(context) || Responsive.isDesktop(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF020617), const Color(0xFF0F172A)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  _buildHeader(theme),
                  const Spacer(),
                  Text(
                    'ASSIGN DEVICE ROLE',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isTablet)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildRoleOption(
                            context: context,
                            ref: ref,
                            title: 'PRIMARY HOST',
                            subtitle: 'Order Intake',
                            description:
                                'Host database and manage kitchen displays.',
                            icon: Icons.dns_rounded,
                            accentColor: const Color(0xFF3B82F6),
                            role: HostRole.primary,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildRoleOption(
                            context: context,
                            ref: ref,
                            title: 'BACKUP HOST',
                            subtitle: 'Sync Peer',
                            description:
                                'Syncs all data and takes over if primary fails.',
                            icon: Icons.sync_rounded,
                            accentColor: const Color(0xFF8B5CF6),
                            role: HostRole.backup,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildRoleOption(
                            context: context,
                            ref: ref,
                            title: 'DISPLAY CLIENT',
                            subtitle: 'Kitchen Screen',
                            description: 'Prep / Expo screen for staff.',
                            icon: Icons.tablet_mac_rounded,
                            accentColor: const Color(0xFF10B981),
                            role: null,
                          ),
                        ),
                      ],
                    )
                  else
                    Expanded(
                      flex: 10,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildRoleOption(
                            context: context,
                            ref: ref,
                            title: 'PRIMARY HOST',
                            subtitle: 'Order Intake & Server',
                            description:
                                'This device will host the database and manage all connected displays.',
                            icon: Icons.dns_rounded,
                            accentColor: const Color(0xFF3B82F6),
                            role: HostRole.primary,
                          ),
                          const SizedBox(height: 16),
                          _buildRoleOption(
                            context: context,
                            ref: ref,
                            title: 'BACKUP HOST',
                            subtitle: 'Failover & Sync Peer',
                            description:
                                'Syncs all data from the primary host. Takes over if primary goes offline.',
                            icon: Icons.sync_rounded,
                            accentColor: const Color(0xFF8B5CF6),
                            role: HostRole.backup,
                          ),
                          const SizedBox(height: 16),
                          _buildRoleOption(
                            context: context,
                            ref: ref,
                            title: 'DISPLAY CLIENT',
                            subtitle: 'Kitchen Prep / Expo',
                            description:
                                'Connects to a Host to view, track, and bump incoming orders.',
                            icon: Icons.tablet_mac_rounded,
                            accentColor: const Color(0xFF10B981),
                            role: null,
                          ),
                        ],
                      ),
                    ),
                  const Spacer(flex: 2),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'DARTKDS v1.2.0 • BUILT FOR WARRIORS',
                      style: TextStyle(
                        color: theme.hintColor.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.restaurant_menu_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DARTKDS',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            Text(
              'Go Warriors',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleOption({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color accentColor,
    required HostRole? role,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _handleTap(context, ref, role);
          },
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? theme.dividerColor : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: theme.hintColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    HostRole? role,
  ) async {
    if (role == null) {
      ref.read(deviceRoleProvider.notifier).setRole(DeviceRole.client);
      return;
    }

    // On web the browser cannot run a server or DB — the WebHostHome widget
    // connects back to the native host that served this page.
    if (kIsWeb) {
      ref.read(hostIdentityProvider.notifier).setRole(role);
      ref.read(deviceRoleProvider.notifier).setRole(DeviceRole.host);
      return;
    }

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
      ref.read(hostIdentityProvider.notifier).setRole(role);

      final identity = ref.read(hostIdentityProvider);
      await ref
          .read(discoveryServiceProvider)
          .register(
            8080,
            hostId: identity.hostId,
            role: role == HostRole.primary ? 'primary' : 'backup',
          );

      ref
          .read(syncServiceProvider)
          .start(
            identity.hostId,
            ref.read(discoveryServiceProvider).discover(),
          );

      ref
          .read(hostServerProvider)
          .setIdentity(
            identity.hostId,
            role == HostRole.primary ? 'primary' : 'backup',
          );

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
        ref.read(deviceRoleProvider.notifier).setRole(DeviceRole.host);
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
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
