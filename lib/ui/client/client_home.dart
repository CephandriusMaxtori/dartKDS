import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) '../../web_io_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../providers/service_providers.dart';
import '../../providers/client_state_provider.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/discovery_service.dart';
import '../../models/order_status.dart';
import '../shared/responsive_utils.dart';

class ClientHome extends ConsumerStatefulWidget {
  const ClientHome({super.key});

  @override
  ConsumerState<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends ConsumerState<ClientHome>
    with WidgetsBindingObserver {
  bool _isConnected = false;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _discoverySub;
  String _deviceIp = '...';
  final _audioPlayer = AudioPlayer();
  late ConfettiController _confettiController;
  bool _isRushMode = false;
  DateTime _lastHeartbeat = DateTime.now();
  Timer? _connectionWatchdog;
  String? _lastConnectedHost;
  int? _lastConnectedPort;
  int _discoveryRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    // Allow both orientations for flexibility, though landscape is preferred
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLastHostAndStart();
      _fetchIp();
    });
  }

  Future<void> _loadLastHostAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    _lastConnectedHost = prefs.getString('last_host');
    _lastConnectedPort = prefs.getInt('last_port');
    _startDiscovery();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Save battery by stopping discovery in background
      _discoverySub?.cancel();
      _connectionWatchdog?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (!_isConnected) _startDiscovery();
    }
  }

  Future<void> _playSound() async {
    final settings = ref.read(settingsProvider);
    try {
      await _audioPlayer.setVolume(settings.clientVolume);
      await _audioPlayer.play(AssetSource('notification.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _handleIncomingMessage(String message) {
    _lastHeartbeat = DateTime.now();
    final data = jsonDecode(message);
    if (data['type'] == 'ping') return;

    if (data['type'] == 'KitchenBroadcast') {
      _showBroadcastOverlay(
        data['message'],
        station: data['station']?.toString(),
      );
    }
    if (data['type'] == 'RushModeChanged') {
      if (mounted) setState(() => _isRushMode = data['enabled'] == true);
    }
    if (data['type'] == 'OrderCreated' || data['type'] == 'OrderUpdated') {
      final stationTag = ref.read(stationTagProvider) ?? 'GENERAL';
      bool shouldNotify = false;
      if (stationTag == 'GENERAL' || stationTag == 'EXPO') {
        shouldNotify = true;
      } else {
        final orderData = data['order'];
        final items = orderData['items'] as List;
        shouldNotify = items.any(
          (i) =>
              (i['stationTag'] as String).toUpperCase() ==
              stationTag.toUpperCase(),
        );
      }

      if (shouldNotify) {
        _playSound();
        HapticFeedback.vibrate();
      }
    }
    if (data['type'] == 'SetStation') {
      ref
          .read(stationTagProvider.notifier)
          .set((data['station'] as String).toUpperCase());
    }
    if (data['type'] == 'ReplayFinished') {
      final orderData = data['order'];
      final order = ClientOrder(
        uuid: orderData['uuid'],
        customerName: orderData['customerName'] ?? 'Guest',
        timestamp: DateTime.parse(orderData['timestamp']),
        status: OrderStatus.complete,
        items: (orderData['items'] as List)
            .map(
              (i) => ClientItem(
                uuid: i['uuid'],
                name: i['name'],
                modifiers: List<String>.from(i['modifiers'] ?? []),
                stationTag: i['stationTag'] ?? 'GENERAL',
                isBumped: true,
              ),
            )
            .toList(),
      );
      ref.read(recentBumpsProvider.notifier).add(order);
      return;
    }
    if (data['type'] == 'OrderDeleted') {
      final orderUuid = data['orderUuid'] as String?;
      if (orderUuid != null) {
        ref.read(clientStateProvider.notifier).removeOrder(orderUuid);
      }
      return;
    }
    final finishedOrder = ref
        .read(clientStateProvider.notifier)
        .handleEvent(message);
    if (finishedOrder != null) {
      ref.read(recentBumpsProvider.notifier).add(finishedOrder);
    }
  }

  Future<void> _fetchIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      final addr = interfaces
          .expand((i) => i.addresses)
          .where((a) => a.type == InternetAddressType.IPv4 && !a.isLoopback)
          .map((a) => a.address)
          .join(', ');
      if (mounted) setState(() => _deviceIp = addr.isEmpty ? 'NO IP' : addr);
    } catch (e) {
      if (mounted) setState(() => _deviceIp = 'ERROR');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _wsSubscription?.cancel();
    _discoverySub?.cancel();
    _connectionWatchdog?.cancel();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startDiscovery() async {
    _discoverySub?.cancel();
    _discoveryRetries = 0;

    // On web, mDNS/UDP discovery is unavailable — this page is usually served
    // by the host itself, so just connect back to the origin.
    if (kIsWeb) {
      final originHost = Uri.base.host;
      if (originHost.isNotEmpty && !_isConnected) {
        _connectToHost(originHost, 8080);
        return;
      }
    }

    // Direct attempt if we have cached credentials
    if (_lastConnectedHost != null &&
        _lastConnectedPort != null &&
        !_isConnected) {
      _connectToHost(_lastConnectedHost!, _lastConnectedPort!);
      return;
    }

    _listenForHosts();
  }

  void _listenForHosts() {
    _discoverySub?.cancel();
    _discoverySub = ref.read(discoveryServiceProvider).discover().listen((
      host,
    ) {
      if (!_isConnected && host.address.isNotEmpty) {
        _connectToHost(host.address, host.port);
      }
    }, onError: (e) => debugPrint('Discovery error: $e'));

    // Backoff logic for battery optimization
    Timer(const Duration(seconds: 30), () {
      if (!_isConnected && mounted) {
        _discoveryRetries++;
        if (_discoveryRetries > 2) {
          _discoverySub?.cancel();
          // Wait 60s before retrying to save battery
          Future.delayed(const Duration(seconds: 60), () {
            if (!_isConnected && mounted) _listenForHosts();
          });
        }
      }
    });
  }

  void _connectToHost(String host, int port, {bool manual = false}) async {
    final hostTrim = host.trim();
    if (hostTrim.isEmpty) return;
    _discoverySub?.cancel();

    final prefs = await SharedPreferences.getInstance();
    String? clientId = prefs.getString('client_uuid');
    if (clientId == null) {
      clientId = Uuid().v4();
      await prefs.setString('client_uuid', clientId);
    }

    try {
      await ref.read(clientServiceProvider).connect(hostTrim, port);
    } catch (e) {
      if (!manual) _startDiscovery();
      if (mounted) setState(() => _isConnected = false);
      return;
    }

    // Save successful connection for future boot speed & battery optimization
    await prefs.setString('last_host', hostTrim);
    await prefs.setInt('last_port', port);

    final registration = jsonEncode({
      'type': 'RegisterClient',
      'id': clientId,
      'deviceName': Platform.localHostname,
      'station': ref.read(stationTagProvider) ?? 'GENERAL',
    });

    ref.read(clientServiceProvider).send(registration);

    _lastConnectedHost = hostTrim;
    _lastConnectedPort = port;
    _lastHeartbeat = DateTime.now();

    _connectionWatchdog?.cancel();
    _connectionWatchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_isConnected) return;
      final diff = DateTime.now().difference(_lastHeartbeat).inSeconds;
      if (diff > 75) {
        _connectToHost(_lastConnectedHost!, _lastConnectedPort!);
      }
    });

    _wsSubscription?.cancel();
    _wsSubscription = ref
        .read(clientServiceProvider)
        .stream
        .listen(
          (message) {
            _handleIncomingMessage(message.toString());
          },
          onError: (e) {
            _handleDisconnect();
          },
          onDone: () {
            _handleDisconnect();
          },
        );
    if (mounted) {
      setState(() {
        _isConnected = true;
      });
    }
  }

  void _handleDisconnect() {
    if (mounted) {
      setState(() {
        _isConnected = false;
      });
    }
    _wsSubscription?.cancel();
    _connectionWatchdog?.cancel();

    if (_lastConnectedHost != null && _lastConnectedPort != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isConnected && mounted) {
          _connectToHost(_lastConnectedHost!, _lastConnectedPort!);
        }
      });
    } else {
      _startDiscovery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(filteredTicketsProvider);
    final stationTag = ref.watch(stationTagProvider) ?? 'GENERAL';
    final settings = ref.watch(settingsProvider);
    final timeFormat = settings.use24HourFormat ? 'HH:mm:ss' : 'h:mm:ss a';
    final isTablet =
        Responsive.isTablet(context) || Responsive.isDesktop(context);

    final isDark =
        settings.themeMode == ThemeMode.dark || settings.clientHighContrast;

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(settings.clientTextScale)),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: settings.clientHighContrast
                ? Colors.black
                : (settings.themeMode == ThemeMode.light
                      ? Colors.white
                      : const Color(0xFF030712)),
            body: Column(
              children: [
                _buildHeader(stationTag, timeFormat, settings),
                Expanded(
                  child: tickets.isEmpty
                      ? _buildEmptyState(isDark)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (isTablet) {
                              // Grid for tablets (denser = smaller tiles)
                              int crossCount = (constraints.maxWidth / 240)
                                  .floor()
                                  .clamp(1, 14);
                              return GridView.builder(
                                padding: const EdgeInsets.all(8),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossCount,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio:
                                          1.05, // shorter = smaller tiles
                                    ),
                                itemCount: tickets.length,
                                itemBuilder: (context, index) =>
                                    _buildAnimatedTicket(
                                      tickets[index],
                                      settings,
                                      stationTag,
                                    ),
                              );
                            } else {
                              // Horizontal list for phones
                              return ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                itemCount: tickets.length,
                                itemBuilder: (context, index) =>
                                    _buildAnimatedTicket(
                                      tickets[index],
                                      settings,
                                      stationTag,
                                    ),
                              );
                            }
                          },
                        ),
                ),
              ],
            ),
          ),
          _buildConfetti(),
        ],
      ),
    );
  }

  Widget _buildAnimatedTicket(
    ClientOrder ticket,
    AppSettings settings,
    String stationTag,
  ) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: RepaintBoundary(
        child: _TicketCard(
          key: ValueKey(ticket.uuid),
          order: ticket,
          stationFilter: stationTag,
          isRushMode: _isRushMode,
          onFinished: () {
            if (settings.enableConfetti) {
              _confettiController.play();
            }
          },
          settings: settings,
        ),
      ),
    );
  }

  Widget _buildConnectionScreen(String stationTag) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF22C55E)),
            const SizedBox(height: 24),
            const Text(
              'SEARCHING FOR KITCHEN HOST...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _showStationSelectionDialog(),
              child: Text('STATION: ${stationTag.toUpperCase()}'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showScannerDialog(context),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('SCAN QR CODE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() => _isConnected = false);
                _startDiscovery();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
              ),
              child: const Text('RE-SCAN FOR HOST'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _showManualConnectDialog(),
              child: const Text(
                'MANUAL CONNECT',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _discoverySub?.cancel();
                ref.read(deviceRoleProvider.notifier).setRole(DeviceRole.unset);
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScannerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'SCAN PAIRING CODE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        body: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null && code.startsWith('dartkds://connect')) {
                    final uri = Uri.parse(code);
                    final ip = uri.queryParameters['ip'];
                    final port =
                        int.tryParse(uri.queryParameters['port'] ?? '8080') ??
                        8080;

                    if (ip != null) {
                      Navigator.pop(context);
                      _connectToHost(ip, port, manual: true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pairing with $ip...'),
                          backgroundColor: const Color(0xFF22C55E),
                        ),
                      );
                      return;
                    }
                  }
                }
              },
            ),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfetti() {
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 0,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 100,
              minBlastForce: 80,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 100,
              minBlastForce: 80,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String station, String timeFormat, AppSettings settings) {
    final isDark =
        settings.themeMode == ThemeMode.dark || settings.clientHighContrast;
    final textColor = isDark ? Colors.white : Colors.black87;

    final bool highContrast = settings.clientHighContrast;
    final bool light = settings.themeMode == ThemeMode.light;
    final BoxDecoration decoration;
    if (highContrast) {
      decoration = const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
      );
    } else if (light) {
      decoration = BoxDecoration(
        color: Colors.grey.shade200,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      );
    } else {
      decoration = const BoxDecoration(color: Color(0xFF1F2937));
    }

    return Container(
      height: 60,
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showStationSelectionDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    station.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  if (!_isConnected) _showManualConnectDialog();
                },
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? const Color(0xFF22C55E)
                            : Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_isConnected)
                            BoxShadow(
                              color: const Color(0xFF22C55E).withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'KDS • $_deviceIp ${_isConnected ? "" : "(OFFLINE)"}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (context, snapshot) {
                  return RepaintBoundary(
                    child: Text(
                      DateFormat(timeFormat).format(DateTime.now()),
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'monospace',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.history, color: textColor, size: 20),
                onPressed: () => _showRecentBumpsDialog(),
              ),
              IconButton(
                icon: Icon(Icons.swap_horiz, color: textColor, size: 20),
                onPressed: () => _confirmSwitchRole(),
              ),
              IconButton(
                icon: Icon(Icons.settings, color: textColor, size: 20),
                onPressed: () => _showClientSettings(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRecentBumpsDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final recent = ref.watch(recentBumpsProvider);
          return AlertDialog(
            backgroundColor: const Color(0xFF1F2937),
            title: const Text(
              'RECENT BUMPS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: recent.isEmpty
                ? const Text(
                    'No recent bumps',
                    style: TextStyle(color: Colors.grey),
                  )
                : SizedBox(
                    width: 400,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: recent.length,
                      itemBuilder: (context, index) {
                        final order = recent[index];
                        return ListTile(
                          title: Text(
                            '#${order.uuid.substring(0, 4).toUpperCase()} - ${order.customerName.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('HH:mm:ss').format(order.timestamp),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                            ),
                            onPressed: () {
                              ref
                                  .read(clientStateProvider.notifier)
                                  .addOrder(order);
                              ref
                                  .read(recentBumpsProvider.notifier)
                                  .remove(order.uuid);
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'RECALL',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBroadcastOverlay(String message, {String? station}) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFDC2626),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 4),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.campaign_rounded, color: Colors.white, size: 80),
              const SizedBox(height: 24),
              const Text(
                'NOTIFICATION',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: 1.5,
                ),
              ),
              if (station != null && station.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'TO STATION: ${station.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                message.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ACKNOWLEDGE',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSwitchRole() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'SWITCH DEVICE ROLE?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: const Text(
          'Return to the role selection screen?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SWITCH ROLE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _wsSubscription?.cancel();
    ref.read(deviceRoleProvider.notifier).setRole(DeviceRole.unset);
  }

  void _showClientSettings() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final settings = ref.watch(settingsProvider);
          final notifier = ref.read(settingsProvider.notifier);
          final isLight =
              settings.themeMode == ThemeMode.light &&
              !settings.clientHighContrast;
          return AlertDialog(
            backgroundColor: isLight ? Colors.white : const Color(0xFF1F2937),
            title: Text(
              'KDS SETTINGS',
              style: TextStyle(
                color: isLight ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text(
                      'APPEARANCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode, size: 16),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode, size: 16),
                          ),
                        ],
                        selected: {
                          settings.themeMode == ThemeMode.system
                              ? ThemeMode.dark
                              : settings.themeMode,
                        },
                        onSelectionChanged: (val) =>
                            notifier.setThemeMode(val.first),
                      ),
                    ),
                  ),
                  const Divider(),
                  _buildSlider(
                    'TEXT SIZE',
                    settings.clientTextScale,
                    0.8,
                    2.0,
                    6,
                    (val) => notifier.setClientTextScale(val),
                  ),
                  _buildSlider(
                    'ALERT VOLUME',
                    settings.clientVolume,
                    0.0,
                    1.0,
                    null,
                    (val) => notifier.setClientVolume(val),
                  ),
                  SwitchListTile(
                    title: Text(
                      'HIGH CONTRAST',
                      style: TextStyle(
                        color: isLight ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    value: settings.clientHighContrast,
                    activeColor: const Color(0xFF22C55E),
                    onChanged: (val) => notifier.setClientHighContrast(val),
                  ),
                  SwitchListTile(
                    title: Text(
                      'ENABLE CONFETTI',
                      style: TextStyle(
                        color: isLight ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    value: settings.enableConfetti,
                    activeColor: const Color(0xFF22C55E),
                    onChanged: (val) => notifier.setEnableConfetti(val),
                  ),
                  ListTile(
                    title: const Text(
                      'CURRENT STATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      (ref.watch(stationTagProvider) ?? 'GENERAL')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showStationSelectionDialog();
                      },
                      child: const Text(
                        'CHANGE',
                        style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text(
                      'EXIT KITCHEN MODE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      ref
                          .read(deviceRoleProvider.notifier)
                          .setRole(DeviceRole.unset);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    int? divisions,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: const Color(0xFF22C55E),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 100, color: textColor),
          const SizedBox(height: 16),
          Text(
            'QUEUE EMPTY',
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  void _showStationSelectionDialog() {
    final controller = TextEditingController(
      text: ref.read(stationTagProvider),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'SET STATION NAME',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. GRILL, FRYER, EXPO',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              ref.read(stationTagProvider.notifier).set(controller.text);
              Navigator.pop(context);
            },
            child: const Text(
              'SAVE',
              style: TextStyle(color: Color(0xFF22C55E)),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualConnectDialog() {
    final controller = TextEditingController();
    final portController = TextEditingController(text: '8080');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'MANUAL CONNECT',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'HOST IP ADDRESS',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'PORT (8080)',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final port = int.tryParse(portController.text) ?? 8080;
              _connectToHost(controller.text, port, manual: true);
              Navigator.pop(context);
            },
            child: const Text(
              'CONNECT',
              style: TextStyle(color: Color(0xFF22C55E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends ConsumerStatefulWidget {
  final ClientOrder order;
  final String stationFilter;
  final VoidCallback? onFinished;
  final AppSettings settings;
  final bool isRushMode;

  const _TicketCard({
    super.key,
    required this.order,
    required this.stationFilter,
    this.onFinished,
    required this.settings,
    this.isRushMode = false,
  });

  @override
  ConsumerState<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends ConsumerState<_TicketCard> {
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final stationFilter = widget.stationFilter;
    final settings = widget.settings;
    final isRushMode = widget.isRushMode;
    final isTablet =
        Responsive.isTablet(context) || Responsive.isDesktop(context);

    final elapsedMinutes = DateTime.now().difference(order.timestamp).inMinutes;
    final isDark =
        settings.themeMode == ThemeMode.dark || settings.clientHighContrast;
    final isLate = elapsedMinutes >= 15;
    final pulse = ref.watch(globalPulseProvider).value ?? 1.0;

    Color agingColor;
    if (elapsedMinutes < 5)
      agingColor = const Color(0xFF22C55E);
    else if (elapsedMinutes < 10)
      agingColor = const Color(0xFFFACC15);
    else
      agingColor = const Color(0xFFDC2626);

    final displayItems = order.items.where((item) {
      if (stationFilter == 'GENERAL' || stationFilter == 'EXPO') return true;
      return item.stationTag.toUpperCase() == stationFilter.toUpperCase();
    }).toList();

    if (displayItems.isEmpty) return const SizedBox.shrink();

    final borderOpacity = isLate ? pulse : 1.0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: 1.0,
      child: Material(
        color: settings.clientHighContrast
            ? Colors.black
            : (settings.themeMode == ThemeMode.light
                  ? Colors.white
                  : const Color(0xFF0F172A)),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: isTablet
              ? null
              : (isRushMode ? 240 : 290), // Flexible width on tablet
          margin: isTablet
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: settings.clientHighContrast
                  ? (elapsedMinutes >= 10
                        ? const Color(0xFFDC2626).withOpacity(borderOpacity)
                        : Colors.white)
                  : agingColor.withOpacity(borderOpacity),
              width: settings.clientHighContrast ? 4 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Urgency Bar
              Container(height: 6, color: agingColor),
              Container(
                padding: EdgeInsets.all(isRushMode ? 8 : 12),
                decoration: BoxDecoration(
                  color: agingColor.withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (order.customerName.startsWith('SQ:'))
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SQ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              '#${order.uuid.substring(0, 4).toUpperCase()}${isRushMode ? "" : " • ${order.customerName.replaceFirst('SQ: ', '').toUpperCase()}"}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: isRushMode ? 16 : 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${elapsedMinutes.clamp(0, 999)}m',
                      style: TextStyle(
                        color: agingColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: displayItems.length,
                itemBuilder: (context, idx) {
                  final item = displayItems[idx];
                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final newValue = !item.isBumped;
                      ref
                          .read(clientServiceProvider)
                          .send(
                            jsonEncode({
                              'type': 'ItemBumped',
                              'orderUuid': order.uuid,
                              'itemUuid': item.uuid,
                              'isBumped': newValue,
                            }),
                          );
                      ref
                          .read(clientStateProvider.notifier)
                          .toggleItemBump(order.uuid, item.uuid);
                    },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: item.isBumped ? 0.3 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? const Color(0xFF374151)
                                  : Colors.grey.shade200,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (item.isBumped)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF22C55E),
                                      size: 20,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    item.name.toUpperCase(),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      decoration: item.isBumped
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.modifiers.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4.0),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFACC15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.modifiers.join(', ').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildFooter(displayItems, isDark),
          ],
        ),
      ),
    ));
  }

  Widget _buildFooter(List<ClientItem> items, bool isDark) {
    final order = widget.order;
    final onFinished = widget.onFinished;
    final allBumped = items.every((i) => i.isBumped);

    return InkWell(
      onTap: () {
        HapticFeedback.heavyImpact();
        if (allBumped) {
          ref
              .read(clientServiceProvider)
              .send(
                jsonEncode({'type': 'TicketFinished', 'orderUuid': order.uuid}),
              );
          onFinished?.call();
          final finishedOrder = ref
              .read(clientStateProvider.notifier)
              .removeOrder(order.uuid);
          if (finishedOrder != null)
            ref.read(recentBumpsProvider.notifier).add(finishedOrder);
        } else {
          for (var item in items) {
            if (!item.isBumped) {
              ref
                  .read(clientServiceProvider)
                  .send(
                    jsonEncode({
                      'type': 'ItemBumped',
                      'orderUuid': order.uuid,
                      'itemUuid': item.uuid,
                      'isBumped': true,
                    }),
                  );
              ref
                  .read(clientStateProvider.notifier)
                  .toggleItemBump(order.uuid, item.uuid);
            }
          }
        }
      },
      child: Container(
        height: 50,
        color: allBumped
            ? const Color(0xFF22C55E)
            : (isDark ? const Color(0xFF374151) : Colors.grey.shade300),
        alignment: Alignment.center,
        child: Text(
          allBumped ? 'FINISH' : 'BUMP ALL',
          style: TextStyle(
            color: allBumped
                ? Colors.black
                : (isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
