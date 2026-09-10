import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:nsd/nsd.dart' as nsd;

class DiscoveredHost {
  final String address;
  final int port;
  final String? hostId;
  final String? role;
  DiscoveredHost(this.address, this.port, {this.hostId, this.role});
}

class DiscoveryService {
  static const String serviceType = '_kdsapp._tcp';
  static const int broadcastPort = 41234;
  static const Duration broadcastInterval = Duration(seconds: 2);

  nsd.Registration? _registration;
  Timer? _broadcastTimer;
  int _serverPort = 8080;
  String _hostId = '';
  String _role = 'primary';

  Future<void> register(int port, {String hostId = '', String role = 'primary'}) async {
    _serverPort = port;
    _hostId = hostId;
    _role = role;
    final service = nsd.Service(
      name: 'KDS_Host_${hostId.isNotEmpty ? hostId.substring(0, 8) : DateTime.now().millisecondsSinceEpoch % 10000}',
      type: serviceType,
      port: port,
    );
    print('DEBUG: Registering service: ${service.name} (${service.type}) on port $port');
    _registration = await nsd.register(service);
    print('DEBUG: Service registered successfully');
    _startBroadcastAnnouncer();
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
  }

  void _startBroadcastAnnouncer() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(broadcastInterval, (_) => _announce());
    _announce();
  }

  Future<void> _announce() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true);
      socket.broadcastEnabled = true;
      final payload = utf8.encode(jsonEncode({
        'app': 'dartkds',
        'port': _serverPort,
        'hostId': _hostId,
        'role': _role,
      }));

      final targets = <String>{'255.255.255.255'};
      final interfaces = await NetworkInterface.list(includeLoopback: false);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
            }
          }
        }
      }

      for (final target in targets) {
        socket.send(payload, InternetAddress(target), broadcastPort);
      }

      socket.close();
    } catch (e) {
      print('DEBUG: Broadcast announce error: $e');
    }
  }

  Stream<DiscoveredHost> discover() {
    final controller = StreamController<DiscoveredHost>();
    RawDatagramSocket? udpSocket;
    dynamic activeDiscovery;

    void stopAll() {
      udpSocket?.close();
      udpSocket = null;
      if (activeDiscovery != null) {
        try {
          nsd.stopDiscovery(activeDiscovery);
        } catch (_) {}
        activeDiscovery = null;
      }
    }

    controller.onListen = () {
      nsd.startDiscovery(serviceType, ipLookupType: nsd.IpLookupType.any).then((discovery) {
        activeDiscovery = discovery;
        discovery.addServiceListener((service, status) {
          print('DEBUG: Discovery event: ${service.name} - $status');
          if (status == nsd.ServiceStatus.found) {
            if (service.addresses == null || service.addresses!.isEmpty) {
              nsd.resolve(service).then((resolved) {
                print('DEBUG: Resolved service: ${resolved.name} at ${resolved.addresses}');
                if (resolved.addresses != null && resolved.addresses!.isNotEmpty) {
                  controller.add(DiscoveredHost(resolved.addresses!.first.address, resolved.port ?? 8080));
                }
              });
            } else {
              controller.add(DiscoveredHost(service.addresses!.first.address, service.port ?? 8080));
            }
          }
        });
      }).catchError((e) {
        print('DEBUG: Error starting mDNS discovery: $e');
      });

      RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort, reuseAddress: true).then((socket) {
        udpSocket = socket;
        socket.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = socket.receive();
            if (datagram == null) return;
            try {
              final msg = jsonDecode(utf8.decode(datagram.data, allowMalformed: true));
              if (msg is Map && msg['app'] == 'dartkds') {
                final port = (msg['port'] as num?)?.toInt() ?? 8080;
                final hostId = msg['hostId'] as String?;
                final role = msg['role'] as String?;
                print('DEBUG: Broadcast discovery from ${datagram.address.address}:$port');
                controller.add(DiscoveredHost(datagram.address.address, port, hostId: hostId, role: role));
              }
            } catch (_) {}
          }
        });
      }).catchError((e) {
        print('DEBUG: Error starting UDP discovery: $e');
      });
    };

    controller.onCancel = stopAll;

    return controller.stream;
  }
}