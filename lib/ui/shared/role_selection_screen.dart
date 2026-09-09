import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/service_providers.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F6), // Warm Neutral Stone
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
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DARTKDS',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      Text(
                        'SYSTEM INITIALIZATION',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'ASSIGN DEVICE ROLE',
                style: TextStyle(
                  color: Color(0xFF666666),
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
                description: 'This device will host the database and manage all connected displays.',
                icon: Icons.dns_outlined,
                accentColor: const Color(0xFF2563EB),
                onTap: () async {
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF111111), strokeWidth: 3)),
                    );
                    
                    await ref.read(hostServerProvider).start();
                    await Future.delayed(const Duration(milliseconds: 600));
                    await ref.read(discoveryServiceProvider).register(8080);
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ref.read(deviceRoleProvider.notifier).state = DeviceRole.host;
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('INIT FAILED: $e', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          backgroundColor: const Color(0xFF111111),
                          behavior: SnackBarBehavior.floating,
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
                description: 'Connects to a Host to view, track, and bump incoming orders.',
                icon: Icons.tablet_android_rounded,
                accentColor: const Color(0xFF059669),
                onTap: () {
                  ref.read(deviceRoleProvider.notifier).state = DeviceRole.client;
                },
              ),
              const Spacer(flex: 2),
              const Align(
                alignment: Alignment.center,
                child: Text(
                  'STABLE BUILD v1.0.1 • AIR-GAPPED OFFLINE PROTOCOL',
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E2DC), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF111111), size: 24),
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
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFDDDDDD), size: 14),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF666666),
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
