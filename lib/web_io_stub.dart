// Comprehensive dart:io stubs for web compilation.
// On web, dart:io is unavailable. These stubs provide the minimal API surface
// so that native-only code compiles but never runs (host mode is blocked on web).

import 'dart:async';

class InternetAddressType {
  static const InternetAddressType IPv4 = InternetAddressType._('IPv4');
  final String _name;
  const InternetAddressType._(this._name);
  @override
  String toString() => 'InternetAddressType.$_name';
}

class InternetAddress {
  static final InternetAddress anyIPv4 = InternetAddress('0.0.0.0');
  final String address;
  final InternetAddressType type = InternetAddressType.IPv4;
  bool get isLoopback => address == '127.0.0.1' || address == '::1';
  InternetAddress(this.address);
}

class NetworkInterface {
  final String name;
  final List<InternetAddress> addresses;
  const NetworkInterface._({required this.name, required this.addresses});
  static Future<List<NetworkInterface>> list({
    bool includeLoopback = false,
    InternetAddressType? type,
  }) async =>
      [];
}

class File {
  final String path;
  File(this.path);
  Future<String> readAsString() async => '';
  Future<List<int>> readAsBytes() async => [];
  Future<void> writeAsString(String contents) async {}
  List<int> readAsBytesSync() => [];
  bool existsSync() => false;
}

class Directory {
  final String path;
  const Directory(this.path);
  static Directory current = Directory('.');
  bool existsSync() => false;
}

class Platform {
  static String get resolvedExecutable => '';
  static String get pathSeparator => '/';
  static String get localHostname => 'Web Browser';
}

class HttpHeaders {
  ContentType contentType = ContentType.json;
}

class HttpClient {
  Future<HttpClientRequest> getUrl(Uri url) async => HttpClientRequest();
  Future<HttpClientRequest> postUrl(Uri url) async => HttpClientRequest();
  void close({bool force = false}) {}
}

class HttpClientRequest {
  final HttpHeaders headers = HttpHeaders();
  void write(Object? data) {}
  Future<HttpClientResponse> close() async => HttpClientResponse();
  Future<HttpClientResponse> timeout(Duration timeout) async =>
      HttpClientResponse();
}

class HttpClientResponse extends StreamView<List<int>> {
  HttpClientResponse() : super(const Stream.empty());
  int get statusCode => 200;
}

class ContentType {
  static final ContentType json = ContentType._();
  ContentType._();
}

class HttpServer {
  Future<void> close({bool force = false}) async {}
}

class Datagram {
  final List<int> data;
  final InternetAddress address;
  Datagram(this.data, this.address);
}

class RawDatagramSocket {
  bool broadcastEnabled = false;
  static Future<RawDatagramSocket> bind(
    InternetAddress? address,
    int port, {
    bool? reuseAddress,
  }) async =>
      RawDatagramSocket();
  RawDatagramSocket();
  void send(List<int> data, InternetAddress address, int port) {}
  Datagram? receive() => null;
  void close() {}
  void listen(void Function(RawSocketEvent event)? onData) {}
}

enum RawSocketEvent { read, write, close }