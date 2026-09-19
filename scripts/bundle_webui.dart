// Packs the compiled Flutter web build (build/web) into a single
// assets/webui.bin file. A single flat file is used instead of copying the
// tree into assets/webui/ because Flutter's asset bundler only includes the
// top-level files of a directory asset entry — subdirectories (canvaskit/,
// assets/, icons/) would be silently dropped, breaking the served web app.
//
// Format (big-endian): u32 entryCount, then per entry:
//   u16 nameLen, UTF-8 relative path, u32 dataLen, raw bytes.
//
// Usage:
//   flutter build web --no-web-resources-cdn
//   dart run scripts/bundle_webui.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<void> main() async {
  final src = Directory(
    '${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}web',
  );
  final out = File(
    '${Directory.current.path}${Platform.pathSeparator}assets${Platform.pathSeparator}webui.bin',
  );

  if (!src.existsSync()) {
    stderr.writeln('ERROR: Web build not found at ${src.path}');
    stderr.writeln('Run "flutter build web --no-web-resources-cdn" first.');
    exitCode = 1;
    return;
  }

  final files = <File>[];
  await for (final entity in src.list(recursive: true)) {
    if (entity is File) {
      final rel = entity.path
          .substring(src.path.length + 1)
          .replaceAll(Platform.pathSeparator, '/');
      // The web build copies the pubspec `assets/webui.bin` (the previously
      // bundled UI) into build/web. Skip it, otherwise the bundle would embed
      // itself and double in size on every build.
      if (rel == 'assets/assets/webui.bin') continue;
      files.add(entity);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  final data = BytesBuilder();
  final count = files.length;
  data.add(_u32(count));
  var bytes = 0;
  for (final file in files) {
    final rel = file.path
        .substring(src.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    final name = utf8.encode(rel);
    final content = await file.readAsBytes();
    data.add(_u16(name.length));
    data.add(name);
    data.add(_u32(content.length));
    data.add(content);
    bytes += content.length;
  }

  await out.writeAsBytes(data.toBytes());
  stdout.writeln(
    'Bundled $count files (${(bytes / 1024 / 1024).toStringAsFixed(1)} MB) to ${out.path}',
  );
}

Uint8List _u32(int value) => Uint8List(4)
  ..buffer.asByteData().setUint32(0, value);

Uint8List _u16(int value) => Uint8List(2)
  ..buffer.asByteData().setUint16(0, value);