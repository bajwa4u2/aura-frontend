import 'package:flutter/material.dart';
import '../kind/kind_composition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/authority/authority_providers.dart';
import '../../../core/authority/capability_projection.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/institutions/institution_paths.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../meetings/application/meetings_provider.dart';
import '../../meetings/domain/meeting.dart';
import '../data/institution_pending_counts.dart';
import '../data/institutions_repository.dart';
import '../engagement/engagement_models.dart';
import '../engagement/engagement_providers.dart';

/// TODAY — THE INSTITUTION'S FRONT DOOR (DD-42 phase 2, 2026-10-09).
///
/// Replaces the admin-only Overview for everyone. Public-first: it leads with
/// what the public is asking, then what is waiting for this person's
/// authority, then what is coming up and what the institution last said.
/// Each block shows only what the viewer may act on; nothing is greyed out.
class InstitutionTodayScreen extends ConsumerWidget {
  const InstitutionTodayScreen({super.key, required this.institutionId});

  /// The institution's address (slug) or id, as the route resolved it.
  final String institutionId;

  bool _may(CapabilityProjection p, ConsequentialAct act) =>
      p.presentationFor(act) == ControlPresentation.available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projection = ref.watch(capabilityProjectionForProvider(institutionId));
    final name = projection.standing?.institutionName.trim() ?? '';
    final mayAnswerJoins = _may(projection, ConsequentialAct.manageJoinRequests);
    final mayInvite = _may(projection, ConsequentialAct.manageInvitations);
    final mayWrite = _may(projection, ConsequentialAct.authorOfficialContent) ||
        _may(projection, ConsequentialAct.publishAnnouncement);
    final mayHost = _may(projection, ConsequentialAct.hostMeeting) ||
        _may(projection, ConsequentialAct.manageMeetings);

    String path(InstitutionSection s) => institutionWorkspacePath(institutionId, s);
    final composition = compositionForInstitution(ref, institutionId);

    // Verification not finished: say so to whoever can finish it. The shell's
    // identity says whether it is verified, so it is asked only when it names
    // the institution in the address.
    final idn = ref.watch(institutionIdentityProvider);
    final isThisInstitution = idn != null &&
        (idn.id == institutionId || idn.slug == institutionId || idn.workspaceAddress == institutionId);
    final showVerification = isThisInstitution &&
        !idn.isVerified &&
        _may(projection, ConsequentialAct.manageVerification);

    return AuraScaffold(
      title: 'Today',
      showHomeAction: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s8,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Text(
            [if (name.isNotEmpty) name, AuraTemporal.day(DateTime.now())].join(' · '),
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s16),
          if (showVerification) ...[
            _Block(
              icon: Icons.verified_outlined,
              title: 'Finish verification',
              actionLabel: 'Continue',
              actionPath: path(InstitutionSection.verification),
              child: const _Quiet(
                'The institution shows as awaiting verification until you show that it exists '
                'and that you may speak for it. People can follow it meanwhile.',
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
          ],
          if (mayAnswerJoins || mayInvite || mayWrite)
            _WaitingForYou(
              institutionId: institutionId,
              joinRequestsPath: mayAnswerJoins ? path(InstitutionSection.joinRequests) : null,
              invitesPath: mayInvite ? path(InstitutionSection.invites) : null,
              announcementsPath: mayWrite ? path(InstitutionSection.announcements) : null,
            ),
          // The kind decides the order below what waits for this person
          // (DD-42 phase 3): a school leads with its notices, a city with
          // what residents are asking.
          for (final block in composition.todayOrder) ...[
            if (block == 'public')
              _PublicQuestions(
                institutionId: institutionId,
                allPath: path(InstitutionSection.publicEngagement),
                publicWord: composition.publicWord,
              )
            else if (block == 'meetings')
              _MeetingsAhead(
                institutionId: institutionId,
                allPath: path(InstitutionSection.meetings),
                newPath: mayHost ? '${path(InstitutionSection.meetings)}/new' : null,
              )
            else if (block == 'announcement')
              _LatestAnnouncement(
                institutionId: institutionId,
                allPath: path(InstitutionSection.announcements),
                writePath: mayWrite ? '${path(InstitutionSection.announcements)}/new' : null,
              ),
            const SizedBox(height: AuraSpace.s16),
          ],
        ],
      ),
    );
  }
}

/// One titled block on Today.
class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.title,
    required this.child,
    this.actionLabel,
    this.actionPath,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final String? actionLabel;
  final String? actionPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AuraSurface.accent),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (actionLabel != null && (actionPath ?? '').isNotEmpty)
                TextButton(
                  onPressed: () => context.push(actionPath!),
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          child,
        ],
      ),
    );
  }
}

/// A plain sentence inside a block, for when there is nothing to list.
class _Quiet extends StatelessWidget {
  const _Quiet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.45));
}

/// A tappable line inside a block.
class _Line extends StatelessWidget {
  const _Line({required this.title, this.detail, required this.path, this.count});

  final String title;
  final String? detail;
  final String path;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: path.isEmpty ? null : () => context.push(path),
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s8),
        child: Row(
          children: [
            if (count != null) ...[
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AuraSurface.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AuraRadius.xl),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: AuraText.small.copyWith(color: AuraSurface.accent, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AuraText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if ((detail ?? '').isNotEmpty)
                    Text(detail!, style: AuraText.small.copyWith(color: AuraSurface.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AuraSurface.muted),
          ],
        ),
      ),
    );
  }
}

// ── Waiting for you ─────────────────────────────────────────────────────────

final _draftCountProvider = FutureProvider.autoDispose.family<int, String>((ref, institutionId) async {
  final drafts = await ref.watch(institutionsRepositoryProvider).listInstitutionDrafts(institutionId);
  return drafts.length;
});

