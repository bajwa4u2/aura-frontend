import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AN EDIT IS SEEN EVERYWHERE AT ONCE (2026-10-25).
///
/// Founder, after editing the 1.7.0 post: "this is not just for post edit,
/// its for anything you edit" -- announcements, articles, profiles including
/// avatar and cover. Every screen read its data through a provider that kept
/// its first answer, and no save told those providers that the answer had
/// changed, so whatever was edited went on showing the old version until a
/// reload. Fixing that per screen is what let it recur, so it is one rule:
///
///  * the network layer counts every successful edit ([isEditWrite]) in
///    [dataEditEpochProvider];
///  * [EditRefreshObserver] answers each count by invalidating every data
///    reader that is alive. Readers on screen fetch again and keep showing
///    their current value while they do; readers off screen fetch on next use.
///
/// A screen that keeps its data in its own State rather than a provider
/// listens to [dataEditEpochProvider] and loads again.
final dataEditEpochProvider = StateProvider<int>((ref) => 0);

/// Writes that are not an edit of something a person sees: draft autosave,
/// uploads, sign-in, calls, typing, read marks, diagnostics.
const _quietWritePrefixes = <String>[
  '/posts/draft',
  '/media',
  '/auth/refresh',
  '/auth/login',
  '/auth/register',
  '/auth/logout',
  '/realtime',
  '/calls',
  '/presence',
  '/typing',
  '/notifications',
  '/telemetry',
  '/client-errors',
  '/link-preview',
  '/link-intelligence',
  '/translation',
  // Every launch updates this device's record (a PATCH), which would refresh
  // the whole app twice at start-up. The devices screen refreshes its own
  // list after a rename or removal.
  '/devices',
];

/// A POST that changes something that already exists, named by its last
/// path segment (`/meetings/:id/cancel`, `/articles/:id/restore`, ...).
const _editVerbs = <String>{
  'cancel',
  'restore',
  'start',
  'end',
  'reschedule',
  'approve',
  'reject',
  'publish',
  'unpublish',
  'pin',
  'unpin',
  'archive',
  'unarchive',
  'disconnect',
  'revoke',
  'accept',
  'decline',
  'leave',
  'remove',
  'resolve',
  'close',
  'reopen',
  'update',
  'edit',
  'rename',
};

/// Whether a successful request with [method] to [path] edited data.
bool isEditWrite(String method, String path) {
  final m = method.toUpperCase();
  if (m == 'GET' || m == 'HEAD' || m == 'OPTIONS') return false;

  var p = Uri.tryParse(path)?.path ?? path;
  if (p.startsWith('/v1/')) p = p.substring(3);
  if (!p.startsWith('/')) p = '/$p';
  for (final quiet in _quietWritePrefixes) {
    if (p == quiet || p.startsWith('$quiet/')) return false;
  }

  if (m == 'PATCH' || m == 'PUT' || m == 'DELETE') return true;
  if (m != 'POST') return false;
  final segments = p.split('/').where((s) => s.isNotEmpty).toList();
  return segments.isNotEmpty && _editVerbs.contains(segments.last);
}

/// Invalidates every live data reader when [dataEditEpochProvider] moves.
///
/// Data readers are the FutureProviders (plain and family, kept or
/// auto-disposed) plus anything in [include] (paged feeds). [exclude] holds
/// readers that must never run again on their own: session bootstrap,
/// providers that perform an action, signed media links.
class EditRefreshObserver extends ProviderObserver {
  EditRefreshObserver({
    this.exclude = const <Object>{},
    this.include = const <Object>{},
  });

  final Set<Object> exclude;
  final Set<Object> include;

  final Map<ProviderBase<Object?>, ProviderContainer> _live = {};
  Timer? _pending;

  bool _isExcluded(ProviderBase<Object?> provider) =>
      exclude.contains(provider) ||
      (provider.from != null && exclude.contains(provider.from));

  bool _isReader(ProviderBase<Object?> provider) {
    if (_isExcluded(provider)) return false;
    if (include.contains(provider) ||
        (provider.from != null && include.contains(provider.from))) {
      return true;
    }
    return provider is FutureProvider || provider is AutoDisposeFutureProvider;
  }

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (_isReader(provider)) _live[provider] = container;
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    _live.remove(provider);
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (provider != dataEditEpochProvider) return;
    // One refresh for a burst of writes (a save that patches, then deletes).
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 250), refreshAll);
  }

  /// Fetch every live reader again now.
  ///
  /// REFRESH, NOT INVALIDATE. An invalidated reader that nothing listens to
  /// rebuilds only when next read, so a caller already awaiting its `.future`
  /// waited forever: the post composer awaits the home feeds after a save,
  /// this observer invalidated them mid-await, and "Saving…" never ended
  /// (found live on d7bf615, 2026-10-25). Refreshing rebuilds at once, so
  /// every pending `.future` completes with the new answer.
  void refreshAll() {
    _pending = null;
    for (final entry in _live.entries.toList()) {
      try {
        entry.value.refresh(entry.key);
      } catch (_) {
        // A container that was disposed between the write and now.
        _live.remove(entry.key);
      }
    }
  }
}
