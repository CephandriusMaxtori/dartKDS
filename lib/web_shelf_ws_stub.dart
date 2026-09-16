// Stub for shelf_web_socket on web — WebSocket upgrade via shelf uses dart:io.
import 'package:shelf/shelf.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Handler webSocketHandler(
  void Function(WebSocketChannel channel) onConnection, {
  Response? onError,
}) {
  throw UnsupportedError('WebSocket handler is not available on web');
}