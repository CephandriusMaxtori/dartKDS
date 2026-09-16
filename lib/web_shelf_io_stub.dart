// Stub for shelf_io.dart on web — the real package uses dart:io HttpServer.
import 'web_io_stub.dart';

Future<HttpServer> serve(
  dynamic handler,
  dynamic address,
  int port, {
  String? serverHeader,
}) async {
  throw UnsupportedError('Shelf server is not available on web');
}