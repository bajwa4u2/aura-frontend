import '../../../core/errors/server_refusal.dart';
import '../../../core/trust/trust_marks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/authority/authority_providers.dart';
import '../../../core/authority/capability_projection.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institution_pending_counts.dart';
import '../data/institutions_repository.dart';
import '../../updates/providers.dart';
import '../workspace/workspace_page.dart';
import 'institution_invites_screen.dart';
import 'institution_join_requests_screen.dart';
import '../../../core/identity/person_identity_model.dart';

/// MEMBERS (DD-43, 2026-10-09): one Collection page with three tabs.
///
/// Members, Join requests and Invites were three pages, each its own world.
/// They are now tabs of one page on the workspace frame: the roster, the
/// people asking to join, and the invites sent. Join requests and Invites
/// show only to people who may act on them. The one gold action is Invite.
class InstitutionMembersScreen extends ConsumerStatefulWidget {
  const InstitutionMembersScreen({super.key, required this.institutionId, this.initialTab});

  final String institutionId;

  /// 'members' (default), 'requests' or 'invites'. The old Join requests and
  /// Invites routes open this page on their tab.
  final String? initialTab;

  @override
  ConsumerState<InstitutionMembersScreen> createState() => _InstitutionMembersScreenState();
}

class _InstitutionMembersScreenState extends ConsumerState<InstitutionMembersScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _members = const [];
  String _callerRole = '';
  String? _removing;
  String? _removeError;
  String? _updating;
  String? _updateError;
  bool _attentionMarked = false;

  // A tab from a link (`?tab=`) is honoured only if it is one of ours.
  late String _tab = const {'members', 'requests', 'invites'}.contains(widget.initialTab) ? widget.initialTab! : 'members';

  /// The invite form, opened by the gold Invite action from any tab.
  bool _showCreate = false;

  InstitutionsRepository get _repo => ref.read(institutionsRepositoryProvider);

  /// PLATFORM_ADMIN is what listMembers returns when the caller is a platform
  /// admin — the service short-circuits on that check before it ever reads
  /// their institution membership role, and updateMemberRole/removeMember both
  /// honour the same bypass. This is SERVER truth about which authority
  /// applied, not a client role label, so it is consumed as reported.
  ///
  /// It is a genuinely different axis from institutional capability: platform
  /// administration is accountable oversight of the platform, not standing
  /// inside this institution.
  bool get _platformAdminBypass => _callerRole.toUpperCase() == 'PLATFORM_ADMIN';

  bool _may(ConsequentialAct act) =>
      ref.watch(capabilityProjectionForProvider(widget.institutionId)).presentationFor(act) ==
      ControlPresentation.available;

  /// MAY THIS VIEWER MANAGE MEMBERSHIP?
  ///
  /// The role labels this replaced were approximating MANAGE_MEMBERS, which
  /// the backend actually enforces and an OWNER may delegate to someone who is
  /// not an admin at all. Seeing the roster is baseline participation; acting
  /// on it is this.
  bool get _canManageMembers => _platformAdminBypass || _may(ConsequentialAct.manageMembers);

  /// Join requests: whoever may answer them (MANAGE_JOIN_REQUESTS, which
  /// owners and admins hold by role), asked as a capability, never a role.
  bool get _canSeeRequests => _platformAdminBypass || _may(ConsequentialAct.manageJoinRequests);

  /// Invites: whoever may send them; the Invite action followed the roster's
  /// management rule before, and still does.
  bool get _canInvite => _canManageMembers || _may(ConsequentialAct.manageInvitations);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_attentionMarked) return;
    _attentionMarked = true;
    Future.microtask(() {
      ref
          .read(notificationsControllerProvider.notifier)
          .markReadForTarget(
            institutionId: widget.institutionId,
            types: const ['FOLLOW', 'ROLE_CHANGED', 'CAPABILITY_GRANTED', 'CAPABILITY_REVOKED'],
          );
    });
  }

  /// MAY THIS VIEWER CHANGE ROLES?
  ///
  /// DELIBERATELY STILL ROLE AUTHORITY. Appointing and removing ADMINs is
  /// governance-exclusive: canonical doctrine keeps it OUT of the capability
  /// model precisely so it can never be delegated away. Converting this to a
  /// capability check would quietly make an ungovernable act delegable.
  ///
  /// So it asks the canonical authority for a GOVERNANCE act
  /// (`ActingRequirement.governance(InstitutionRole.owner)`) rather than
  /// comparing a role string here.
  bool get _canGovernRoles => _platformAdminBypass || _may(ConsequentialAct.appointAdmin);

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Staff seats in use and the plan's limit (null = no limit), as the server
  /// counts them (2026-10-09). Shown to people who manage members.
  int? _seatsUsed;
  int? _seatsLimit;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _repo.listMembers(widget.institutionId);
      final rawMembers = data['members'];
      final members = rawMembers is List
          ? rawMembers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _members = members;
        _callerRole = (data['callerRole'] ?? '').toString().trim();
        final seats = data['seats'];
        _seatsUsed = seats is Map ? (seats['used'] as num?)?.toInt() : null;
        _seatsLimit = seats is Map ? (seats['limit'] as num?)?.toInt() : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _message(e, 'Could not load members.');
        _loading = false;
      });
    }
  }

  Future<void> _remove(String userId) async {
    if (_removing != null) return;
    setState(() {
      _removing = userId;
      _removeError = null;
    });

    try {
      await _repo.removeMember(widget.institutionId, userId);
      await _load();
    } catch (e) {
      setState(() {
        _removeError = _message(e, 'Could not remove member.');
        _removing = null;
      });
    }
  }

  Future<void> _changeRole(String userId, String newRole) async {
    if (_updating != null) return;
    setState(() {
      _updating = userId;
      _updateError = null;
    });

    try {
      await _repo.updateMemberRole(widget.institutionId, userId, newRole);
      await _load();
    } catch (e) {
      setState(() {
        _updateError = _message(e, 'Could not update role.');
        _updating = null;
      });
    }
  }

  String _message(Object error, String fallback) => institutionMembersErrorMessage(error, fallback);

  String _roleBadge(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Owner';
      case 'ADMIN':
        return 'Admin';
      case 'EDITOR':
        return 'Editor';
      default:
        return 'Member';
    }
  }

  Widget _buildMemberRow(Map<String, dynamic> member) {
    final user = member['user'] is Map ? Map<String, dynamic>.from(member['user'] as Map) : <String, dynamic>{};
    final memberId = member['userId']?.toString() ?? '';
    // F053/F116 — the person half; `role` and `capabilities` below are
    // membership state and stay local.
    final person = AuraPersonIdentity.fromJson(user);
    final displayName = person.displayName;
    final handle = person.handle;
    final role = member['role']?.toString().trim() ?? 'MEMBER';
    final caps = <String>{
      if (member['capabilities'] is List)
        ...(member['capabilities'] as List).map((e) => e.toString().trim().toUpperCase()),
    };
    final isRepresentative = caps.contains('OFFICIAL_REPRESENTATION');
    final isHost = caps.contains('HOST_MEETINGS');
    // Seat holding comes from the server's own rule (owners, admins and
    // official voices); the app never re-derives it.
    final holdsSeat = member['holdsSeat'] == true;
    // An official voice may come from the delegated capability, from
    // publishing officially, or from the older "speaks officially" flag; the
    // seat rule counts all three, so the pill names all three (2026-10-09:
    // a member held a seat while the roster called him only "Member").
    final speaksOfficially =
        isRepresentative ||
        caps.contains('PUBLISH_OFFICIAL') ||
        (member['canSpeakOfficially'] == true && !const {'OWNER', 'ADMIN'}.contains(role.toUpperCase()));
    final isBusy = _removing == memberId || _updating == memberId;

    final nameOrHandle = displayName.isNotEmpty ? displayName : (handle.isNotEmpty ? '@$handle' : 'Unknown');
    final ownerRow = role.toUpperCase() == 'OWNER';

    // One pill per row (the frame's rule): the institution's voice first,
    // because responsibility is visible to everyone; otherwise ownership.
    // Everything else is said in the context line.
    final WorkspacePill? pill = speaksOfficially
        ? const WorkspacePill(label: 'Official voice', tone: WorkspaceTone.waiting)
        : ownerRow
        ? const WorkspacePill(label: 'Owner', tone: WorkspaceTone.done)
        : null;
    final contextLine = [
      if (handle.isNotEmpty) '@$handle',
      // The role is named here unless the pill already names it.
      if (!(ownerRow && pill?.label == 'Owner')) _roleBadge(role),
      if (isHost) 'Meeting host',
      // A seat is a plan matter: shown to those who manage members.
      if (holdsSeat && _canManageMembers) 'Staff seat',
      // Lifecycle truth, only when it is not the ordinary case: a roster
      // should say plainly that someone's account is no longer active.
      if ((person.accountStatus ?? 'ACTIVE') != 'ACTIVE')
        person.accountStatus == 'DELETED' ? 'Account deleted' : 'Account disabled',
    ].join(' · ');

    return WorkspaceRow(
      // THE PERSON'S OWN FACE, NOT AN INITIAL STANDING IN FOR IT.
      leading: AuraAvatar(name: nameOrHandle, imageUrl: person.avatarUrl, size: 36),
      title: nameOrHandle,
      context: contextLine,
      pill: pill,
      // TRUST IS PART OF WHO SOMEONE IS: rendered through the canonical
      // presentation, so a person cannot be verified here and unverified there.
      trailing: personTrailing(
        person,
        !_canManageThisMember(role)
            ? null
            : isBusy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : _memberMenu(
                memberId: memberId,
                name: nameOrHandle,
                role: role,
                isRepresentative: isRepresentative,
                isHost: isHost,
              ),
      ),
    );
  }

  Widget _memberMenu({
    required String memberId,
    required String name,
    required String role,
    required bool isRepresentative,
    required bool isHost,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: AuraSurface.muted),
      tooltip: 'Member options',
      color: AuraSurface.overlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AuraSurface.divider),
      ),
      itemBuilder: (_) => [
        // GOVERNANCE: appointing/removing admins and transferring
        // ownership are OWNER-exclusive; delegating Representative
        // and Host is available to admins.
        if (_canGovernRoles && role.toUpperCase() == 'MEMBER')
          PopupMenuItem(
            value: 'PROMOTE',
            child: Text('Promote to Admin', style: AuraText.small.copyWith(color: AuraSurface.ink)),
          ),
        if (_canGovernRoles && role.toUpperCase() == 'ADMIN')
          PopupMenuItem(
            value: 'DEMOTE',
            child: Text('Demote to Member', style: AuraText.small.copyWith(color: AuraSurface.ink)),
          ),
        if (_canGovernRoles && role.toUpperCase() != 'OWNER')
          PopupMenuItem(
            value: 'TRANSFER',
            child: Text('Transfer ownership…', style: AuraText.small.copyWith(color: AuraSurface.ink)),
          ),
        if (role.toUpperCase() == 'MEMBER')
          PopupMenuItem(
            value: isRepresentative ? 'REVOKE_REP' : 'GRANT_REP',
            child: Text(
              isRepresentative ? 'Remove as official voice' : 'Make official voice',
              style: AuraText.small.copyWith(color: AuraSurface.ink),
            ),
          ),
        if (role.toUpperCase() == 'MEMBER')
          PopupMenuItem(
            value: isHost ? 'REVOKE_HOST' : 'GRANT_HOST',
            child: Text(
              isHost ? 'Remove as meeting host' : 'Make meeting host',
              style: AuraText.small.copyWith(color: AuraSurface.ink),
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'REMOVE',
          child: Text('Remove', style: AuraText.small.copyWith(color: AuraSurface.dangerInk)),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'REMOVE':
            _confirmRemove(memberId, name);
          case 'PROMOTE':
            _changeRole(memberId, 'ADMIN');
          case 'DEMOTE':
            _changeRole(memberId, 'MEMBER');
          case 'TRANSFER':
            _confirmTransfer(memberId, name);
          case 'GRANT_REP':
            _changeCapability(memberId, 'OFFICIAL_REPRESENTATION', true);
          case 'REVOKE_REP':
            _changeCapability(memberId, 'OFFICIAL_REPRESENTATION', false);
          case 'GRANT_HOST':
            _changeCapability(memberId, 'HOST_MEETINGS', true);
          case 'REVOKE_HOST':
            _changeCapability(memberId, 'HOST_MEETINGS', false);
        }
      },
    );
  }

  /// Only owners may act on the admin tier; owners/admins may act on members.
  bool _canManageThisMember(String role) {
    final r = role.toUpperCase();
    if (r == 'OWNER') return false;
    if (r == 'ADMIN') return _canGovernRoles;
    return _canManageMembers;
  }

  Future<void> _changeCapability(String userId, String capability, bool grant) async {
    if (_updating != null) return;
    setState(() {
      _updating = userId;
      _updateError = null;
    });
    try {
      if (grant) {
        await _repo.grantCapability(widget.institutionId, userId, capability);
      } else {
        await _repo.revokeCapability(widget.institutionId, userId, capability);
      }
      await _load();
    } catch (e) {
      setState(() {
        _updateError = _message(e, 'Could not update capability.');
        _updating = null;
      });
    }
  }

  Future<void> _confirmTransfer(String userId, String name) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AuraRadius.card)),
        title: const Text('Transfer ownership', style: AuraText.subtitle),
        content: Text(
          'Make $name the owner of this institution? You will become an admin. '
          'This is irreversible without the new owner transferring it back.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AuraText.small.copyWith(color: AuraSurface.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Transfer',
              style: AuraText.small.copyWith(color: AuraSurface.coVerdant, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _updating = userId;
      _updateError = null;
    });
    try {
      await _repo.transferOwnership(widget.institutionId, userId);
      await _load();
    } catch (e) {
      setState(() {
        _updateError = _message(e, 'Could not transfer ownership.');
        _updating = null;
      });
    }
  }

  Future<void> _confirmRemove(String userId, String name) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AuraRadius.card)),
        title: const Text('Remove member', style: AuraText.subtitle),
        content: Text(
          'Remove $name from this institution? This cannot be undone.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AuraText.small.copyWith(color: AuraSurface.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: AuraText.small.copyWith(color: AuraSurface.coRose, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _remove(userId);
  }

  List<Widget> _membersTab() {
    if (_error != null) {
      return [
        WorkspaceEmpty(
          icon: Icons.error_outline_rounded,
          title: 'Could not load members',
          body: _error!,
          action: WorkspaceAction(
            label: ProductLabels.of(ProductAction.retry),
            icon: Icons.refresh_rounded,
            onPressed: _load,
          ),
        ),
      ];
    }
    return [
      for (final err in [_removeError, _updateError].whereType<String>())
        WorkspaceNotice(
          message: err,
          onDismiss: () => setState(() {
            _removeError = null;
            _updateError = null;
          }),
        ),
      if (_members.isEmpty)
        WorkspaceEmpty(
          icon: Icons.people_outline_rounded,
          title: 'No members yet',
          body: 'Invite colleagues with Invite.',
          action: _canInvite ? _inviteAction(label: 'Invite') : null,
        )
      else
        ..._members.map(_buildMemberRow),
    ];
  }

  WorkspaceAction _inviteAction({String label = 'Invite'}) => WorkspaceAction(
    label: label,
    icon: Icons.person_add_alt_1_rounded,
    onPressed: () => setState(() {
      _tab = 'invites';
      _showCreate = true;
    }),
  );

  @override
  Widget build(BuildContext context) {
    final showRequests = _canSeeRequests;
    final showInvites = _canInvite;
    final tab = (_tab == 'requests' && !showRequests) || (_tab == 'invites' && !showInvites) ? 'members' : _tab;
    final pending = (showRequests || showInvites)
        ? ref.watch(institutionPendingCountsProvider(widget.institutionId)).valueOrNull
        : null;

    final seatLine = _canManageMembers && _seatsUsed != null
        ? (_seatsLimit == null
              ? '$_seatsUsed staff seat${_seatsUsed == 1 ? '' : 's'} in use'
              : '$_seatsUsed of $_seatsLimit staff seats in use')
        : null;

    final List<Widget> children = switch (tab) {
      'requests' => [InstitutionJoinRequestsPanel(institutionId: widget.institutionId)],
      'invites' => [
        InstitutionInvitesPanel(
          institutionId: widget.institutionId,
          showCreate: _showCreate,
          onCloseCreate: () => setState(() => _showCreate = false),
          onInvite: _inviteAction().onPressed,
        ),
      ],
      _ => _membersTab(),
    };

    return WorkspacePage(
      type: WorkspacePageType.collection,
      title: 'Members',
      // Subtitle is shown to every member who can see this screen, not
      // just operators: the plain product terms (people who belong, what
      // they can do), then the seat count for those who manage members.
      purpose: [
        'People who belong to this institution and what each of them may do.',
        if (seatLine != null) seatLine,
      ].join(' · '),
      primary: showInvites && !(tab == 'invites' && _showCreate) ? _inviteAction() : null,
      tabs: [
        WorkspaceTab(id: 'members', label: 'Members', count: _loading ? null : _members.length),
        if (showRequests) WorkspaceTab(id: 'requests', label: 'Join requests', count: pending?.joinRequests),
        // No number: the tab lists every invite, used and expired too, and a
        // pending-only count beside them read as "0 invites" (live, 9 Oct).
        if (showInvites) const WorkspaceTab(id: 'invites', label: 'Invites'),
      ],
      selectedTab: tab,
      onTab: (id) => setState(() => _tab = id),
      loading: tab == 'members' && _loading,
      children: children,
    );
  }
}

