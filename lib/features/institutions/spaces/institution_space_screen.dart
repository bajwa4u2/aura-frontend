import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/identity/person_identity_model.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../conversation/presentation/conversation_screen.dart';
import '../data/institutions_repository.dart';
import 'institution_space_context.dart';

/// THE RECONSTRUCTED INSTITUTION SPACE — RC-C7, founder rulings D1–D4
/// (2026-08-20).
///
/// What replaced what:
///
///   BEFORE  `/institution/:id/spaces/:spaceId` rendered `SpaceScreen`, the
///           same widget as `/me/correspondence/:spaceId`, on the legacy
///           Thread/Message runtime. Institution Spaces and personal
///           correspondence were literally the same code, which is why
///           retiring the correspondence family would have deleted this
///           product as collateral damage.
///
///   NOW     the Space owns identity, purpose, membership and access, and the
///           canonical Conversation owns communication. One Space, one
///           Conversation (D2). No Thread. No Space-local message, attachment,
///           media, read-state, call or notification model (§M) — the surface
///           you are reading is a governance shell around
///           `ConversationScreen`, not a second messenger.
///
/// SPACE GOVERNANCE ≠ CONVERSATION GOVERNANCE. Membership decisions are made
/// here and by the Space authority behind it; conversation participation is a
/// projection of those decisions, reconciled server-side by
/// `InstitutionSpaceConversationAuthority`. Nothing on this screen writes a
/// conversation party.
class InstitutionSpaceScreen extends ConsumerStatefulWidget {
  const InstitutionSpaceScreen({
    super.key,
    required this.institutionId,
    required this.spaceId,
  });

  final String institutionId;
  final String spaceId;

  @override
  ConsumerState<InstitutionSpaceScreen> createState() =>
      _InstitutionSpaceScreenState();
}

class _InstitutionSpaceScreenState
    extends ConsumerState<InstitutionSpaceScreen> {
  Future<_SpaceBundle>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Space first, conversation second — and in that order on purpose. The
  /// conversation id is only obtainable through an endpoint that checks Space
  /// access first, so a Space that refuses you never yields one. Fetching the
  /// conversation independently would be a way around Space governance.
  Future<_SpaceBundle> _load() async {
    final repo = ref.read(institutionsRepositoryProvider);
    final space = await repo.getInstitutionSpace(widget.institutionId, widget.spaceId);
    final conversationId = await repo.institutionSpaceConversationId(
      widget.institutionId,
      widget.spaceId,
    );
    return _SpaceBundle(space: space, conversationId: conversationId);
  }

  void _reload() => setState(() => _future = _load());

  void _openMembers(_SpaceBundle bundle) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.card,
      builder: (_) => _MembersSheet(
        institutionId: widget.institutionId,
        spaceId: widget.spaceId,
        space: bundle.space,
        onChanged: _reload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SpaceBundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return AuraScaffold(
            body: const AuraProductState(
              state: ProductState.loading,
              subject: ProductNoun.conversation,
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          return AuraScaffold(
            body: AuraProductState(
              state: ProductState.unavailable,
              subject: ProductNoun.conversation,
              detail:
                  'This space may have been archived, or you may no longer be a member.',
              action: AuraSecondaryButton(
                label: 'Back to spaces',
                onPressed: () =>
                    context.go(NavigationAuthority.institutionSpacesRoute(widget.institutionId)),
              ),
            ),
          );
        }

        final bundle = snap.data!;
        final conversationId = bundle.conversationId;

        // A Space whose conversation could not be resolved is honest about it
        // rather than rendering an empty timeline that looks like silence.
        if (conversationId == null || conversationId.isEmpty) {
          return AuraScaffold(
            body: AuraProductState(
              state: ProductState.unavailable,
              subject: ProductNoun.conversation,
              detail: 'This space has no conversation yet.',
              action: AuraSecondaryButton(
                label: ProductLabels.of(ProductAction.retry),
                onPressed: _reload,
              ),
            ),
          );
        }

        return ConversationScreen(
          conversationId: conversationId,
          spaceContext: InstitutionSpaceContext(
            institutionId: widget.institutionId,
            spaceId: widget.spaceId,
            title: bundle.title,
            purpose: bundle.description,
            memberCount: bundle.members.length,
            canGovern: bundle.canGovern,
            onOpenMembers: () => _openMembers(bundle),
            onBack: () =>
                context.go(NavigationAuthority.institutionSpacesRoute(widget.institutionId)),
          ),
        );
      },
    );
  }
}

class _SpaceBundle {
  _SpaceBundle({required this.space, required this.conversationId});

  final Map<String, dynamic> space;
  final String? conversationId;

