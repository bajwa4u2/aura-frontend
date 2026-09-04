// THE ONE COMMAND THAT PACKAGES AURA FOR WINDOWS.
//
//     dart run tool/windows/package_windows.dart
//
// ── WHY THIS EXISTS ──────────────────────────────────────────────────────
//
// Packaging Aura correctly is three steps, because the `msix` package cannot
// declare a share target and the declaration has to be injected between its
// build and its pack. Three steps is a defect waiting to happen: the obvious
// command is `dart run msix:create`, it regenerates the manifest, it drops the
// share target, and it SUCCEEDS — producing a package that installs, runs, and
// is silently not a share target. Nothing fails, so nobody finds out until a
// person goes looking for Aura in the Windows share sheet and it is not there.
//
// A release step that depends on someone remembering it is not a release step.
// So this is the canonical entry point, and it verifies its own output: the
// finished `.msix` is opened and its manifest read, and the command FAILS if
// the declaration is not in the shipped package. Passing here means the
// artifact is correct, not that the right commands were typed.
//
// `--verify-only <path>` re-runs just that check against any existing package,
// which is what a release gate calls.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

const _shareTargetMarker = 'windows.shareTarget';
const _dataFormats = ['Text', 'WebLink', 'StorageItems'];

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--verify-only') {
    final path = args.length > 1 ? args[1] : _defaultPackagePath();
    final problems = verifyPackage(File(path));
    if (problems.isEmpty) {
      stdout.writeln('OK  $path carries the share target declaration.');
      return;
    }
    _fail(path, problems);
  }

  await _run('dart', ['run', 'msix:build'], 'building the unpackaged files');
  await _run(
    'dart',
    ['run', 'tool/windows/declare_share_target.dart'],
    'declaring the share target',
  );
  await _run('dart', ['run', 'msix:pack'], 'packing');

  final path = _defaultPackagePath();
  final package = File(path);
  if (!package.existsSync()) {
    stderr.writeln('Packing reported success but produced no file at $path.');
    exit(1);
  }

  // THE POINT OF THE WHOLE FILE. Not "did the steps run" — did the artifact
  // come out right.
  final problems = verifyPackage(package);
  if (problems.isNotEmpty) _fail(path, problems);

  final size = (package.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
  stdout.writeln('');
  stdout.writeln('Packaged and verified: $path ($size MB)');
  stdout.writeln('  share target declared, with ${_dataFormats.join(", ")}');
}

/// Read the manifest out of a built `.msix` and say what is wrong with it.
///
/// Returns an empty list when the package is correct. Deliberately reports
/// EVERY problem rather than the first: a release check that makes someone
/// re-run a five-minute package build to discover the second fault is a check
/// people learn to skip.
List<String> verifyPackage(File package) {
  if (!package.existsSync()) {
    return ['${package.path} does not exist.'];
  }

  final String manifest;
  try {
    manifest = _readManifest(package);
  } on FormatException catch (error) {
    return ['${package.path}: ${error.message}'];
  }

  final problems = <String>[];

  if (!manifest.contains(_shareTargetMarker)) {
    problems.add(
      'No windows.shareTarget extension. This package installs and runs and '
      'is not a share target — which is exactly the failure that produces no '
      'error. Package with this tool, not with `dart run msix:create`.',
    );
    // Everything below is about the CONTENT of a declaration that is not
    // there, so saying it too would be noise.
    return problems;
  }

  for (final format in _dataFormats) {
    if (!manifest.contains('<uap:DataFormat>$format</uap:DataFormat>')) {
      problems.add('The share target does not accept $format.');
    }
  }

  final fileTypes = RegExp(r'<uap:FileType>(\.[a-z0-9]+)</uap:FileType>')
      .allMatches(manifest)
      .length;
  if (fileTypes == 0) {
    problems.add(
      'The share target declares no file types, so Aura would appear in the '
      'share sheet and then decline everything.',
    );
  }

  // The declaration must not have displaced what was already there. Both of
  // these are load-bearing continuation mechanisms.
  if (!manifest.contains('windows.protocol')) {
    problems.add('The aura:// protocol declaration is missing.');
  }
  if (!manifest.contains('windows.appUriHandler')) {
    problems.add('The App URI Handler declaration is missing.');
  }

  return problems;
}

/// `AppxManifest.xml` from inside the package.
///
/// AN MSIX IS A ZIP, AND READING IT PROPERLY MATTERS. This was first written
/// as a hand-rolled central-directory walk, to avoid a dependency in the
/// release path. It failed on the very first real package: at 32 MB the
/// archive uses Zip64, where an entry's offset field is a `0xFFFFFFFF`
/// sentinel that points into an extra field, and the naive read walked off the
/// end of the buffer. A release gate that mis-parses the artifact it exists to
/// guard is worse than no gate, so this reads the archive with a reader that
/// knows the format.
String _readManifest(File package) {
  final archive = ZipDecoder().decodeBytes(package.readAsBytesSync());
  for (final file in archive.files) {
    if (!file.isFile) continue;
    if (file.name != 'AppxManifest.xml') continue;
    return utf8.decode(file.content as List<int>, allowMalformed: true);
  }
  throw const FormatException('No AppxManifest.xml inside the package.');
}

String _defaultPackagePath() =>
    'build/windows/x64/runner/Release/aura.msix';

Never _fail(String path, List<String> problems) {
  stderr.writeln('');
  stderr.writeln('WINDOWS PACKAGE REJECTED: $path');
  for (final problem in problems) {
    stderr.writeln('  - $problem');
  }
  exit(1);
}

Future<void> _run(String executable, List<String> args, String what) async {
  stdout.writeln('→ $what');
  final process = await Process.start(
    executable,
    args,
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  final code = await process.exitCode;
  if (code != 0) {
    stderr.writeln('Failed while $what (exit $code).');
    exit(code);
  }
}
