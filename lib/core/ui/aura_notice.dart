import 'dart:async';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'aura_radius.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

/// THE AURA NOTICE — the one way Aura tells a person that something happened.
///
/// Founder-approved spec (21 Oct 2026), amended the same day to follow each
/// platform's own convention. Every former `showSnackBar` call goes through
/// here; a guard test refuses any new one.
///
/// Same everywhere: Aura tokens, an icon by kind, plain words, one notice at a
/// time (a new one replaces the old), an optional single action, and a
/// screen-reader announcement.
///
/// Per platform, behind this one API:
///  * Android, and a phone-width browser: a Material snackbar at the bottom,
///    full width less 16 px gutters (at most 560 px, centred), above the
///    bottom navigation, any registered composer bar and the keyboard; swiped
///    sideways to dismiss.
///  * iOS: a banner that drops in at the TOP below the notch, swiped up to
///    dismiss, with a light haptic on a problem.
///  * Windows, macOS, Linux: a toast card in the bottom-RIGHT corner; hover
///    pauses it, × is always there, Esc dismisses it.
///  * A desktop-width browser: the same card in the bottom-LEFT corner.
///
/// Done and info stay 4 s, a problem 6 s with ×.
/// The app's one ScaffoldMessenger (MaterialApp.scaffoldMessengerKey).
final auraScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

enum AuraNoticeKind { done, info, problem }

/// The single optional action a notice may carry: Undo, Retry, View…
class AuraNoticeAction {
  const AuraNoticeAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// How a notice is presented on the platform it runs on.
enum AuraNoticePresentation { snackbar, banner, cornerRight, cornerLeft }

class AuraNotice {
  AuraNotice._();

  static const Duration shortDuration = Duration(seconds: 4);
  static const Duration problemDuration = Duration(seconds: 6);

  /// Below this width a browser behaves like a phone.
  static const double phoneWidth = 600;

  /// Tests set this to exercise the browser presentations off the web.
  @visibleForTesting
  static bool? debugIsWebOverride;

  static bool get _isWeb => debugIsWebOverride ?? kIsWeb;

  /// Something the person asked for has happened.
  static void done(
    BuildContext? context,
    String message, {
    AuraNoticeAction? action,
  }) => show(context, message, kind: AuraNoticeKind.done, action: action);

  /// Something the person should know, that is neither success nor failure.
  static void info(
    BuildContext? context,
    String message, {
    AuraNoticeAction? action,
  }) => show(context, message, kind: AuraNoticeKind.info, action: action);

  /// Something did not happen. Say what, and what to do about it.
  static void problem(
    BuildContext? context,
    String message, {
    AuraNoticeAction? action,
  }) => show(context, message, kind: AuraNoticeKind.problem, action: action);

  /// Something was copied. Android 13 and later confirm every copy with a
  /// system message of their own, so there Aura says nothing more: two
  /// confirmations of one tap read as a fault. Everywhere else this is a
  /// done notice.
  static void copied(BuildContext? context, String message) {
    if (systemConfirmsCopy) {
      dismissAll();
      return;
    }
    done(context, message);
  }

  /// Android's API level, read once when the host mounts.
  static int? _androidSdk;

  @visibleForTesting
  static int? debugAndroidSdkOverride;

  /// True where the platform itself confirms a copy to the clipboard.
  static bool get systemConfirmsCopy =>
      !_isWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      (debugAndroidSdkOverride ?? _androidSdk ?? 0) >= 33;