/// The person's verification, in its canonical presentation, followed by
/// whatever the row offers (a menu, Approve/Reject). The frame's row holds
/// the name as text, so the mark sits at the row's end, beside the actions.
Widget? personTrailing(AuraPersonIdentity person, Widget? rest) {
  if (!person.verification.hasAny) return rest;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PersonVerificationMarks(verification: person.verification, size: TrustMarkSize.micro),
      if (rest != null) ...[const SizedBox(width: AuraSpace.s8), rest],
    ],
  );
}

/// A refusal or failure from an action on this page, in the list's own
/// place, dismissible. (Not in the frame: the frame has no inline notice.)
class WorkspaceNotice extends StatelessWidget {
  const WorkspaceNotice({super.key, required this.message, this.onDismiss, this.tone = WorkspaceTone.problem});

  final String message;
  final VoidCallback? onDismiss;
  final WorkspaceTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = WorkspacePill.colors(tone);
    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s12),
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14, vertical: AuraSpace.s12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ink.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone == WorkspaceTone.done ? Icons.check_circle_outline : Icons.error_outline, size: 16, color: ink),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(message, style: AuraText.small.copyWith(color: ink)),
          ),
          if (onDismiss != null)
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(8),
              child: Icon(Icons.close, size: 16, color: ink),
            ),
        ],
      ),
    );
  }
}

/// The server's own sentence for a refused member change, else [fallback].
///
/// Reads the `{ok:false, error:{code, message}}` envelope as well as a flat
/// `message`: it used to read only the flat one, so a refusal such as
/// SEAT_LIMIT_REACHED, whose sentence says how many staff seats the plan
/// holds, reached the owner as "Could not update role."
@visibleForTesting
String institutionMembersErrorMessage(Object error, String fallback) => ServerRefusal.of(error).message ?? fallback;
