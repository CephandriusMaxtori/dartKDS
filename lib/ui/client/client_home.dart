import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    // 1. Lock to Landscape and Enter Immersive Full-Screen
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
    // Revert orientations and UI mode when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _startDiscovery() {
    print('DEBUG: Starting discovery stream');
    ref.read(discoveryServiceProvider).discover().listen((service) {
      print('DEBUG: Discovered service: ${service.name} at ${service.addresses}');
      if (service.addresses != null && service.addresses!.isNotEmpty && !_isConnected) {
        final host = service.addresses!.first.address;
        _connectToHost(host, service.port ?? 8080);
      }
    }, onError: (e) {
      print('DEBUG: Discovery error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discovery error: $e')),
      );
    });
  }

  void _connectToHost(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    String? clientId = prefs.getString('client_uuid');
    if (clientId == null) {
      clientId = const Uuid().v4();
      await prefs.setString('client_uuid', clientId);
    }

    ref.read(clientServiceProvider).connect(host, port);
    
    // Send registration message
    final registration = jsonEncode({
      'type': 'RegisterClient',
      'id': clientId,
      'deviceName': Platform.localHostname,
      'station': ref.read(stationTagProvider) ?? 'GENERAL',
    });
    
    ref.read(clientServiceProvider).send(registration);

    _wsSubscription?.cancel();
    _wsSubscription = ref.read(clientServiceProvider).stream.listen((message) {
      try {
        final data = jsonDecode(message.toString());
        if (data['type'] == 'SetStation') {
          ref.read(stationTagProvider.notifier).state = data['station'];
          // Notify host back that we changed
          ref.read(clientServiceProvider).send(jsonEncode({
            'type': 'StationChanged',
            'station': data['station'],
          }));
        } else {
          ref.read(clientStateProvider.notifier).handleEvent(message.toString());
        }
      } catch (e) {
        print('Error parsing client event: $e');
      }
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
              FutureBuilder<List<NetworkInterface>>(
                future: NetworkInterface.list(),
                builder: (context, snapshot) {
                  final hasBluetooth = snapshot.data?.any((i) => i.name.contains('bt') || i.name.contains('pan')) ?? false;
                  if (!hasBluetooth) return const SizedBox.shrink();
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Bluetooth PAN detected.\nIf Host is not found, try Manual Connect.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                    ),
                  );
                },
              ),
              TextButton(
                onPressed: () => _showManualConnectDialog(),
                child: const Text('MANUAL CONNECT', style: TextStyle(color: Color(0xFF6B7280))),
              ),
            ],
          ),
        ),
      );
    }

    // Filter tickets based on stationTag
    final filteredTickets = tickets.where((order) {
      if (stationTag == 'GENERAL' || stationTag == 'EXPO') return true;
      return order.items.any((item) => item.stationTag.toUpperCase() == stationTag.toUpperCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Column(
        children: [
          // 4.1 Global Header
          _buildHeader(stationTag, timeFormat),
          // 4.2 Ticket Queue
          Expanded(
            child: filteredTickets.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    itemCount: filteredTickets.length,
                    itemBuilder: (context, index) => _TicketCard(
                      order: filteredTickets[index],
                      stationFilter: stationTag,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showStationSelectionDialog() {
    // Note: Since clients are offline and Host holds the stations,
    // we can either hardcode common ones or allow manual entry on the client.
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

  Widget _buildHeader(String station, String timeFormat) {
    return Container(
      height: 60,
      color: const Color(0xFF1F2937),
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, snapshot) {
              return Text(
                DateFormat(timeFormat).format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 120, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'QUEUE EMPTY',
            style: TextStyle(
              color: Colors.white.withOpacity(0.1),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
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
  const _TicketCard({required this.order, required this.stationFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = DateTime.now().difference(order.timestamp).inMinutes > 15;
    
    // Filter items for this ticket based on station
    final displayItems = order.items.where((item) {
      if (stationFilter == 'GENERAL' || stationFilter == 'EXPO') return true;
      return item.stationTag.toUpperCase() == stationFilter.toUpperCase();
    }).toList();

    if (displayItems.isEmpty) return const SizedBox.shrink();

    return Container(
      width: 340,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF374151),
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ticket Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOverdue ? const Color(0xFFDC2626).withOpacity(0.1) : Colors.transparent,
              border: const Border(bottom: BorderSide(color: Color(0xFF374151))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${order.uuid.substring(0, 4).toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${DateTime.now().difference(order.timestamp).inMinutes}m',
                      style: TextStyle(
                        color: isOverdue ? const Color(0xFFDC2626) : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Text(
                  order.customerName.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Item List
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
                    opacity: item.isBumped ? 0.4 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF374151), width: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (item.isBumped)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20),
                                ),
                              Expanded(
                                child: Text(
                                  item.name.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    decoration: item.isBumped ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (item.modifiers.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                item.modifiers.join(', ').toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFFACC15),
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
          // Ticket Footer
          _buildFooter(ref, displayItems),
        ],
      ),
    );
  }

  Widget _buildFooter(WidgetRef ref, List<ClientItem> items) {
    final allBumped = items.every((i) => i.isBumped);

    return InkWell(
      onTap: () {
        HapticFeedback.heavyImpact();
        if (stationFilter == 'EXPO') {
           ref.read(clientStateProvider.notifier).removeOrder(order.uuid);
        } else {
           // For prep stations, maybe just mark all items in THIS station as bumped
           for(var item in items) {
              if(!item.isBumped) {
                 ref.read(clientStateProvider.notifier).toggleItemBump(order.uuid, item.uuid);
              }
           }
        }
      },
      child: Container(
        height: 60,
        color: allBumped ? const Color(0xFF22C55E) : const Color(0xFF374151),
        alignment: Alignment.center,
        child: Text(
          stationFilter == 'EXPO' 
            ? (allBumped ? 'FINISH TICKET' : 'BUMP ALL')
            : (allBumped ? 'STATION DONE' : 'BUMP ALL'),
          style: TextStyle(
            color: allBumped ? Colors.black : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
