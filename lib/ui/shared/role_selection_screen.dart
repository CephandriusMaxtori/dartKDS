import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/service_providers.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Device Role')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              height: 100,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await ref.read(hostServerProvider).start();
                    // Small delay to ensure server is bound
                    await Future.delayed(const Duration(milliseconds: 500));
                    await ref.read(discoveryServiceProvider).register(8080);
                    if (context.mounted) {
                      ref.read(deviceRoleProvider.notifier).state = DeviceRole.host;
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to start Host: $e')),
                      );
                    }
                  }
                },
                child: const Text(
                  'HOST\n(Order Intake + Server)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 300,
              height: 100,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(deviceRoleProvider.notifier).state = DeviceRole.client;
                },
                child: const Text(
                  'CLIENT\n(Prep / Expo Display)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
