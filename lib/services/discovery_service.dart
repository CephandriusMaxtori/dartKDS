import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) '../web_io_stub.dart';
import 'package:nsd/nsd.dart' if (dart.library.js_interop) '../web_nsd_stub.dart' as nsd;

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
  bool _isAnnouncing = false;
  Duration _currentInterval = broadcastInterval;

  Future<void> register(
    int port, {
    String hostId = '',
    String role = 'primary',
  }) async {
    _serverPort = port;
    _hostId = hostId;
    _role = role;
    final service = nsd.Service(
      name:
          'KDS_Host_${hostId.isNotEmpty ? hostId.substring(0, 8) : DateTime.now().millisecondsSinceEpoch % 10000}',
      type: serviceType,
      port: port,
    );
    print(
      'DEBUG: Registering service: ${service.name} (${service.type}) on port $port',
    );

    // mDNS registration is best-effort. It fails for reasons well outside the
    // host's control — no network interface up yet, a VPN or container bridge,
    // a platform without an mDNS responder — and none of those should stop the
    // host from serving. Previously this threw straight out of `startHostServices`
    // and the host refused to boot at all.
    try {
      _registration = await nsd.register(service);
      print('DEBUG: Service registered successfully');
    } catch (e) {
      _registration = null;
      print('DEBUG: mDNS registration failed, falling back to UDP: $e');
    }

    // The UDP announcer runs either way. It is the mechanism that actually works
    // on the Android tablets this app targets, where mDNS resolution is spotty.
    _startBroadcastAnnouncer();
  }

  Future<void> stop() async {
    _isAnnouncing = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _announceSocket?.close();
    _announceSocket = null;
    if (_registration != null) {
      try {
        await nsd.unregister(_registration!);
      } catch (e) {
        // The responder may already be gone; nothing left to unregister.
        print('DEBUG: mDNS unregister failed: $e');
      }
      _registration = null;
    }
  }

  /// Held open across announcements. Binding a fresh socket every 2-30s leaked
  /// descriptors on a device that only has a handful to spare, and the sender
  /// has nothing to receive, so one long-lived socket is both cheaper and enough.
  RawDatagramSocket? _announceSocket;

  void _startBroadcastAnnouncer() {
    _isAnnouncing = true;
    _currentInterval = broadcastInterval;
    unawaited(_announceLoop());
  }

  Future<void> _announceLoop() async {
    if (!_isAnnouncing) return;

    await _announce();

    // Adaptive backoff: start at 2s, slowly increase to 30s to save
    // battery/bandwidth. Capped, and reset on `register()`, so a host that has
    // been up a while still announces promptly for a newly booted display.
    if (_currentInterval < _maxAnnounceInterval) {
      _currentInterval += const Duration(seconds: 2);
    }

    _broadcastTimer = Timer(_currentInterval, () => unawaited(_announceLoop()));
  }

  static const Duration _maxAnnounceInterval = Duration(seconds: 30);

  Future<void> _announce() async {
    RawDatagramSocket? socket = _announceSocket;
    if (socket == null) {
      try {
        socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );
        socket.broadcastEnabled = true;
        _announceSocket = socket;
      } catch (e) {
        print('DEBUG: Could not open announce socket: $e');
        return;
      }
    }
    try {
      final payload = utf8.encode(
        jsonEncode({
          'app': 'dartkds',
          'port': _serverPort,
          'hostId': _hostId,
          'role': _role,
        }),
      );

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
      // Socket intentionally left open and reused; see [_announceSocket].
    } catch (e) {
      print('DEBUG: Broadcast announce error: $e');
      // A send failure usually means the socket went bad. Drop it so the next
      // round reopens rather than announcing into a dead descriptor forever.
      _announceSocket?.close();
      _announceSocket = null;
    }
  }

  Stream<DiscoveredHost> discover() {
    final controller = StreamController<DiscoveredHost>();
    RawDatagramSocket? udpSocket;
    dynamic activeDiscovery;
    var stopped = false;

    void stopAll() {
      if (stopped) return;
      stopped = true;
      udpSocket?.close();
      udpSocket = null;
      if (activeDiscovery != null) {
        try {
          nsd.stopDiscovery(activeDiscovery);
        } catch (_) {}
        activeDiscovery = null;
      }
    }

    /// Both the mDNS listener and the UDP socket outlive the setup futures
    /// below, so they can fire after the screen cancelled and closed the
    /// controller. Adding to a closed controller throws inside a stream
    /// callback, which surfaces as an unhandled zone error.
    void publish(DiscoveredHost host) {
      if (stopped || controller.isClosed) return;
      controller.add(host);
    }

    controller.onListen = () {
      nsd
          .startDiscovery(serviceType, ipLookupType: nsd.IpLookupType.any)
          .then((discovery) {
            if (stopped) {
              // Cancelled between the request and the reply.
              try {
                nsd.stopDiscovery(discovery);
              } catch (_) {}
              return;
            }
            activeDiscovery = discovery;
            discovery.addServiceListener((service, status) {
              print('DEBUG: Discovery event: ${service.name} - $status');
              if (status == nsd.ServiceStatus.found) {
                if (service.addresses == null || service.addresses!.isEmpty) {
                  nsd
                      .resolve(service)
                      .then((resolved) {
                        print(
                          'DEBUG: Resolved service: ${resolved.name} at ${resolved.addresses}',
                        );
                        if (resolved.addresses != null &&
                            resolved.addresses!.isNotEmpty) {
                          publish(
                            DiscoveredHost(
                              resolved.addresses!.first.address,
                              resolved.port ?? 8080,
                            ),
                          );
                        }
                      })
                      // An unresolvable mDNS record used to become an unhandled
                      // async error, which can take the isolate down.
                      .catchError((Object e) {
                        print('DEBUG: mDNS resolve failed: $e');
                      });
                } else {
                  publish(
                    DiscoveredHost(
                      service.addresses!.first.address,
                      service.port ?? 8080,
                    ),
                  );
                }
              }
            });
          })
          // Same reason as above: discovery failing is expected on networks
          // without mDNS, and must not be fatal.
          .catchError((e) {
            print('DEBUG: Error starting mDNS discovery: $e');
          });

      RawDatagramSocket.bind(
            InternetAddress.anyIPv4,
            broadcastPort,
            reuseAddress: true,
          )
          .then((socket) {
            if (stopped) {
              socket.close();
              return;
            }
            udpSocket = socket;
            socket.listen(
              (event) {
                if (stopped) return;
                if (event == RawSocketEvent.read) {
                  final datagram = socket.receive();
                  if (datagram == null) return;
                  try {
                    final msg = jsonDecode(
                      utf8.decode(datagram.data, allowMalformed: true),
                    );
                    if (msg is Map && msg['app'] == 'dartkds') {
                      final port = (msg['port'] as num?)?.toInt() ?? 8080;
                      final hostId = msg['hostId'] as String?;
                      final role = msg['role'] as String?;
                      print(
                        'DEBUG: Broadcast discovery from ${datagram.address.address}:$port',
                      );
                      publish(
                        DiscoveredHost(
                          datagram.address.address,
                          port,
                          hostId: hostId,
                          role: role,
                        ),
                      );
                    }
                  } catch (_) {
                    // Not one of ours, or malformed. Announcements are
                    // unauthenticated LAN traffic; ignore anything unparseable.
                  }
                }
              },
              // A reset socket must not become an unhandled error.
              onError: (Object e) {
                print('DEBUG: UDP discovery socket error: $e');
                stopAll();
              },
              cancelOnError: true,
            );
          })
          .catchError((e) {
            print('DEBUG: Error starting UDP discovery: $e');
          });
    };

    controller.onCancel = stopAll;

    return controller.stream;
  }
}
