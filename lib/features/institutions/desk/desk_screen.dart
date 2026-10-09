import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/authority/authority_providers.dart';
import '../../../core/authority/capability_projection.dart';
import '../../../core/errors/server_refusal.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/institutions/institution_paths.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../topics/topic.dart';
import '../engagement/question_record.dart';
import '../workspace/workspace_page.dart';
import 'desk_models.dart';
import 'desk_providers.dart';

/// THE DESK (DD-43, 2026-10-09): the institution workspace's first screen.
///
/// One queue of everything waiting for this person, from every section:
/// questions and issues, commitments coming due, join requests, their own
/// drafts, meetings starting and follow-ups. Live and overdue first, then
/// oldest first. A question opens beside the queue on wide screens and is
/// answered there, with Memory beside the answer; on narrow screens it opens
/// as its own page. Everything else opens where it is handled.
class DeskScreen extends ConsumerStatefulWidget {
  const DeskScreen({super.key, required this.institutionId, this.initialTab});

  /// The institution's address or id, as the route resolved it.
  final String institutionId;
  final DeskTab? initialTab;

  @override
  ConsumerState<DeskScreen> createState() => _DeskScreenState();
}

class _DeskScreenState extends ConsumerState<DeskScreen> {
  late DeskTab _tab = widget.initialTab ?? DeskTab.all;
  String? _openKey;

  String _path(InstitutionSection s) => institutionWorkspacePath(widget.institutionId, s);

  void _open(DeskItem item, {required bool beside}) {
    if (item.isRecord) {
      if (beside) {
        setState(() => _openKey = item.key);
      } else {
        context.push('${_path(InstitutionSection.publicEngagement)}/${item.id}?from=desk');
      }
      return;
    }
    switch (item.type) {
      case DeskItemType.joinRequest:
        context.push('${_path(InstitutionSection.members)}?tab=requests');
      case DeskItemType.draft:
        context.push('${_path(InstitutionSection.announcements)}/${item.id}/edit');
      case DeskItemType.meeting:
        // Inside the institution's own Meetings, so the workspace stays around it.
        final meeting = '${_path(InstitutionSection.meetings)}/${item.id}';
        context.push(meeting);
      case DeskItemType.followUp:
        final meetingId = item.meta['meetingId']?.toString();
        final target = meetingId == null
            ? _path(InstitutionSection.meetings)
            : '${_path(InstitutionSection.meetings)}/$meetingId';
        context.push(target);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(deskProvider(widget.institutionId));
    final projection = ref.watch(capabilityProjectionForProvider(widget.institutionId));
    final name = projection.standing?.institutionName.trim() ?? '';

    // Verification not finished: the one thing above the queue, for whoever
    // can finish it.
    final idn = ref.watch(institutionIdentityProvider);
    final isThis = idn != null &&
        (idn.id == widget.institutionId || idn.slug == widget.institutionId || idn.workspaceAddress == widget.institutionId);
    final mayVerify = projection.presentationFor(ConsequentialAct.manageVerification) == ControlPresentation.available;
    final showVerification = isThis && !idn.isVerified && mayVerify;

    final snapshot = async.valueOrNull ?? DeskSnapshot.empty;
    final items = snapshot.items.where((i) => _tab.holds(i.type)).toList();

    return LayoutBuilder(
      builder: (context, box) {
        final beside = WorkspacePage.opensBeside(context, box.maxWidth);
        // Wide screens never show an empty half: the first question opens.
        DeskItem? open;
        if (beside) {
          final records = items.where((i) => i.isRecord);
          open = records.where((i) => i.key == _openKey).firstOrNull ?? records.firstOrNull;
        }

        return WorkspacePage(
          type: WorkspacePageType.collection,
          title: 'Desk',
          purpose: name.isEmpty
              ? 'Everything waiting for you: live and overdue first, then oldest first.'
              : 'Everything waiting for you at $name: live and overdue first, then oldest first.',
          tabs: [
            for (final t in DeskTab.values)
              if (t == DeskTab.all || snapshot.count(t) > 0 || t == _tab)
                WorkspaceTab(id: t.wire, label: t.label, count: async.hasValue ? snapshot.count(t) : null),
          ],
          selectedTab: _tab.wire,
          onTab: (id) => setState(() {
            _tab = DeskTab.values.firstWhere((t) => t.wire == id);
          }),
          loading: async.isLoading && !async.hasValue,
          detail: open == null
              ? null
              : QuestionRecord(
                  key: ValueKey(open.key),
                  institutionId: widget.institutionId,
                  recordId: open.id,
                ),
          children: [
            if (showVerification)
              WorkspaceRow(
                leading: const WorkspaceIcon(Icons.verified_outlined, tone: WorkspaceTone.waiting),
                title: 'Finish verifying the institution',
                context: 'Until it is verified, the public sees it as set up, awaiting verification.',
                pill: const WorkspacePill(label: 'Set up', tone: WorkspaceTone.waiting),
                onTap: () => context.push(_path(InstitutionSection.verification)),
              ),
            if (async.hasError && !async.hasValue)
              WorkspaceEmpty(
                icon: Icons.error_outline_rounded,
                title: 'The Desk could not be loaded',
                body: ServerRefusal.of(async.error!).message ?? 'Check the connection and try again.',
                action: WorkspaceAction(
                  label: ProductLabels.of(ProductAction.retry),
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.invalidate(deskProvider(widget.institutionId)),
                ),
              )
            else if (items.isEmpty)
              _empty()
            else
              for (final item in items)
                _DeskRow(
                  item: item,
                  selected: open?.key == item.key,
                  onTap: () => _open(item, beside: beside),
                ),
          ],
        );
      },
    );
  }

  Widget _empty() {
    final (title, body) = switch (_tab) {
      DeskTab.all => (
          'Nothing is waiting for you',
          'New questions, commitments coming due, join requests, your drafts and meetings starting soon appear here.',
        ),
      DeskTab.questions => ('No questions waiting', 'When someone asks or raises an issue on a topic you have taken on, it appears here.'),
      DeskTab.commitments => ('No open commitments', 'When you commit to act on an issue, it stays here with its date until it is resolved.'),
      DeskTab.joinRequests => ('No join requests', 'When someone asks to join, it appears here.'),
      DeskTab.drafts => ('No drafts', 'Announcements you start and do not publish wait here.'),
      DeskTab.meetings => ('No meetings soon', 'Meetings you host or attend appear here on the day, and follow-ups assigned to you until they are done.'),
    };
    return WorkspaceEmpty(icon: Icons.inbox_outlined, title: title, body: body);
  }
}

/// How long something has waited, in plain words.
String _waited(DateTime since) {
  final d = DateTime.now().difference(since);
  if (d.inMinutes < 60) return 'just now';
  if (d.inHours < 24) return d.inHours == 1 ? 'for an hour' : 'for ${d.inHours} hours';
  return d.inDays == 1 ? 'for a day' : 'for ${d.inDays} days';
}

class _DeskRow extends StatelessWidget {
  const _DeskRow({required this.item, required this.selected, required this.onTap});

