// Stub for drift/isolate.dart on web — background isolates differ in browsers.
import 'dart:async';
import 'package:drift/drift.dart' show DatabaseConnection;

class DriftIsolate {
  static Future<DriftIsolate> inCurrent(
    FutureOr<DatabaseConnection> Function() connect,
  ) async {
    throw UnsupportedError('DriftIsolate is not available on web');
  }

  Future<DatabaseConnection> connect() async {
    throw UnsupportedError('DriftIsolate is not available on web');
  }
}