  static Future<void> _readPlatform() async {
    if (_isWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_androidSdk != null) return;
    try {
      _androidSdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {
      // Unknown: Aura confirms the copy itself, which is never wrong.
    }
  }

  /// Captures where a notice will go BEFORE an await, the way
  /// `ScaffoldMessenger.of(context)` used to be captured, so the notice still
  /// lands after the widget that asked for it has gone.
  static AuraNoticeHandle of(BuildContext context) => AuraNoticeHandle._(
    ScaffoldMessenger.maybeOf(context),
    presentationFor(context),
  );

  /// Which presentation this platform and window take.
  static AuraNoticePresentation presentationFor(BuildContext? context) {
    final width = context == null
        ? _fallbackWidth()
        : (MediaQuery.maybeSizeOf(context)?.width ?? _fallbackWidth());
    if (_isWeb) {
      return width < phoneWidth
          ? AuraNoticePresentation.snackbar
          : AuraNoticePresentation.cornerLeft;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return AuraNoticePresentation.banner;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return AuraNoticePresentation.cornerRight;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return AuraNoticePresentation.snackbar;
    }
  }

  static double _fallbackWidth() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 400;
    final view = views.first;
    return view.physicalSize.width / view.devicePixelRatio;
  }

  static void show(
    BuildContext? context,
    String message, {
    required AuraNoticeKind kind,
    AuraNoticeAction? action,
  }) {
    _present(
      context == null ? null : ScaffoldMessenger.maybeOf(context),
      presentationFor(context),
      message,
      kind,
      action,
    );
  }

  /// Takes down whatever notice is showing, in any presentation.
  static void dismissAll() {
    for (final messenger in {
      auraScaffoldMessengerKey.currentState,
      _lastMessenger,
    }) {
      if (messenger != null && messenger.mounted) messenger.clearSnackBars();
    }
    AuraNoticeHost._active?._clear();
  }

  static ScaffoldMessengerState? _lastMessenger;

  /// One house style: a notice ends as a sentence does. Messages from the
  /// server or older call sites that stop short get their full stop here.
  static String _houseStyle(String message) {
    final text = message.trim();
    if (text.isEmpty) return text;
    const ends = '.!?…)"”';
    return ends.contains(text[text.length - 1]) ? text : '$text.';
  }

  static void _present(
    ScaffoldMessengerState? messenger,
    AuraNoticePresentation presentation,
    String message,
    AuraNoticeKind kind,
    AuraNoticeAction? action,
  ) {
    final text = _houseStyle(message);
    if (text.isEmpty) return;
    // One at a time, whatever presented the last one.
    dismissAll();

    final host = AuraNoticeHost._active;
    if (presentation != AuraNoticePresentation.snackbar && host != null) {
      host._show(_NoticeData(text, kind, action, presentation));
      if (kind == AuraNoticeKind.problem &&
          presentation == AuraNoticePresentation.banner) {
        HapticFeedback.lightImpact();
      }
      return;
    }

    final target = (messenger != null && messenger.mounted)
        ? messenger
        : auraScaffoldMessengerKey.currentState;
    if (target == null) return;
    _lastMessenger = target;
    final size = MediaQuery.maybeSizeOf(target.context) ?? const Size(400, 800);
    final side = math.max(16.0, (size.width - 560) / 2);
    target.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(side, 0, side, 12 + AuraNoticeLift.height),
        dismissDirection: DismissDirection.horizontal,
        duration: kind == AuraNoticeKind.problem
            ? problemDuration
            : shortDuration,
        // A notice with an action still times out: the action is an offer,
        // not a question the person must answer.
        persist: false,
        showCloseIcon: kind == AuraNoticeKind.problem,
        content: _NoticeBody(text: text, kind: kind),
        action: action == null
            ? null
            : SnackBarAction(label: action.label, onPressed: action.onPressed),
      ),
    );
  }
}

/// A notice destination captured ahead of an await.
class AuraNoticeHandle {
  AuraNoticeHandle._(this._messenger, this._presentation);

  final ScaffoldMessengerState? _messenger;
  final AuraNoticePresentation _presentation;

  void done(String message, {AuraNoticeAction? action}) =>
      show(message, kind: AuraNoticeKind.done, action: action);

  void info(String message, {AuraNoticeAction? action}) =>
      show(message, kind: AuraNoticeKind.info, action: action);

  void problem(String message, {AuraNoticeAction? action}) =>
      show(message, kind: AuraNoticeKind.problem, action: action);

