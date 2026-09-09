import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../application/realtime_providers.dart';
import '../domain/call_occurrence.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_models.dart';

/// THE CALL THAT HAPPENED.
///
/// Call History opens HERE. It used to open the Conversation, which answers a
/// different question — "what have we said to each other" — from the one the
/// person asked, which is "what happened on that call". The conversation is
/// real context and it is one tap away, as secondary navigation.
///
/// A CONSUMER OF CALL TRUTH. Every fact on this screen is read from the
/// canonical `Call` the backend already projects onto the session snapshot.
/// Nothing is written, no outcome is computed here, and no duration is
/// invented. There is no second call authority.
///
/// Ordinary people see a call. Provider session ids, transport generations,
/// track names and SDP are diagnostics, and are deliberately absent.
class CallDetailScreen extends ConsumerStatefulWidget {
  const CallDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends ConsumerState<CallDetailScreen> {
  late Future<RealtimeSessionSnapshot?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<RealtimeSessionSnapshot?> _load() async {
    final repo = ref.read(realtimeRepositoryProvider);
    try {
      return await repo.loadSessionBundle(widget.sessionId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Call',
      maxWidth: 560,
      body: FutureBuilder<RealtimeSessionSnapshot?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            // Through the state authority, not a bare spinner: a whole
            // surface waiting is a product state with copy of its own, and
            // deciding that locally is how one condition ends up looking
            // like five different things across the app.
            // No `subject`: the canonical vocabulary has no "call" noun, and
            // adding one is a decision about Aura's language, not something a
            // screen gets to do on its way past.
            return const AuraProductState(state: ProductState.loading);
          }
          final bundle = snap.data;
          final call = bundle?.session.call;
          if (bundle == null || call == null) {
            return _Unavailable(onBack: () => _back(context));
          }
          return _CallBody(
            occurrence: CallOccurrence(
              sessionId: widget.sessionId,
              call: call,
              viewerUserId: ref.read(currentUserIdProvider),
              participants: bundle.participants,
              conversationId:
                  bundle.session.surfaceType == RealtimeSurfaceType.conversation
                      ? bundle.session.surfaceId
                      : null,
              title: bundle.session.title,
            ),
          );
        },
      ),
    );
  }

  void _back(BuildContext context) {
    // System Back and the visible Back must agree, so both come through here.
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(NavigationAuthority.callHistoryRoute);
  }
}

/// A call record can legitimately be gone — retention, a revoked invitation.
/// Saying so beats an empty screen, and it is not a dead end.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This call is no longer available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Its record may have been removed, or it may no longer be shared with you.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

class _CallBody extends StatelessWidget {
  const _CallBody({required this.occurrence});

  final CallOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = occurrence;
    final headline = callOutcomeHeadline(
      outcome: o.call.outcome,
      viewerIsCaller: o.viewerIsCaller,
      isVideo: o.isVideo,
    );
    final explanation = callOutcomeExplanation(
      outcome: o.call.outcome,
      viewerIsCaller: o.viewerIsCaller,
    );
    final counterpart = o.counterpart;
    final title = o.title?.trim() ?? '';

    // Scrollable even when the content fits, so the page cannot become a dead
    // end when one more fact, one more participant or a shorter window pushes
    // it over the fold.
    //
    // CORRECTION, and worth keeping: this replaced a bare `ListView` that I
    // believed did not scroll at all. It did. My evidence was a drag gesture
    // that moved Home and not this page — but Flutter's default ScrollBehavior
    // disables mouse-DRAG scrolling on desktop and web, and the one place it
    // works is `adaptive_card_grid.dart`, which opts `PointerDeviceKind.mouse`
    // back in. That grid is the Spaces cards on Home, which is exactly where I
    // dragged. A real wheel event scrolls both pages fine.
    //
    // So the change stands on its own small merit and nothing here was ever
    // broken. Left as a caution: a comparison is only a control when both
    // sides are actually comparable.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
        Row(
          children: [
            Icon(
              o.isVideo ? Icons.videocam_outlined : Icons.call_outlined,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    counterpart != null
                        ? counterpart.identityLabel
                        : (title.isNotEmpty ? title : 'Call'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  // Direction is stated plainly, because "Missed call from
                  // them" on your OWN outgoing call is how this went wrong.
                  Text(
                    o.viewerIsCaller ? 'Outgoing' : 'Incoming',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(headline, style: theme.textTheme.titleMedium),
        if (explanation != null) ...[
          const SizedBox(height: 6),
          Text(explanation, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _Fact(
          label: 'Started',
          value: _timestamp(o.call.initiatedAt, TimeEvent.started),
        ),
        // ABSENCE IS A FACT HERE. "Their phone rang" and "their phone never
        // rang" are the difference between ignoring a call and never being
        // offered one, so the ring is stated either way.
        _Fact(
          label: 'Rang',
          value: o.everRang
              ? _timestamp(o.call.ringPresentedAt, TimeEvent.invited)
              : 'Never rang',
        ),
        if (o.call.acceptedAt != null)
          _Fact(
          label: 'Answered',
          value: _timestamp(o.call.acceptedAt, TimeEvent.occurred),
        ),
        _Fact(
          label: 'Connected',
          value: o.everConnected
              ? _timestamp(o.call.connectedAt, TimeEvent.started)
              : 'Never connected',
        ),
        if (o.call.endedAt != null)
          _Fact(
          label: 'Ended',
          value: _timestamp(o.call.endedAt, TimeEvent.ended),
        ),
        // No duration rather than a fabricated one: a call that was declined,
        // missed or cancelled did not last zero seconds — it had no duration.
        _Fact(
          label: 'Duration',
          value: o.duration != null ? _duration(o.duration!) : '—',
        ),
        const SizedBox(height: 24),
        Text('People', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final p in o.participants)
          _Person(participant: p, isCaller: o.call.isCaller(p.userId)),
        if (o.conversationId != null) ...[
          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // SECONDARY, AND EXPLICITLY A SECOND NAVIGATION. The conversation is
          // context for the call; it is not what a call history item is.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.forum_outlined),
            title: const Text('Open conversation'),
            subtitle: const Text('The conversation this call belonged to'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(NavigationAuthority.messagesRoute),
          ),
        ],
        ],
      ),
    );
  }

  /// Exact, through the temporal authority.
  ///
  /// A call's record is the audit-sensitive case `absolute` exists for — the
  /// question here is "when precisely did this happen", never "how long ago".
  /// The event travels with the instant so the authority, and not this
  /// screen, owns what local time means.
  static String _timestamp(DateTime? value, TimeEvent event) {
    if (value == null) return '—';
    return AuraTemporal.absolute(ProductTime(value, event));
  }

  static String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.participant, required this.isCaller});

  final RealtimeParticipant participant;
  final bool isCaller;

  @override
  Widget build(BuildContext context) {
    final avatar = participant.avatarUrl ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.isEmpty
            ? Text(participant.identityLabel.substring(0, 1).toUpperCase())
            : null,
      ),
      title: Text(participant.identityLabel),
      subtitle: Text(isCaller ? 'Called' : 'Was called'),
    );
  }
}
