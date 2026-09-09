import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/navigation/navigation_authority.dart';
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
            return const Center(child: CircularProgressIndicator());
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

    // THE PAGE MUST OWN ITS SCROLL.
    //
    // This shipped as a bare `ListView` and did not scroll at all: everything
    // below the fold — the second participant and the conversation link — was
    // unreachable on a normal window. Proven by comparison, not assumed: a
    // drag scrolls Home and did nothing here.
    //
    // `AlwaysScrollableScrollPhysics` is the load-bearing part. It makes the
    // surface scrollable even when the content happens to fit, so the page
    // does not silently become a dead end the moment one more fact, one more
    // participant, or a smaller window pushes it over.
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
        _Fact(label: 'Started', value: _timestamp(o.call.initiatedAt)),
        // ABSENCE IS A FACT HERE. "Their phone rang" and "their phone never
        // rang" are the difference between ignoring a call and never being
        // offered one, so the ring is stated either way.
        _Fact(
          label: 'Rang',
          value: o.everRang ? _timestamp(o.call.ringPresentedAt) : 'Never rang',
        ),
        if (o.call.acceptedAt != null)
          _Fact(label: 'Answered', value: _timestamp(o.call.acceptedAt)),
        _Fact(
          label: 'Connected',
          value: o.everConnected
              ? _timestamp(o.call.connectedAt)
              : 'Never connected',
        ),
        if (o.call.endedAt != null)
          _Fact(label: 'Ended', value: _timestamp(o.call.endedAt)),
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

  static String _timestamp(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
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
