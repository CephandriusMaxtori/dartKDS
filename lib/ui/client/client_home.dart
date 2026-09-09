import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../providers/service_providers.dart';
import '../../providers/client_state_provider.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/settings_provider.dart';

class ClientHome extends ConsumerStatefulWidget {
  const ClientHome({super.key});

  @override
  ConsumerState<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends ConsumerState<ClientHome> {
  bool _isConnected = false;
  StreamSubscription? _wsSubscription;
  String _deviceIp = '...';
  final _audioPlayer = AudioPlayer();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
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
    final data = jsonDecode(message);
    if (data['type'] == 'OrderCreated') {
      _playSound();
      HapticFeedback.vibrate();
    }
    ref.read(clientStateProvider.notifier).handleEvent(message);
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
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startDiscovery() {
    ref.read(discoveryServiceProvider).discover().listen((service) {
      if (service.addresses != null && service.addresses!.isNotEmpty && !_isConnected) {
        final host = service.addresses!.first.address;
        _connectToHost(host, service.port ?? 8080);
      }
    }, onError: (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discovery error: $e')),
      );
    });
  }

  void _connectToHost(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    String? clientId = prefs.getString('client_uuid');
    if (clientId == null) {
      clientId = Uuid().v4();
      await prefs.setString('client_uuid', clientId);
    }

    ref.read(clientServiceProvider).connect(host, port);
    
    final registration = jsonEncode({
      'type': 'RegisterClient',
      'id': clientId,
      'deviceName': Platform.localHostname,
      'station': ref.read(stationTagProvider) ?? 'GENERAL',
    });
    
    ref.read(clientServiceProvider).send(registration);

    _wsSubscription?.cancel();
    _wsSubscription = ref.read(clientServiceProvider).stream.listen((message) {
      _handleIncomingMessage(message.toString());
    });
    setState(() {
      _isConnected = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(clientStateProvider);
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937)),
                child: const Text('RE-SCAN FOR HOST'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _showManualConnectDialog(),
                child: const Text('MANUAL CONNECT', style: TextStyle(color: Color(0xFF6B7280))),
              ),
            ],
          ),
        ),
      );
    }

    final filteredTickets = tickets.where((order) {
      if (stationTag == 'GENERAL' || stationTag == 'EXPO') return true;
      return order.items.any((item) => item.stationTag.toUpperCase() == stationTag.toUpperCase());
    }).toList();

    final isDark = settings.themeMode == ThemeMode.dark || settings.clientHighContrast;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(settings.clientTextScale),
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: settings.clientHighContrast 
                ? Colors.black 
                : (settings.themeMode == ThemeMode.light ? Colors.white : const Color(0xFF030712)),
            body: Column(
              children: [
                _buildHeader(stationTag, timeFormat, settings),
                Expanded(
                  child: filteredTickets.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                          itemCount: filteredTickets.length,
                          itemBuilder: (context, index) {
                            final ticket = filteredTickets[index];
                            return TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutBack,
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(50 * (1 - value), 0),
                                  child: Opacity(opacity: value, child: child),
                                );
                              },
                              child: _TicketCard(
                                key: ValueKey(ticket.uuid),
                                order: ticket,
                                stationFilter: stationTag,
                                onFinished: () => _confettiController.play(),
                                settings: settings,
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
                    colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
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
                    colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
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
    final isDark = settings.themeMode == ThemeMode.dark || settings.clientHighContrast;
    final bgColor = settings.clientHighContrast 
        ? Colors.black 
        : (settings.themeMode == ThemeMode.light ? Colors.grey.shade200 : const Color(0xFF1F2937));
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      height: 60,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: settings.clientHighContrast 
        ? const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 2))) 
        : (settings.themeMode == ThemeMode.light ? BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))) : null),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showStationSelectionDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    station.toUpperCase(),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'KDS ACTIVE • $_deviceIp',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (context, snapshot) {
                  return Text(
                    DateFormat(timeFormat).format(DateTime.now()),
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'monospace',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
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

  void _showClientSettings() {
    showDialog(
      context: context,
      builder: (context) => Consumer(builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider);
        final notifier = ref.read(settingsProvider.notifier);
        return AlertDialog(
          backgroundColor: settings.themeMode == ThemeMode.light && !settings.clientHighContrast ? Colors.white : const Color(0xFF1F2937),
          title: Text('KDS SETTINGS', 
            style: TextStyle(
              color: settings.themeMode == ThemeMode.light && !settings.clientHighContrast ? Colors.black : Colors.white, 
              fontWeight: FontWeight.bold
            )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('APPEARANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                subtitle: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {settings.themeMode == ThemeMode.system ? ThemeMode.dark : settings.themeMode},
                  onSelectionChanged: (val) => notifier.setThemeMode(val.first),
                ),
              ),
              const Divider(),
              const Text('TEXT SIZE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              Slider(
                value: settings.clientTextScale,
                min: 0.8,
                max: 2.0,
                divisions: 6,
                activeColor: const Color(0xFF22C55E),
                onChanged: (val) => notifier.setClientTextScale(val),
              ),
              const Text('ALERT VOLUME', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              Slider(
                value: settings.clientVolume,
                min: 0.0,
                max: 1.0,
                activeColor: const Color(0xFF22C55E),
                onChanged: (val) => notifier.setClientVolume(val),
              ),
              SwitchListTile(
                title: Text('HIGH CONTRAST', 
                  style: TextStyle(
                    color: settings.themeMode == ThemeMode.light && !settings.clientHighContrast ? Colors.black : Colors.white, 
                    fontWeight: FontWeight.bold
                  )),
                value: settings.clientHighContrast,
                activeColor: const Color(0xFF22C55E),
                onChanged: (val) => notifier.setClientHighContrast(val),
              ),
              const Divider(),
              ListTile(
                title: const Text('EXIT KITCHEN MODE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  ref.read(deviceRoleProvider.notifier).state = DeviceRole.unset;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
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
    final controller = TextEditingController(text: ref.read(stationTagProvider));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('SET STATION NAME', style: TextStyle(color: Colors.white)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              ref.read(stationTagProvider.notifier).state = controller.text.trim().toUpperCase();
              Navigator.pop(context);
            },
            child: const Text('SAVE', style: TextStyle(color: Color(0xFF22C55E))),
          ),
        ],
      ),
    );
  }

  void _showManualConnectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('MANUAL CONNECT', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'HOST IP ADDRESS',
            hintStyle: TextStyle(color: Colors.grey),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              _connectToHost(controller.text, 8080);
              Navigator.pop(context);
            },
            child: const Text('CONNECT', style: TextStyle(color: Color(0xFF22C55E))),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  final ClientOrder order;
  final String stationFilter;
  final VoidCallback? onFinished;
  final AppSettings settings;
  
  const _TicketCard({
    super.key, 
    required this.order, 
    required this.stationFilter, 
    this.onFinished,
    required this.settings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsedMinutes = DateTime.now().difference(order.timestamp).inMinutes;
    final isDark = settings.themeMode == ThemeMode.dark || settings.clientHighContrast;

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

    return Material(
      color: settings.clientHighContrast
          ? Colors.black
          : (settings.themeMode == ThemeMode.light ? Colors.white : const Color(0xFF1F2937)),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 340,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: settings.clientHighContrast ? (elapsedMinutes >= 10 ? const Color(0xFFDC2626) : Colors.white) : agingColor,
            width: settings.clientHighContrast ? 4 : 3,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: agingColor.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${order.uuid.substring(0, 4).toUpperCase()}',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${elapsedMinutes.clamp(0, 999)}m',
                      style: TextStyle(
                        color: agingColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Text(
                  order.customerName.toUpperCase(),
                  style: TextStyle(color: isDark ? const Color(0xFF6B7280) : Colors.grey.shade700, fontWeight: FontWeight.bold),
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
                    ref.read(clientStateProvider.notifier).toggleItemBump(order.uuid, item.uuid);
                  },
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: item.isBumped ? 0.3 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.grey.shade200, width: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (item.isBumped)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 24),
                                ),
                              Expanded(
                                child: Text(
                                  item.name.toUpperCase(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    decoration: item.isBumped ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (item.modifiers.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8.0),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFACC15),
                                borderRadius: BorderRadius.circular(4),
                                border: settings.clientHighContrast ? Border.all(color: Colors.black, width: 2) : null,
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
          _buildFooter(ref, displayItems, isDark),
        ],
      ),
    ),);
  }

  Widget _buildFooter(WidgetRef ref, List<ClientItem> items, bool isDark) {
    final allBumped = items.every((i) => i.isBumped);

    return InkWell(
      onTap: () {
        HapticFeedback.heavyImpact();
        if (allBumped) {
          onFinished?.call();
          ref.read(clientStateProvider.notifier).removeOrder(order.uuid);
        } else {
          for (var item in items) {
            if (!item.isBumped) {
              ref.read(clientStateProvider.notifier).toggleItemBump(order.uuid, item.uuid);
            }
          }
        }
      },
      child: Container(
        height: 70,
        color: allBumped ? const Color(0xFF22C55E) : (isDark ? const Color(0xFF374151) : Colors.grey.shade300),
        alignment: Alignment.center,
        child: Text(
          allBumped ? 'FINISH TICKET' : 'BUMP ALL',
          style: TextStyle(
            color: allBumped ? Colors.black : (isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
