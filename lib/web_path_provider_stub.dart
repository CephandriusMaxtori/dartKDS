// Stub for path_provider on web — no filesystem access in browsers.
import 'web_io_stub.dart';

Future<Directory> getApplicationDocumentsDirectory() async =>
    throw UnsupportedError('path_provider is not available on web');

Future<Directory> getTemporaryDirectory() async =>
    throw UnsupportedError('path_provider is not available on web');
