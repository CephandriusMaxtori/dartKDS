import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../providers/service_providers.dart';
import '../../providers/client_state_provider.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/discovery_service.dart';

class ClientHome extends ConsumerStatefulWidget {
  const ClientHome({super.key});

  @override
  ConsumerState<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends ConsumerState<ClientHome> {
  bool _isConnected = false;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _discoverySub;
  final Map<String, DiscoveredHost> _knownHosts = {};
  String _deviceIp = '...';
  final _audioPlayer = AudioPlayer();
  late ConfettiController _confettiController;
  bool _isRushMode = false;
  DateTime _lastHeartbeat = DateTime.now();
  Timer? _connectionWatchdog;
  String? _lastConnectedHost;
  int? _lastConnectedPort;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchIp();
      _startDiscovery();
    });
  }

  Future<void> _playSound() async {
    final settings = ref.read(settingsProvider);
    try {
      await _audioPlayer.setVolume(settings.clientVolume);
      await _audioPlayer.play(AssetSource('notification.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void _handleIncomingMessage(String message) {
    _lastHeartbeat = DateTime.now();
    final data = jsonDecode(message);
    if (data['type'] == 'ping') return; // Just update heartbeat

    if (data['type'] == 'KitchenBroadcast') {
      _showBroadcastOverlay(data['message']);
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
    final finishedOrder = ref
        .read(clientStateProvider.notifier)
        .handleEvent(message);
    if (finishedOrder != null) {
      ref.read(recentBumpsProvider.notifier).add(finishedOrder);
    }
  }

  Future<void> _fetchIp() async {
    final interfaces = await NetworkInterface.list();
    final addr = interfaces
        .expand((i) => i.addresses)
        .where((a) => a.type == InternetAddressType.IPv4 && !a.isLoopback)
        .map((a) => a.address)
        .join(', ');
    if (mounted) setState(() => _deviceIp = addr);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _wsSubscription?.cancel();
    _connectionWatchdog?.cancel();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startDiscovery() {
    _discoverySub?.cancel();
    _discoverySub = ref
        .read(discoveryServiceProvider)
        .discover()
        .listen(
          (host) {
            if (!_isConnected && host.address.isNotEmpty) {
              _connectToHost(host.address, host.port);
            }
          },
          onError: (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Discovery error: $e')));
          },
        );
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
      debugPrint('Host connection error: $e');
      if (!manual) _startDiscovery();
      if (mounted) setState(() => _isConnected = false);
      return;
    }

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
        debugPrint('Connection stale ($diff s), reconnecting...');
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
            debugPrint('Host connection error: $e');
            _handleDisconnect();
          },
          onDone: () {
            debugPrint('Host connection closed.');
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

    // Auto-reconnect after a delay if we have last host
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

    if (!_isConnected) {
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
                  ref.read(deviceRoleProvider.notifier).state =
                      DeviceRole.unset;
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
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 16,
                          ),
                          itemCount: tickets.length,
                          itemBuilder: (context, index) {
                            final ticket = tickets[index];
                            return TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutBack,
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(50 * (1 - value), 0),
                                  child: Opacity(
                                    opacity: value.clamp(0.0, 1.0),
                                    child: child,
                                  ),
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
                          },
                        ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: 0, // right
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
                    blastDirection: 3.14, // left
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
              Text(
                'KDS ACTIVE • $_deviceIp',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
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
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.history, color: textColor),
                tooltip: 'Recall Bumps',
                onPressed: () => _showRecentBumpsDialog(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.settings, color: textColor),
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

  void _showBroadcastOverlay(String message) {
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign_rounded, color: Colors.white, size: 80),
            const SizedBox(height: 24),
            const Text(
              'IMPORTANT NOTIFICATION',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ACKNOWLEDGE',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClientSettings() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final settings = ref.watch(settingsProvider);
          final notifier = ref.read(settingsProvider.notifier);
          return AlertDialog(
            backgroundColor:
                settings.themeMode == ThemeMode.light &&
                    !settings.clientHighContrast
                ? Colors.white
                : const Color(0xFF1F2937),
            title: Text(
              'KDS SETTINGS',
              style: TextStyle(
                color:
                    settings.themeMode == ThemeMode.light &&
                        !settings.clientHighContrast
                    ? Colors.black
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text(
                    'APPEARANCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  subtitle: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
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
                const Divider(),
                const Text(
                  'TEXT SIZE',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: settings.clientTextScale,
                  min: 0.8,
                  max: 2.0,
                  divisions: 6,
                  activeColor: const Color(0xFF22C55E),
                  onChanged: (val) => notifier.setClientTextScale(val),
                ),
                const Text(
                  'ALERT VOLUME',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: settings.clientVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: const Color(0xFF22C55E),
                  onChanged: (val) => notifier.setClientVolume(val),
                ),
                SwitchListTile(
                  title: Text(
                    'HIGH CONTRAST',
                    style: TextStyle(
                      color:
                          settings.themeMode == ThemeMode.light &&
                              !settings.clientHighContrast
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
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
                      color:
                          settings.themeMode == ThemeMode.light &&
                              !settings.clientHighContrast
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    (ref.watch(stationTagProvider) ?? 'GENERAL').toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF22C55E),
                      letterSpacing: 0.5,
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
                    ref.read(deviceRoleProvider.notifier).state =
                        DeviceRole.unset;
                    Navigator.pop(context);
                  },
                ),
              ],
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

  Widget _buildEmptyState(bool isDark) {
    final textColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 120, color: textColor),
          const SizedBox(height: 16),
          Text(
            'QUEUE EMPTY',
            style: TextStyle(
              color: textColor,
              fontSize: 32,
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
                hintText: 'PORT (default 8080)',
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

    final elapsedMinutes = DateTime.now().difference(order.timestamp).inMinutes;
    final isDark =
        settings.themeMode == ThemeMode.dark || settings.clientHighContrast;
    final isLate = elapsedMinutes >= 15;

    final pulse = ref.watch(globalPulseProvider).value ?? 1.0;

    Color agingColor;
    if (elapsedMinutes < 5) {
      agingColor = const Color(0xFF22C55E); // Green
    } else if (elapsedMinutes < 10) {
      agingColor = const Color(0xFFFACC15); // Yellow
    } else {
      agingColor = const Color(0xFFDC2626); // Red
    }

    final displayItems = order.items.where((item) {
      if (stationFilter == 'GENERAL' || stationFilter == 'EXPO') return true;
      return item.stationTag.toUpperCase() == stationFilter.toUpperCase();
    }).toList();

    if (displayItems.isEmpty) return const SizedBox.shrink();

    final borderOpacity = isLate ? pulse : 1.0;

    return Material(
      color: settings.clientHighContrast
          ? Colors.black
          : (settings.themeMode == ThemeMode.light
                ? Colors.white
                : const Color(0xFF1F2937)),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: isRushMode ? 280 : 340,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: settings.clientHighContrast
                ? (elapsedMinutes >= 10
                      ? const Color(0xFFDC2626).withOpacity(borderOpacity)
                      : Colors.white)
                : agingColor.withOpacity(borderOpacity),
            width: settings.clientHighContrast ? 4 : 3,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isLate
              ? [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.3 * pulse),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(isRushMode ? 8 : 12),
              decoration: BoxDecoration(
                color: agingColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF374151)
                        : Colors.grey.shade300,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '#${order.uuid.substring(0, 4).toUpperCase()}${isRushMode ? "" : " • ${order.customerName.toUpperCase()}"}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: isRushMode ? 22 : 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${elapsedMinutes.clamp(0, 999)}m',
                        style: TextStyle(
                          color: agingColor,
                          fontSize: isRushMode ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
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
                          vertical: 16,
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
                                      size: 24,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    item.name.toUpperCase(),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
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
                                margin: const EdgeInsets.only(top: 8.0),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFACC15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: settings.clientHighContrast
                                      ? Border.all(
                                          color: Colors.black,
                                          width: 2,
                                        )
                                      : null,
                                  boxShadow: [
                                    if (!settings.clientHighContrast)
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: Text(
                                  item.modifiers.join(', ').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 1.1,
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
    );
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
          if (finishedOrder != null) {
            ref.read(recentBumpsProvider.notifier).add(finishedOrder);
          }
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
        height: 70,
        color: allBumped
            ? const Color(0xFF22C55E)
            : (isDark ? const Color(0xFF374151) : Colors.grey.shade300),
        alignment: Alignment.center,
        child: Text(
          allBumped ? 'FINISH TICKET' : 'BUMP ALL',
          style: TextStyle(
            color: allBumped
                ? Colors.black
                : (isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
