import 'package:web_socket_channel/web_socket_channel.dart';

class ClientService {
  WebSocketChannel? _channel;

  Future<void> connect(String host, int port) async {
    final channel = WebSocketChannel.connect(Uri.parse('ws://$host:$port/ws'));
    _channel = channel;
    // Completes once the socket is open, errors if the host is unreachable.
    await channel.ready;
  }

  Stream get stream => _channel?.stream ?? const Stream.empty();

  void send(dynamic message) {
    try {
      _channel?.sink.add(message);
    } catch (_) {
      // Socket may already be closed; ignore.
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}