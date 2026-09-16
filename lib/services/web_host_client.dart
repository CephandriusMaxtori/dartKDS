import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_state_providers.dart';

enum WebHostStatus { disconnected, connecting, connected, error }

class WebHostClient {
  WebSocketChannel? _channel;
  StreamSubscription? _streamSub;
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<WebHostStatus>.broadcast();
  final _clientId = const Uuid().v4();
  String _hostUrl = '';
  WebHostStatus _status = WebHostStatus.disconnected;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;
  Stream<WebHostStatus> get statusStream => _statusController.stream;

  WebHostStatus get status => _status;

  bool get isConnected => _status == WebHostStatus.connected;

  void _setStatus(WebHostStatus value) {
    _status = value;
    _statusController.add(value);
  }

  Future<void> connect({String? host, int? port, HostRole? role}) async {
    await disconnect();
    _setStatus(WebHostStatus.connecting);

    _hostUrl = host ?? Uri.base.host;
    final portStr = ':${port ?? 8080}';
    final wsUrl = 'ws://$_hostUrl$portStr/ws';

    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;
      await channel.ready;

      _streamSub = channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message.toString());
            if (data['type'] == 'WebHostReady') {
              _setStatus(WebHostStatus.connected);
            }
            _eventsController.add(data);
          } catch (_) {}
        },
        onError: (_) {
          _setStatus(WebHostStatus.error);
        },
        onDone: () {
          _setStatus(WebHostStatus.disconnected);
        },
      );

      // Register as web host
      send({
        'type': 'RegisterWebHost',
        'id': _clientId,
        'deviceName': 'Web Host',
        if (role != null)
          'role': role == HostRole.backup ? 'backup' : 'primary',
      });
    } catch (e) {
      _setStatus(WebHostStatus.error);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _streamSub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _streamSub = null;
    _setStatus(WebHostStatus.disconnected);
  }

  void send(dynamic message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  void requestSnapshot() {
    send({'type': 'RequestSnapshot'});
  }

  void createOrder({
    required String customerName,
    required List<Map<String, dynamic>> items,
  }) {
    send({'type': 'CreateOrder', 'order': {'customerName': customerName, 'items': items}});
  }

  void updateOrder({
    required String uuid,
    required String customerName,
    required List<Map<String, dynamic>> items,
  }) {
    send({'type': 'UpdateOrder', 'order': {'uuid': uuid, 'customerName': customerName, 'items': items}});
  }

  void deleteOrder(String orderUuid) {
    send({'type': 'DeleteOrder', 'orderUuid': orderUuid});
  }

  void recallOrder(String orderUuid) {
    send({'type': 'RecallOrder', 'orderUuid': orderUuid});
  }

  void setStock(int menuId, int quantity) {
    send({'type': 'SetStock', 'id': menuId, 'quantity': quantity});
  }

  void saveMenu(Map<String, dynamic> menu) {
    send({'type': 'SaveMenu', 'menu': menu});
  }

  void deleteMenu(int id) {
    send({'type': 'DeleteMenu', 'id': id});
  }

  void saveStation(Map<String, dynamic> station) {
    send({'type': 'SaveStation', 'station': station});
  }

  void deleteStation(int id) {
    send({'type': 'DeleteStation', 'id': id});
  }

  void saveModifier(Map<String, dynamic> modifier) {
    send({'type': 'SaveModifier', 'modifier': modifier});
  }

  void deleteModifier(int id) {
    send({'type': 'DeleteModifier', 'id': id});
  }

  void broadcastMessage(String message, {String? station}) {
    send({
      'type': 'BroadcastMessage',
      'message': message,
      if (station != null && station.isNotEmpty) 'station': station,
    });
  }

  void setRushMode(bool enabled) {
    send({'type': 'SetRushMode', 'enabled': enabled});
  }

  void dispose() {
    _streamSub?.cancel();
    _channel?.sink.close();
    _eventsController.close();
    _statusController.close();
  }
}