  String get title {
    final t = (space['title'] ?? '').toString().trim();
    return t.isEmpty ? 'Space' : t;
  }

  String? get description {
    final d = (space['description'] ?? '').toString().trim();
    return d.isEmpty ? null : d;
  }

  List<Map<String, dynamic>> get members {
    final raw = space['members'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList(growable: false);
  }

  /// Whether this viewer may govern membership.
  ///
  /// A CAPABILITY question, never a role comparison. An earlier draft read
  /// `role == 'OWNER' || role == 'ADMIN'` and the C1 anti-drift ratchet caught
  /// it, correctly: role-as-permission is the defect that chapter exists to
  /// prevent, and a client that re-derives authority from a role string will
  /// eventually disagree with the server that actually decides. The server
  /// answers this; absence means no, and the write is refused there regardless
  /// of what this returns.
  bool get canGovern => space['viewerCanManage'] == true;
}

/// MEMBERSHIP — the Space's own governance, rendered honestly.
///
/// The frozen Institution Space Membership Doctrine distinguishes two
/// capabilities that must never be renamed into each other: ADD MEMBER grants
/// membership immediately to someone already governed by the owning
/// institution, and INVITE PERSON runs the invitation lifecycle for everyone
/// else. This sheet performs the first and says so; it never labels an
/// invitation as an add.
class _MembersSheet extends ConsumerStatefulWidget {
  const _MembersSheet({
    required this.institutionId,
    required this.spaceId,
    required this.space,
    required this.onChanged,
  });

  final String institutionId;
  final String spaceId;
  final Map<String, dynamic> space;
  final VoidCallback onChanged;

  @override
  ConsumerState<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends ConsumerState<_MembersSheet> {
  late List<Map<String, dynamic>> _members;
  String? _busyUserId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _members = _readMembers(widget.space);
  }

  static List<Map<String, dynamic>> _readMembers(Map<String, dynamic> space) {
    final raw = space['members'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Future<void> _remove(String userId) async {
    setState(() {
      _busyUserId = userId;
      _error = null;
    });
    try {
      final space = await ref
          .read(institutionsRepositoryProvider)
          .removeInstitutionSpaceMember(
            widget.institutionId,
            widget.spaceId,
            userId,
          );
      if (!mounted) return;
      setState(() => _members = _readMembers(space));
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      // The server owns the refusal — a sole owner, a non-member, an
      // unauthorised actor. Show what it said rather than guessing.
      setState(() => _error = _readableError(e));
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  static String _readableError(Object e) {
    final text = e.toString();
    final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(text);
    return match?.group(1) ?? 'That could not be completed.';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Members',
                    style: AuraText.title.copyWith(color: AuraSurface.ink)),
                const Spacer(),
                Text('${_members.length}',
                    style: AuraText.small.copyWith(color: AuraSurface.muted)),
              ],
            ),
            const SizedBox(height: AuraSpace.s4),
            Text(
              'Membership is governed by the space. Removing someone here '
              'never changes their institution membership.',
              style: AuraText.micro.copyWith(color: AuraSurface.muted),
            ),
            if (_error != null) ...[
              const SizedBox(height: AuraSpace.s10),
              Text(_error!,
                  style: AuraText.small.copyWith(color: AuraSurface.dangerInk)),
            ],
            const SizedBox(height: AuraSpace.s12),
            Flexible(
              child: _members.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AuraSpace.s16),
                      child: Text('No members yet.',
                          style: AuraText.small
                              .copyWith(color: AuraSurface.muted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _members.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AuraSpace.s6),
                      itemBuilder: (_, i) {
                        final member = _members[i];
                        // Person identity through the one canonical reader —
                        // a space roster does not get its own name order.
                        final person = AuraPersonIdentity.fromJson(member);
                        final role =
                            (member['role'] ?? '').toString().toUpperCase();
                        final userId = person.userId;
                        final busy = _busyUserId == userId;
                        return Row(
                          children: [
                            AuraAvatar(
                              name: person.label,
                              imageUrl: person.avatarUrl,
                              size: 34,
                            ),
                            const SizedBox(width: AuraSpace.s10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(person.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AuraText.body.copyWith(
                                          color: AuraSurface.ink)),
                                  if (role.isNotEmpty)
                                    Text(_roleLabel(role),
                                        style: AuraText.micro.copyWith(
                                            color: AuraSurface.muted)),
                                ],
                              ),
                            ),
                            if (userId.isNotEmpty)
                              busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : IconButton(
                                      tooltip: 'Remove from space',
                                      icon: const Icon(
                                          Icons.person_remove_outlined),
                                      onPressed: () => _remove(userId),
                                    ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(String role) {
    if (role.isEmpty) return '';
    return role[0] + role.substring(1).toLowerCase();
  }
}