class _WaitingForYou extends ConsumerWidget {
  const _WaitingForYou({
    required this.institutionId,
    this.joinRequestsPath,
    this.invitesPath,
    this.announcementsPath,
  });

  final String institutionId;
  final String? joinRequestsPath;
  final String? invitesPath;
  final String? announcementsPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = (joinRequestsPath != null || invitesPath != null)
        ? ref.watch(institutionPendingCountsProvider(institutionId)).valueOrNull
        : null;
    final drafts = announcementsPath != null
        ? ref.watch(_draftCountProvider(institutionId)).valueOrNull ?? 0
        : 0;
    final joins = joinRequestsPath != null ? (counts?.joinRequests ?? 0) : 0;
    final invites = invitesPath != null ? (counts?.invites ?? 0) : 0;

    // Nothing waiting is not news: the block only appears when something is.
    if (joins == 0 && invites == 0 && drafts == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s16),
      child: _Block(
        icon: Icons.inbox_outlined,
        title: 'Waiting for you',
        child: Column(
          children: [
            if (joins > 0)
              _Line(
                count: joins,
                title: joins == 1 ? 'A person asks to join' : 'People ask to join',
                path: joinRequestsPath!,
              ),
            if (drafts > 0)
              _Line(
                count: drafts,
                title: drafts == 1 ? 'A draft announcement' : 'Draft announcements',
                detail: 'Not yet published',
                path: announcementsPath!,
              ),
            if (invites > 0)
              _Line(
                count: invites,
                title: invites == 1 ? 'An invite not yet accepted' : 'Invites not yet accepted',
                path: invitesPath!,
              ),
          ],
        ),
      ),
    );
  }
}

// ── What the public is asking ───────────────────────────────────────────────

class _PublicQuestions extends ConsumerWidget {
  const _PublicQuestions({required this.institutionId, required this.allPath, this.publicWord = 'the public'});

  final String institutionId;
  final String allPath;

  /// "residents", "the congregation" — the kind's word for its public.
  final String publicWord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(engagementListProvider(institutionId));
    return _Block(
      icon: Icons.record_voice_over_outlined,
      // "What residents are asking" / "What the congregation is asking".
      title: 'What $publicWord ${publicWord.startsWith('the ') ? 'is' : 'are'} asking',
      actionLabel: 'All questions',
      actionPath: allPath,
      child: async.when(
        loading: () => const AuraProductState(state: ProductState.loading, scope: StateScope.inline),
        error: (_, __) => const _Quiet('Questions could not be loaded just now.'),
        data: (records) {
          final waiting = records.where((r) => r.status == RoutedRecordStatus.pending).toList();
          if (waiting.isEmpty) {
            return const _Quiet(
              'No questions are waiting. When someone asks a question or raises an issue on a topic this institution has taken on, it appears here.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                waiting.length == 1 ? '1 question is waiting for a response.' : '${waiting.length} questions are waiting for a response.',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
              for (final r in waiting.take(3))
                _Line(
                  title: (r.postText ?? '').trim().isEmpty ? 'A question from the public' : r.postText!.trim(),
                  detail: r.authorName,
                  path: '$allPath/${r.id}',
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Meetings ahead ──────────────────────────────────────────────────────────

class _MeetingsAhead extends ConsumerWidget {
  const _MeetingsAhead({required this.institutionId, required this.allPath, this.newPath});

  final String institutionId;
  final String allPath;
  final String? newPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(institutionUpcomingMeetingsProvider(institutionId));
    return _Block(
      icon: Icons.videocam_outlined,
      title: 'Meetings ahead',
      actionLabel: newPath != null ? 'New meeting' : 'All meetings',
      actionPath: newPath ?? allPath,
      child: async.when(
        loading: () => const AuraProductState(state: ProductState.loading, scope: StateScope.inline),
        error: (_, __) => const _Quiet('Meetings could not be loaded just now.'),
        data: (List<Meeting> meetings) {
          final ahead = meetings.where((m) => m.scheduledAt != null).toList()
            ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
          if (ahead.isEmpty) return const _Quiet('Nothing is scheduled.');
          return Column(
            children: [
              for (final m in ahead.take(3))
                _Line(
                  title: m.title.trim().isEmpty ? 'Meeting' : m.title.trim(),
                  detail: AuraTemporal.fullShort(m.scheduledAt!),
                  path: '$allPath/${m.id}',
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── What the institution last said ──────────────────────────────────────────

final _latestAnnouncementProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, institutionId) async {
  final list = await ref.watch(institutionsRepositoryProvider).listInstitutionAnnouncements(institutionId);
  return list.isEmpty ? null : list.first;
});

class _LatestAnnouncement extends ConsumerWidget {
  const _LatestAnnouncement({required this.institutionId, required this.allPath, this.writePath});

  final String institutionId;
  final String allPath;
  final String? writePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_latestAnnouncementProvider(institutionId));
    return _Block(
      icon: Icons.campaign_outlined,
      title: 'Last announcement',
      actionLabel: writePath != null ? 'Write one' : null,
      actionPath: writePath,
      child: async.when(
        loading: () => const AuraProductState(state: ProductState.loading, scope: StateScope.inline),
        error: (_, __) => const _Quiet('Announcements could not be loaded just now.'),
        data: (a) {
          if (a == null) return const _Quiet('Nothing announced yet.');
          final title = (a['title'] ?? '').toString().trim();
          final at = DateTime.tryParse((a['publishedAt'] ?? a['createdAt'] ?? '').toString());
          return _Line(
            title: title.isEmpty ? 'Announcement' : title,
            detail: at == null ? null : AuraTemporal.fullShort(at),
            path: allPath,
          );
        },
      ),
    );
  }
}
