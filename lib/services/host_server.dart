import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/connected_client.dart';

class HostServer {
  final Map<String, WebSocketChannel> _clientChannels = {};
  final List<ConnectedClient> _clients = [];
  HttpServer? _server;

  // Callback to notify UI of client changes
  Function? onClientsChanged;

  List<ConnectedClient> get connectedClients => List.unmodifiable(_clients);

  Future<void> start({int port = 8080}) async {
    final router = Router();

    // Serve the Web KDS Client
    router.get('/', (Request request) async {
      final html = await rootBundle.loadString('assets/index.html');
      return Response.ok(html, headers: {'Content-Type': 'text/html'});
    });

    router.get('/ws', webSocketHandler((WebSocketChannel webSocket) {
      String? clientId;

      webSocket.stream.listen((message) {
        try {
          final data = jsonDecode(message.toString());
          if (data['type'] == 'RegisterClient') {
            clientId = data['id'];
            _clientChannels[clientId!] = webSocket;
            
            // Update or add to list
            _clients.removeWhere((c) => c.id == clientId);
            _clients.add(ConnectedClient(
              id: clientId!,
              deviceName: data['deviceName'] ?? 'Unknown Device',
              currentStation: data['station'] ?? 'GENERAL',
              connectedAt: DateTime.now(),
            ));
            
            onClientsChanged?.call();
            print('Client registered: $clientId');
          } else if (data['type'] == 'StationChanged') {
             final idx = _clients.indexWhere((c) => c.id == clientId);
             if (idx != -1) {
                _clients[idx].currentStation = data['station'];
                onClientsChanged?.call();
             }
          }
          
          // Re-broadcast general events
          if (data['type'] != 'RegisterClient') {
            broadcast(message);
          }
        } catch (e) {
          print('Error handling WS message: $e');
        }
      }, onDone: () {
        if (clientId != null) {
          _clientChannels.remove(clientId);
          _clients.removeWhere((c) => c.id == clientId);
          onClientsChanged?.call();
        }
      });
    }));

    router.post('/order', (Request request) async {
      final payload = await request.readAsString();
      broadcast(payload);
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _server = await io.serve(router, InternetAddress.anyIPv4, port);
    print('Server listening on port ${_server?.port}');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    for (var client in _clientChannels.values) {
      client.sink.close();
    }
    _clientChannels.clear();
    _clients.clear();
  }

  void broadcast(dynamic message) {
    for (final client in _clientChannels.values) {
      client.sink.add(message);
    }
  }

  void sendToClient(String clientId, Map<String, dynamic> message) {
    final channel = _clientChannels[clientId];
    if (channel != null) {
      channel.sink.add(jsonEncode(message));
    }
  }
}