  void show(
    String message, {
    required AuraNoticeKind kind,
    AuraNoticeAction? action,
  }) => AuraNotice._present(_messenger, _presentation, message, kind, action);
}

/// Bottom-anchored bars (a message composer, a reply bar, the post composer's
/// action bar) register their height here while they are on screen, so a
/// notice at the bottom sits ABOVE them and never covers Send.
///
/// Do not wrap a Scaffold's own bottomNavigationBar: the Scaffold already
/// lifts its snackbars above that.
class AuraNoticeLift extends StatefulWidget {
  const AuraNoticeLift({super.key, required this.child});

  final Widget child;

  static final Map<Object, double Function()> _bars = {};

  /// The tallest registered bar that is on screen now.
  static double get height {
    var tallest = 0.0;
    for (final read in _bars.values) {
      tallest = math.max(tallest, read());
    }
    return tallest;
  }

  @visibleForTesting
  static void debugReset() => _bars.clear();

  @override
  State<AuraNoticeLift> createState() => _AuraNoticeLiftState();
}

class _AuraNoticeLiftState extends State<AuraNoticeLift> {
  final _key = GlobalKey();
  final _token = Object();

  double _read() {
    if (!mounted) return 0;
    // A bar on a route that is covered by another is not in the way.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return 0;
    final box = _key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return 0;
    // Only the part of the bar above the bottom inset matters: the snackbar
    // already sits above the keyboard and the system bar.
    final view = MediaQuery.maybeOf(context);
    final screenHeight = view?.size.height ?? 0;
    final bottomInset = math.max(
      view?.viewInsets.bottom ?? 0,
      view?.viewPadding.bottom ?? 0,
    );
    final top = box.localToGlobal(Offset.zero).dy;
    final lift = screenHeight - bottomInset - top;
    return lift.clamp(0, box.size.height + 24).toDouble();
  }

  @override
  void initState() {
    super.initState();
    AuraNoticeLift._bars[_token] = _read;
  }

  @override
  void dispose() {
    AuraNoticeLift._bars.remove(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

class _NoticeData {
  _NoticeData(this.text, this.kind, this.action, this.presentation);

  final String text;
  final AuraNoticeKind kind;
  final AuraNoticeAction? action;
  final AuraNoticePresentation presentation;
}

/// Hosts the banner and corner presentations above the whole app. Mounted
/// once, in MaterialApp's builder, under MediaQuery and Directionality.
class AuraNoticeHost extends StatefulWidget {
  const AuraNoticeHost({super.key, required this.child});

  final Widget child;

  static _AuraNoticeHostState? _active;

  @override
  State<AuraNoticeHost> createState() => _AuraNoticeHostState();
}

class _AuraNoticeHostState extends State<AuraNoticeHost> {
  _NoticeData? _current;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    AuraNoticeHost._active = this;
    AuraNotice._readPlatform();
  }

  @override
  void dispose() {
    if (AuraNoticeHost._active == this) AuraNoticeHost._active = null;
    super.dispose();
  }

  void _show(_NoticeData data) {
    if (!mounted) return;
    setState(() {
      _current = data;
      _serial++;
    });
    final view = View.maybeOf(context);
    if (view != null) {
      SemanticsService.sendAnnouncement(
        view,
        data.text,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    }
  }

  void _clear() {
    if (!mounted || _current == null) return;
    setState(() => _current = null);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (current != null)
          _PositionedNotice(
            key: ValueKey(_serial),
            data: current,
            onGone: _clear,
          ),
      ],
    );
  }
}

class _PositionedNotice extends StatelessWidget {
  const _PositionedNotice({
    super.key,
    required this.data,
    required this.onGone,
  });

