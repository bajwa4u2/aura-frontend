// DECLARE AURA'S PUSH BACKGROUND TASK.
//
// Run BETWEEN `dart run msix:build` and `dart run msix:pack`, beside
// `declare_share_target.dart` — `package_windows.dart` runs both.
//
// ── WHY THIS IS A STEP AND NOT A CONFIG LINE ─────────────────────────────
//
// Same reason the share target is: the `msix` package builds its AppxManifest
// from a fixed template with keys for a protocol, a file association, an
// execution alias, App URI handlers, a startup task and a toast activator —
// and no key for a COM server, no key for a background task, and no escape
// hatch for arbitrary extensions. The supported seam is that `msix:build`
// writes the manifest and `msix:pack` packs whatever manifest is there.
//
// ── WHAT IT DECLARES, AND WHY BOTH HALVES ARE NEEDED ────────────────────
//
// A raw WNS call push delivered while Aura is CLOSED reaches a packaged
// full-trust Win32 app through one documented mechanism: a background task
// whose entry point is a COM class the package registers. That is two
// declarations, and either alone is silent:
//
//   windows.comServer      tells Windows which executable to start, and with
//                          which argument, to serve the class id that
//                          `call_push.cpp` registers.
//
// That is the ONLY declaration needed. A winmain COM background task is
// registered in code -- `SetTaskEntryPointClsid` in `call_push.cpp` -- so the
// manifest declares the server, not the task. A `windows.backgroundTasks`
// extension beside it is not merely redundant: it is rejected by the manifest
// schema and the package cannot be built at all. See `_inject` below.
//
// The class id below MUST equal `kCallPushTaskClsid` in
// `windows/runner/call_push.cpp`. A mismatch fails the way that is hardest to
// find: registration succeeds, the push arrives, Windows has nothing to
// activate, and nothing anywhere reports an error.

import 'dart:io';

/// Must equal `kCallPushTaskClsid` in windows/runner/call_push.cpp.
const _clsid = '7A6C2C1E-3E5B-4C52-9E1A-2F6B1D5C7A90';
/// The declaration whose presence means this tool has already run.
const _marker = 'windows.comServer';
const _comNamespace = 'http://schemas.microsoft.com/appx/manifest/com/windows10';
const _desktopNamespace =
    'http://schemas.microsoft.com/appx/manifest/desktop/windows10';

void main(List<String> args) {
  final manifest = _locateManifest(args);
  if (manifest == null) {
    stderr.writeln(
      'No generated AppxManifest.xml found. Run `dart run msix:build` first.',
    );
    exit(1);
  }

  final original = manifest.readAsStringSync();

  if (original.contains(_marker)) {
    stdout.writeln('Push background task already declared in ${manifest.path}.');
    return;
  }

  // READ THE EXECUTABLE, DO NOT ASSUME IT. The COM server must name the same
  // binary the package launches; hard-coding `aura.exe` here would be a second
  // place the name is written down and the first to go stale after a rename.
  final executable = _applicationExecutable(original);
  if (executable == null) {
    stderr.writeln(
      'Could not read Application@Executable from the manifest. The template '
      'has changed; this tool has not.',
    );
    exit(1);
  }

  var updated = _withNamespaces(original);
  final injected = _inject(updated, executable);
  if (injected == null) {
    stderr.writeln(
      'AppxManifest.xml has no <Extensions> element and no </Application> to '
      'add one before. The manifest template has changed; this tool has not.',
    );
    exit(1);
  }

  manifest.writeAsStringSync(injected);
  stdout.writeln(
    'Declared the push background task (COM server $executable, class '
    '$_clsid).',
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

String? _applicationExecutable(String manifest) {
  final match =
      RegExp(r'<Application[^>]*\sExecutable="([^"]+)"').firstMatch(manifest);
  return match?.group(1);
}

/// Both extensions live in namespaces the template may not have declared.
///
/// An undeclared prefix is not a warning — the package fails to validate — so
/// the declarations are added to `<Package>` and to `IgnorableNamespaces`
/// when they are absent, and left exactly as they are when they are present.
String _withNamespaces(String manifest) {
  var updated = manifest;

  for (final entry in const <String, String>{
    'com': _comNamespace,
    'desktop': _desktopNamespace,
  }.entries) {
    final declaration = 'xmlns:${entry.key}="${entry.value}"';
    if (!updated.contains(declaration)) {
      updated = updated.replaceFirst('<Package', '<Package $declaration');
    }
  }

  final ignorable =
      RegExp(r'IgnorableNamespaces="([^"]*)"').firstMatch(updated);
  if (ignorable != null) {
    final existing = ignorable.group(1)!.split(RegExp(r'\s+'))
      ..removeWhere((value) => value.isEmpty);
    for (final prefix in const ['com', 'desktop']) {
      if (!existing.contains(prefix)) existing.add(prefix);
    }
    updated = updated.replaceFirst(
      ignorable.group(0)!,
      'IgnorableNamespaces="${existing.join(' ')}"',
    );
  }

  return updated;
}

String? _inject(String manifest, String executable) {
  final block = StringBuffer()
    ..writeln('        <com:Extension Category="windows.comServer">')
    ..writeln('          <com:ComServer>')
    ..writeln(
      '            <com:ExeServer Executable="$executable" '
      'Arguments="-RegisterProcessAsComServer" '
      'DisplayName="Aura call delivery">',
    )
    ..writeln(
      '              <com:Class Id="$_clsid" DisplayName="Aura call push task" />',
    )
    ..writeln('            </com:ExeServer>')
    ..writeln('          </com:ComServer>')
    ..write('        </com:Extension>');

  // AND NO `windows.backgroundTasks` EXTENSION. THIS IS THE WHOLE FIX.
  //
  // A winmain COM background task is registered IN CODE — `call_push.cpp`
  // calls `BackgroundTaskBuilder::SetTaskEntryPointClsid(kCallPushTaskClsid)`
  // — and the manifest's job is only to declare the COM server that CLSID
  // resolves to. The `windows.backgroundTasks` extension belongs to tasks with
  // a managed entry point, which this is not.
  //
  // Declaring it anyway does not merely add noise; it makes the package
  // impossible to build, and it took two different rejections to read:
  //
  //   as `desktop:Extension`  -> 'windows.backgroundTasks' violates
  //     enumeration constraint of 'windows.fullTrustProcess
  //     windows.startupTask windows.toastNotificationActivation
  //     windows.searchProtocolHandler'
  //
  //   unprefixed, with EntryPoint="Windows.FullTrustApplication"
  //     -> If it is not an audio background task, it is not allowed to have
  //        EntryPoint="Windows.FullTrustApplication"
  //
  // The second message is the real rule, and it was only legible after
  // bisecting the generated manifest against MakeAppx directly — the packer
  // reports the first schema failure it meets and calls the rest
  // "Unspecified error".
  //
  // None of this was found when the declaration was written, because the
  // package was never built again afterwards. The 1.4.4 release gate found
  // it. That is the argument for the gate, and against trusting any
  // declaration nobody has packed.

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
