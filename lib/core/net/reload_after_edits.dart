import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data_changes.dart';

/// A screen that keeps its data in its own State reloads after any edit.
///
/// The provider-held half of "an edit is seen everywhere at once" is
/// [EditRefreshObserver]; this is the other half (2026-10-25). Call
/// [listenForEdits] from `initState`; [reloadAfterEdits] runs once per burst
/// of saved edits, wherever in the app they were made. Editors that seed a
/// form must NOT use this: reloading would discard what is being typed.
mixin ReloadAfterEdits<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _editReload;

  /// Load this screen's data again, quietly where the screen can.
  void reloadAfterEdits();

  void listenForEdits() {
    ref.listenManual<int>(dataEditEpochProvider, (_, __) {
      _editReload?.cancel();
      _editReload = Timer(const Duration(milliseconds: 250), () {
        if (mounted) reloadAfterEdits();
      });
    });
  }

  @override
  void dispose() {
    _editReload?.cancel();
    super.dispose();
  }
}
