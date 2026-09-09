import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/service_providers.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712), // Deep charcoal background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Logo/Branding
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 80,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'DART KDS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'OFFLINE KITCHEN ECOSYSTEM',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              const Text(
                'SELECT DEVICE ROLE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              // Role Cards
              _buildRoleCard(
                context: context,
                title: 'SERVER HOST',
                subtitle: 'Manage menu & take orders',
                description: 'Runs the database and web server.',
                icon: Icons.dns,
                color: const Color(0xFF2563EB),
                onTap: () async {
                  try {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );
                    
                    await ref.read(hostServerProvider).start();
                    await Future.delayed(const Duration(milliseconds: 500));
                    await ref.read(discoveryServiceProvider).register(8080);
                    
                    if (context.mounted) {
                      Navigator.pop(context); // Remove loading
                      ref.read(deviceRoleProvider.notifier).state = DeviceRole.host;
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Remove loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to start Host: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context: context,
                title: 'KITCHEN DISPLAY',
                subtitle: 'View & bump orders',
                description: 'Prep line or expo display screen.',
                icon: Icons.tablet_android,
                color: const Color(0xFF22C55E),
                onTap: () {
                  ref.read(deviceRoleProvider.notifier).state = DeviceRole.client;
                },
              ),
              const Spacer(flex: 2),
              const Text(
                'v1.0.0 • AIR-GAPPED READY',
                style: TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF374151), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF4B5563)),
            ],
          ),
        ),
      ),
    );
  }
}
