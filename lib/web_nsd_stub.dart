// Stub for the nsd package on web — mDNS is not available in browsers.

import 'web_io_stub.dart';

class Service {
  final String name;
  final String type;
  final int? port;
  List<InternetAddress>? addresses;
  Service({required this.name, required this.type, this.port});
}

class Registration {}

enum ServiceStatus { found, resolved, failed }

class Discovery {
  void addServiceListener(
    void Function(Service service, ServiceStatus status) listener,
  ) {}
}

Future<Registration> register(Service service) async =>
    throw UnsupportedError('mDNS registration is not available on web');
Future<void> unregister(Registration registration) async {}
Future<Discovery> startDiscovery(String type,
        {dynamic ipLookupType}) async =>
    throw UnsupportedError('mDNS discovery is not available on web');
Future<void> stopDiscovery(Discovery discovery) async {}
Future<Service> resolve(Service service) async => service;

enum IpLookupType { any, local }