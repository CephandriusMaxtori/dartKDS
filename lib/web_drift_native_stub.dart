// Stub for drift/native.dart on web — NativeDatabase requires dart:io.
import 'package:drift/drift.dart' show QueryExecutor;

class NativeDatabase implements QueryExecutor {
  NativeDatabase(dynamic file, {dynamic setup});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('NativeDatabase is not available on web');
  }
}