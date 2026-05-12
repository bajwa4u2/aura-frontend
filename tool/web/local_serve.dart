// Tiny local HTTP server that mimics the production nginx behavior:
//   - Serves files under build/web verbatim.
//   - For an URL like "/investors", first tries build/web/investors,
//     then build/web/investors/index.html, then falls back to
//     build/web/index.html — i.e. `try_files $uri $uri/ /index.html`.
//
// Used to validate route-aware OG metadata locally without deploying.
// Run from aura_final/:
//   dart run tool/web/local_serve.dart [port]

import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 8080;
  const root = 'build/web';

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('local_serve: listening on http://127.0.0.1:$port (root=$root)');

  await for (final request in server) {
    try {
      var pathSeg = Uri.decodeComponent(request.uri.path);
      if (pathSeg.contains('..')) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        continue;
      }
      // Strip leading slash for filesystem join.
      final rel = pathSeg.startsWith('/') ? pathSeg.substring(1) : pathSeg;
      File? hit;

      // try_files $uri
      if (rel.isNotEmpty) {
        final direct = File('$root/$rel');
        if (await direct.exists()) hit = direct;
      }
      // try_files $uri/
      if (hit == null) {
        final dirIndex = File('$root/${rel.isEmpty ? '' : '$rel/'}index.html');
        if (await dirIndex.exists()) hit = dirIndex;
      }
      // fallback /index.html
      hit ??= File('$root/index.html');

      final mime = _mime(hit.path);
      request.response.headers.set(HttpHeaders.contentTypeHeader, mime);
      request.response.headers.set('X-Aura-Served-Path', hit.path);
      await request.response.addStream(hit.openRead());
      await request.response.close();
    } catch (e) {
      stderr.writeln('local_serve: error $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }
}

String _mime(String path) {
  if (path.endsWith('.html')) return 'text/html; charset=utf-8';
  if (path.endsWith('.js')) return 'application/javascript';
  if (path.endsWith('.css')) return 'text/css';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.json')) return 'application/json';
  if (path.endsWith('.ico')) return 'image/x-icon';
  if (path.endsWith('.wasm')) return 'application/wasm';
  if (path.endsWith('.woff2')) return 'font/woff2';
  return 'application/octet-stream';
}