  final _NoticeData data;
  final VoidCallback onGone;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    switch (data.presentation) {
      case AuraNoticePresentation.banner:
        final side = math.max(16.0, (width - 560) / 2);
        return Positioned(
          top: media.padding.top + 8,
          left: side,
          right: side,
          child: _NoticeCard(data: data, onGone: onGone),
        );
      case AuraNoticePresentation.cornerRight:
      case AuraNoticePresentation.cornerLeft:
        final cardWidth = math.min(420.0, math.max(0.0, width - 32));
        final bottom =
            16 +
            math.max(media.viewInsets.bottom, media.padding.bottom) +
            AuraNoticeLift.height;
        return Positioned(
          bottom: bottom,
          right: data.presentation == AuraNoticePresentation.cornerRight
              ? 16
              : null,
          left: data.presentation == AuraNoticePresentation.cornerLeft
              ? 16
              : null,
          width: math.max(math.min(360.0, width - 32), cardWidth),
          child: _NoticeCard(data: data, onGone: onGone),
        );
      case AuraNoticePresentation.snackbar:
        return const SizedBox.shrink();
    }
  }
}

/// The banner / toast card: timer, hover pause, Esc, swipe, ×.
class _NoticeCard extends StatefulWidget {
  const _NoticeCard({required this.data, required this.onGone});

  final _NoticeData data;
  final VoidCallback onGone;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  Timer? _timer;
  late Duration _remaining = widget.data.kind == AuraNoticeKind.problem
      ? AuraNotice.problemDuration
      : AuraNotice.shortDuration;
  final Stopwatch _running = Stopwatch();

  bool get _isBanner =>
      widget.data.presentation == AuraNoticePresentation.banner;

  @override
  void initState() {
    super.initState();
    _start();
    if (!_isBanner) HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _entrance.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _dismiss();
      return true;
    }
    return false;
  }

  void _start() {
    _timer?.cancel();
    _running
      ..reset()
      ..start();
    _timer = Timer(_remaining, _dismiss);
  }

  void _pause() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    _running.stop();
    final left = _remaining - _running.elapsed;
    _remaining = left.isNegative ? Duration.zero : left;
  }

  void _resume() {
    if (_timer != null) return;
    _start();
  }

  void _dismiss() {
    _timer?.cancel();
    _timer = null;
    if (mounted) widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    // Desktop and browser cards always carry ×; a banner shows it for a
    // problem, like the snackbar.
    final showClose = !_isBanner || data.kind == AuraNoticeKind.problem;
    final card = Material(
      color: AuraSurface.elevated,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        side: const BorderSide(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: _NoticeBody(text: data.text, kind: data.kind),
            ),
            if (data.action != null)
              TextButton(
                onPressed: () {
                  data.action!.onPressed();
                  _dismiss();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AuraSurface.accent,
                ),
                child: Text(data.action!.label),
              ),
            if (showClose)
              Semantics(
                button: true,
                label: 'Dismiss',
                child: IconButton(
                  key: const ValueKey('aura-notice-close'),
                  onPressed: _dismiss,
                  icon: const Icon(Icons.close, size: 18),
                  color: AuraSurface.muted,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );

    final slide = Tween<Offset>(
      begin: Offset(0, _isBanner ? -0.6 : 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));

    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: _entrance,
        child: MouseRegion(
          onEnter: (_) => _pause(),
          onExit: (_) => _resume(),
          child: Dismissible(
            key: const ValueKey('aura-notice'),
            direction: _isBanner
                ? DismissDirection.up
                : DismissDirection.horizontal,
            onDismissed: (_) => _dismiss(),
            child: Semantics(liveRegion: true, container: true, child: card),
          ),
        ),
      ),
    );
  }
}

class _NoticeBody extends StatelessWidget {
  const _NoticeBody({required this.text, required this.kind});

  final String text;
  final AuraNoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (kind) {
      AuraNoticeKind.done => (Icons.check_circle_outline, AuraSurface.accent),
      AuraNoticeKind.info => (Icons.info_outline, AuraSurface.muted),
      AuraNoticeKind.problem => (Icons.error_outline, AuraSurface.dangerInk),
    };
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AuraText.body.copyWith(color: AuraSurface.ink),
          ),
        ),
      ],
    );
  }
}
