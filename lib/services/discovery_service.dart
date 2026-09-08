import 'dart:async';
import 'package:nsd/nsd.dart' as nsd;

class DiscoveryService {
  static const String serviceType = '_kdsapp._tcp';
  nsd.Registration? _registration;

  Future<void> register(int port) async {
    final service = nsd.Service(
      name: 'KDS_Host_${DateTime.now().millisecondsSinceEpoch % 10000}',
      type: serviceType,
      port: port,
    );
    print('DEBUG: Registering service: ${service.name} (${service.type}) on port $port');
    _registration = await nsd.register(service);
    print('DEBUG: Service registered successfully');
  }

  Future<void> stop() async {
    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
  }

  Stream<nsd.Service> discover() {
    final controller = StreamController<nsd.Service>();
    
    print('DEBUG: Starting discovery for $serviceType');
    
    // Start discovery with automatic resolution
    nsd.startDiscovery(serviceType, ipLookupType: nsd.IpLookupType.any).then((discovery) {
      // Periodically trigger a re-resolve or check if something new came up
      // though addServiceListener should handle it.
      
      discovery.addServiceListener((service, status) {
        print('DEBUG: Discovery event: ${service.name} - $status');
        if (status == nsd.ServiceStatus.found) {
          // If addresses are missing, try to resolve it explicitly
          if (service.addresses == null || service.addresses!.isEmpty) {
             nsd.resolve(service).then((resolved) {
                print('DEBUG: Resolved service: ${resolved.name} at ${resolved.addresses}');
                controller.add(resolved);
             });
          } else {
            controller.add(service);
          }
        }
      });
      
      controller.onCancel = () {
        print('DEBUG: Stopping discovery');
        nsd.stopDiscovery(discovery);
      };
    }).catchError((e) {
      print('DEBUG: Error starting discovery: $e');
      controller.addError(e);
    });

    return controller.stream;
  }
}