  final DeskItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final who = item.person?.label;
    final topic = AuraTopic.fromWire(item.meta['topic']?.toString())?.label;
    final due = item.dueAt;

    Widget avatar() => AuraAvatar(name: who ?? '?', imageUrl: item.person?.avatarUrl, size: 36);

    final (Widget leading, String context, WorkspacePill pill) = switch (item.type) {
      DeskItemType.question || DeskItemType.issue => (
          avatar(),
          [
            item.type == DeskItemType.issue ? 'Raised issue' : 'Question',
            if (who != null) who,
            if (topic != null) topic,
            'waiting ${_waited(item.since)}',
          ].join(' · '),
          item.meta['acknowledged'] == true
              ? const WorkspacePill(label: 'Acknowledged', tone: WorkspaceTone.waiting)
              : const WorkspacePill(label: 'Waiting', tone: WorkspaceTone.waiting),
        ),
      DeskItemType.commitment => (
          WorkspaceIcon(
            Icons.handshake_outlined,
            tone: item.urgency == DeskUrgency.overdue ? WorkspaceTone.problem : WorkspaceTone.waiting,
          ),
          ['Commitment', if (who != null) 'promised to $who', if (topic != null) topic].join(' · '),
          due == null
              ? const WorkspacePill(label: 'Set a date', tone: WorkspaceTone.waiting)
              : item.urgency == DeskUrgency.overdue
                  ? WorkspacePill(label: 'Was due ${AuraTemporal.dueDay(due)}', tone: WorkspaceTone.problem)
                  : WorkspacePill(label: 'Due ${AuraTemporal.dueDay(due)}', tone: WorkspaceTone.waiting),
        ),
      DeskItemType.joinRequest => (
          avatar(),
          'Join request · ${AuraTemporal.fullShort(item.since)}',
          const WorkspacePill(label: 'Review'),
        ),
      DeskItemType.draft => (
          const WorkspaceIcon(Icons.edit_note_rounded),
          'Your draft announcement · last edited ${AuraTemporal.fullShort(item.since)}',
          const WorkspacePill(label: 'Draft'),
        ),
      DeskItemType.meeting => (
          WorkspaceIcon(Icons.videocam_outlined, tone: item.urgency == DeskUrgency.now ? WorkspaceTone.live : WorkspaceTone.neutral),
          item.meta['live'] == true ? 'Meeting · live now' : 'Meeting · starts ${AuraTemporal.fullShort(due ?? item.since)}',
          item.meta['live'] == true
              ? const WorkspacePill(label: 'Live', tone: WorkspaceTone.live)
              : item.urgency == DeskUrgency.now
                  ? const WorkspacePill(label: 'Starting', tone: WorkspaceTone.live)
                  : const WorkspacePill(label: 'Today'),
        ),
      DeskItemType.followUp => (
          WorkspaceIcon(Icons.checklist_rounded, tone: item.urgency == DeskUrgency.overdue ? WorkspaceTone.problem : WorkspaceTone.neutral),
          'Follow-up${item.meta['meetingTitle'] != null ? ' from ${item.meta['meetingTitle']}' : ''}',
          due == null
              ? const WorkspacePill(label: 'Open')
              : item.urgency == DeskUrgency.overdue
                  ? WorkspacePill(label: 'Was due ${AuraTemporal.dueDay(due)}', tone: WorkspaceTone.problem)
                  : WorkspacePill(label: 'Due ${AuraTemporal.dueDay(due)}', tone: WorkspaceTone.waiting),
        ),
      DeskItemType.unknown => (const WorkspaceIcon(Icons.circle_outlined), '', const WorkspacePill(label: 'Open')),
    };

    return WorkspaceRow(
      leading: leading,
      title: item.title.isEmpty ? 'Untitled' : item.title,
      context: context,
      pill: pill,
      selected: selected,
      emphasis: switch (item.urgency) {
        DeskUrgency.overdue => WorkspaceTone.problem,
        DeskUrgency.now => WorkspaceTone.live,
        _ => null,
      },
      onTap: onTap,
    );
  }
}
