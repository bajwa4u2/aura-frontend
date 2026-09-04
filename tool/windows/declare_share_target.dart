// DECLARE AURA AS A WINDOWS SHARE TARGET.
//
// Run BETWEEN `dart run msix:build` and `dart run msix:pack`:
//
//     dart run msix:build
//     dart run tool/windows/declare_share_target.dart
//     dart run msix:pack
//
// ── WHY THIS EXISTS AS A STEP RATHER THAN A CONFIG LINE ──────────────────
//
// The `msix` package builds its AppxManifest from a fixed template. It can
// declare a protocol, a file association, an execution alias, App URI
// handlers, a startup task and a toast activator — and it has no key for a
// share target and no escape hatch for arbitrary extensions. There is nothing
// to set in `msix_config`.
//
// So this uses the seam the package already supports: `msix:build` writes the
// manifest and staging files, `msix:pack` packs WHATEVER MANIFEST IS THERE.
// Two documented commands with a gap between them is a supported flow, not a
// hack — and unlike patching the finished `.msix`, nothing has to be unpacked
// or re-signed.
//
// ── AND WHY THE FILE TYPES ARE READ RATHER THAN LISTED ───────────────────
//
// Windows matches a share target on FILE EXTENSION, where Android matches on
// MIME. A hand-written list here would be a fourth place the set of things
// Aura accepts is written down, and the first one to go stale. This reads the
// extensions straight out of `inferMimeFromFileName` in `media_mime.dart`, so
// the manifest cannot promise something intake would refuse.

import 'dart:io';

const _mimeAuthority = 'lib/core/media/media_mime.dart';
const _marker = 'windows.shareTarget';

void main(List<String> args) {
  final manifest = _locateManifest(args);
  if (manifest == null) {
    stderr.writeln(
      'No generated AppxManifest.xml found. Run `dart run msix:build` first.',
    );
    exit(1);
  }

  final extensions = _acceptedFileExtensions();
  if (extensions.isEmpty) {
    stderr.writeln(
      'Could not read any file extensions from $_mimeAuthority. Refusing to '
      'declare a share target that promises nothing.',
    );
    exit(1);
  }

  final original = manifest.readAsStringSync();

  if (original.contains(_marker)) {
    stdout.writeln('Share target already declared in ${manifest.path}.');
    return;
  }

  final updated = _inject(original, extensions);
  if (updated == null) {
    stderr.writeln(
      'AppxManifest.xml has no <Extensions> element and no </Application> to '
      'add one before. The manifest template has changed; this tool has not.',
    );
    exit(1);
  }

  manifest.writeAsStringSync(updated);
  stdout.writeln(
    'Declared Aura as a Windows share target for ${extensions.length} file '
    'types, plus Text, WebLink and StorageItems.',
  );
  stdout.writeln('  ${manifest.path}');
}

/// The manifest `msix:build` produced.
File? _locateManifest(List<String> args) {
  if (args.isNotEmpty) {
    final explicit = File(args.first);
    return explicit.existsSync() ? explicit : null;
  }
  for (final flavour in const ['Release', 'Debug']) {
    final candidate =
        File('build/windows/x64/runner/$flavour/AppxManifest.xml');
    if (candidate.existsSync()) return candidate;
  }
  return null;
}

/// Every extension `inferMimeFromFileName` recognises, read from its source.
///
/// Parsing the authority rather than importing it is deliberate: this runs as
/// a standalone script during packaging, where the app's own dependency graph
/// is not loaded, and the answer needed is the SET of cases — which the
/// function itself has no way to return.
Set<String> _acceptedFileExtensions() {
  final source = File(_mimeAuthority);
  if (!source.existsSync()) return const {};
  final text = source.readAsStringSync();

  final start = text.indexOf('String? inferMimeFromFileName(');
  if (start < 0) return const {};
  final end = text.indexOf('\n}', start);
  if (end < 0) return const {};

  final body = text.substring(start, end);
  return RegExp(r"case '([a-z0-9]+)':")
      .allMatches(body)
      .map((m) => '.${m.group(1)}')
      .toSet();
}

String? _inject(String manifest, Set<String> extensions) {
  final ordered = extensions.toList()..sort();
  final block = StringBuffer()
    ..writeln('        <uap:Extension Category="windows.shareTarget">')
    ..writeln('          <uap:ShareTarget>')
    ..writeln('            <uap:SupportedFileTypes>');
  for (final extension in ordered) {
    block.writeln('              <uap:FileType>$extension</uap:FileType>');
  }
  block
    ..writeln('            </uap:SupportedFileTypes>')
    // Text and WebLink are how a sentence and a link arrive. StorageItems is
    // how files do.
    ..writeln('            <uap:DataFormat>Text</uap:DataFormat>')
    ..writeln('            <uap:DataFormat>WebLink</uap:DataFormat>')
    ..writeln('            <uap:DataFormat>StorageItems</uap:DataFormat>')
    ..writeln('          </uap:ShareTarget>')
    ..write('        </uap:Extension>');

  const extensionsClose = '</Extensions>';
  if (manifest.contains(extensionsClose)) {
    return manifest.replaceFirst(
      extensionsClose,
      '${block.toString()}\n        $extensionsClose',
    );
  }

  const applicationClose = '</Application>';
  if (manifest.contains(applicationClose)) {
    return manifest.replaceFirst(
      applicationClose,
      '<Extensions>\n$block\n        </Extensions>\n      $applicationClose',
    );
  }

  return null;
}
