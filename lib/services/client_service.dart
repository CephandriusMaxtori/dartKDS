import 'package:web_socket_channel/web_socket_channel.dart';

class ClientService {
  WebSocketChannel? _channel;

  void connect(String host, int port) {
    _channel = WebSocketChannel.connect(Uri.parse('ws://$host:$port/ws'));
  }

  Stream get stream => _channel?.stream ?? const Stream.empty();

  void send(dynamic message) {
    _channel?.sink.add(message);
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
