import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_paths.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institution_pending_counts.dart';
import '../ui/institution_ds.dart';

/// Phase 6.6a — Institution Overview / Command Center.
///
/// This is the surface a member or admin lands on after entering the
/// institution workspace. It is composed entirely of `Ins…` design-system
/// primitives so subsequent surfaces (Edit, Profile, Public Preview) inherit
/// the same vocabulary.
///
/// Layout:
///   1. Identity header — avatar, name, slug, badge cluster, fact row.
///   2. Standing — four status cards (Standing, Role, Official Speech,
///      Domain Trust). Strict 1-line helpers, tone-driven pills.
///   3. Next actions — actionable cards filtered by membership state.
///   4. Light activity — calm meta facts (no embedded feed).
///
/// Data still comes from `/institutions/me`; nothing else changed about the
/// load contract or the underlying state machine.
class InstitutionDashboardScreen extends ConsumerStatefulWidget {
  const InstitutionDashboardScreen({super.key});

  @override
  ConsumerState<InstitutionDashboardScreen> createState() =>
      _InstitutionDashboardScreenState();
}

class _InstitutionDashboardScreenState
    extends ConsumerState<InstitutionDashboardScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _membership;
  Map<String, dynamic>? _institution;
  String _state = 'SIGNED_IN_NO_STANDING';

  Dio get _dio => ref.read(dioProvider);

  bool get _hasInstitution =>
      _institution != null &&
      ((_institution!['id']?.toString().trim().isNotEmpty) ?? false);

  bool get _canUseInstitutionTools =>
      _state == 'VERIFIED_MEMBER' || _state == 'AUTHORIZED_SPEAKER';

  /// GOVERNANCE V1: effective capability set from /institutions/me.
  Set<String> get _capabilities => <String>{
        if (_membership?['capabilities'] is List)
          ...(_membership!['capabilities'] as List)
              .map((e) => e.toString().trim().toUpperCase()),
      };

  bool _can(String capability) => _capabilities.contains(capability);

  // Domains are owner-held — the dashboard shortcut is only shown when the
  // acting member actually holds MANAGE_DOMAINS.
  bool get _canManageDomains =>
      _canUseInstitutionTools && (_can('MANAGE_DOMAINS') || _isInstitutionAccount);

  bool get _isInstitutionAccount => _state == 'AUTHORIZED_SPEAKER' &&
      (_membership?['role']?.toString().trim().isEmpty ?? true);

  bool get _isAdmin {
    final r = _membership?['role']?.toString().trim().toUpperCase() ?? '';
    return r == 'ADMIN' || r == 'OWNER';
  }

  bool get _canSpeakOfficially =>
      _membership?['canSpeakOfficially'] == true ||
      _state == 'AUTHORIZED_SPEAKER';

  bool get _canPublishAnnouncements =>
      _isAdmin || _state == 'AUTHORIZED_SPEAKER';

  bool get _isPending => _state == 'PENDING_REQUEST';
  bool get _isRejected => _state == 'REJECTED';
  bool get _isSuspended => _state == 'SUSPENDED';

  bool get _domainVerified {
    final verifiedAt =
        _institution?['domainVerifiedAt']?.toString().trim() ?? '';
    return verifiedAt.isNotEmpty;
  }

  String get _institutionId =>
      _institution?['id']?.toString().trim() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data loading ────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _dio.get('/institutions/me');
      final data = _map(res.data);

      final membership = _mapOrNull(data['membership']);
      final institution = _mapOrNull(membership?['institution']) ??
          _mapOrNull(data['institution']);
      final state = (data['state']?.toString().trim().isNotEmpty ?? false)
          ? data['state'].toString().trim()
          : 'SIGNED_IN_NO_STANDING';

      setState(() {
        _membership = membership;
        _institution = institution;
        _state = state;
        _loading = false;
      });

      // Refresh the Action Queue counts whenever the overview reloads so a
      // pull-to-refresh updates pending join requests / invites too.
      final id = institution?['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) {
        ref.invalidate(institutionPendingCountsProvider(id));
      }
    } catch (e) {
      setState(() {
        _error = _dioMessage(e, 'Could not load institution dashboard.');
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Map<String, dynamic>? _mapOrNull(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  String _dioMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final msg = data['message'].toString().trim();
        if (msg.isNotEmpty) return msg;
      }
      if (data is Map && data['error'] is Map) {
        final inner = data['error'];
        if (inner is Map && inner['message'] != null) {
          final msg = inner['message'].toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }
    return fallback;
  }

  void _go(String route) {
    if (!mounted) return;
    context.go(route);
  }

  String _str(Map<String, dynamic>? m, List<String> keys) {
    if (m == null) return '';
    for (final k in keys) {
      final v = m[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  // ── Identity / display helpers ─────────────────────────────────────────

  String get _domain => _str(_institution, ['domain']);

  // ── Status mapping ──────────────────────────────────────────────────────

  ({String value, InsTone tone, String helper}) get _standing {
    if (_canUseInstitutionTools) {
      return (
        value: 'Active',
        tone: InsTone.ok,
        helper: 'Institutional standing is active and verified.',
      );
    }
    if (_isPending) {
      return (
        value: 'Under review',
        tone: InsTone.warn,
        helper: 'Account request is being reviewed by the Aura team.',
      );
    }
    if (_isSuspended) {
      return (
        value: 'Suspended',
        tone: InsTone.danger,
        helper: 'Institutional actions are paused until standing is restored.',
      );
    }
    if (_isRejected) {
      return (
        value: 'Rejected',
        tone: InsTone.danger,
        helper: 'The previous request was declined. A fresh request can be submitted.',
      );
    }
    return (
      value: 'Not started',
      tone: InsTone.neutral,
      helper: 'Submit an institutional account request to begin.',
    );
  }

  ({String value, InsTone tone, String helper, IconData icon}) get _role {
    final r = _membership?['role']?.toString().trim().toUpperCase() ?? '';
    if (r.isEmpty) {
      return (
        value: 'No role',
        tone: InsTone.neutral,
        icon: Icons.person_outline_rounded,
        helper: 'You do not have a role in an institution yet.',
      );
    }
    final pretty = switch (r) {
      'OWNER' => 'Founder',
      'ADMIN' => 'Admin',
      'EDITOR' => 'Editor',
      'MEMBER' => 'Member',
      _ => r,
    };
    final tone = (r == 'OWNER' || r == 'ADMIN') ? InsTone.info : InsTone.ok;
    return (
      value: pretty,
      tone: tone,
      icon: r == 'OWNER'
          ? Icons.workspace_premium_rounded
          : (r == 'ADMIN'
              ? Icons.shield_outlined
              : (r == 'EDITOR'
                  ? Icons.edit_note_rounded
                  : Icons.person_outline_rounded)),
      helper: switch (r) {
        'OWNER' => 'Full control over institution identity and access.',
        'ADMIN' => 'Manage members, domains, and institutional surfaces.',
        'EDITOR' => 'Publish posts and announcements on behalf of the institution.',
        'MEMBER' => 'Verified member of this institution workspace.',
        _ => 'Membership role inside this institution.',
      },
    );
  }

  ({String value, InsTone tone, String helper}) get _officialSpeech {
    if (_canSpeakOfficially) {
      return (
        value: 'Active',
        tone: InsTone.ok,
        helper: 'You can post in the institution voice on behalf of this organisation.',
      );
    }
    return (
      value: 'Not authorized',
      tone: InsTone.neutral,
      helper: 'Posts appear under your personal identity.',
    );
  }

  ({String value, InsTone tone, String helper}) get _domainTrust {
    if (_domainVerified) {
      final d = _domain;
      return (
        value: 'Verified',
        tone: InsTone.ok,
        helper: d.isEmpty
            ? 'Domain ownership is confirmed.'
            : 'Verified · $d',
      );
    }
    if (_domain.isNotEmpty) {
      return (
        value: 'Pending',
        tone: InsTone.warn,
        helper: 'Add the DNS record on $_domain to complete verification.',
      );
    }
    return (
      value: 'Not configured',
      tone: InsTone.neutral,
      helper: 'Optional. Adds an extra layer of institutional trust.',
    );
  }


  // ── Next actions ────────────────────────────────────────────────────────

  List<Widget> _buildNextActions() {
    final items = <Widget>[];

    // Pre-onboarding states.
    if (!_hasInstitution && !_isPending) {
      items.add(InsActionCard(
        icon: Icons.rocket_launch_outlined,
        title: _isRejected
            ? 'Submit a fresh request'
            : 'Create institutional account',
        body:
            'Establish institutional standing inside Aura by submitting a verification request.',
        cta: 'Get started',
        tone: InsTone.info,
        onTap: () => _go('/institutions/get-started'),
      ));
      return items;
    }

    if (_isPending) {
      items.add(const InsActionCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Under review',
        body:
            'Your request is with the Aura team. Nothing to do — we will notify you once a decision is made.',
        tone: InsTone.warn,
        disabledHint: 'Awaiting review',
      ));
      return items;
    }

    if (_isSuspended) {
      items.add(const InsActionCard(
        icon: Icons.pause_circle_outline_rounded,
        title: 'Standing suspended',
        body:
            'Institutional actions are paused. Contact support if you believe this is an error.',
        tone: InsTone.danger,
        disabledHint: 'Restricted',
      ));
      return items;
    }

    // Active workspace — show the smallest, most relevant set of actions.

    if (!_domainVerified && _canManageDomains) {
      items.add(InsActionCard(
        icon: Icons.dns_outlined,
        title: _domain.isEmpty ? 'Add a domain' : 'Verify domain',
        body: _domain.isEmpty
            ? 'Attach an institutional domain — it adds a strong trust signal on every post.'
            : 'Confirm DNS ownership of $_domain to finish domain trust.',
        cta: 'Open domains',
        tone: InsTone.info,
        onTap: () => _go(_institutionId.isNotEmpty
            ? institutionWorkspacePath(
                _institutionId, InstitutionSection.domains)
            : '/institution/dashboard'),
      ));
    }

    if (_isAdmin && _institutionId.isNotEmpty) {
      items.add(InsActionCard(
        icon: Icons.group_add_outlined,
        title: 'Invite members',
        body:
            'Bring colleagues into the workspace with single-use invite codes.',
        cta: 'Open invites',
        tone: InsTone.info,
        onTap: () => _go('/institution/$_institutionId/invites'),
      ));
    }

    // Pending join requests are now surfaced by the Action Queue ("Needs your
    // attention") at the top of the overview, so they are intentionally not
    // duplicated in this evergreen-suggestions list.

    if (_canPublishAnnouncements && _institutionId.isNotEmpty) {
      items.add(InsActionCard(
        icon: Icons.campaign_outlined,
        title: 'Publish an announcement',
        body:
            'Post in the institution voice to members and the public.',
        cta: 'Compose',
        tone: InsTone.info,
        onTap: () => _go('/institution/$_institutionId/announcements'),
      ));
    }

    if (_isAdmin && _institutionId.isNotEmpty) {
      items.add(InsActionCard(
        icon: Icons.inbox_outlined,
        title: 'Public Engagement',
        body:
            'View public records routed to your institution and manage your participation declarations.',
        cta: 'Open workspace',
        tone: InsTone.info,
        onTap: () => _go('/institution/$_institutionId/public-engagement'),
      ));
    }

    if (items.isEmpty) {
      // Fully set up — nothing actionable. Surface a calm "all clear" tile
      // so the section never sits empty on a healthy workspace.
      items.add(const InsActionCard(
        icon: Icons.check_circle_rounded,
        title: 'Workspace is fully set up',
        body:
            'Identity, domain, and roles are in place. Nothing to do here right now.',
        tone: InsTone.ok,
        disabledHint: 'All clear',
      ));
    }

    return items;
  }

  // ── Light activity ──────────────────────────────────────────────────────

  Widget _buildActivity() {
    final memberCount = _institution?['memberCount'];
    final lastActivity = _str(_institution, [
      'lastActivityAt',
      'updatedAt',
      'lastPostAt',
    ]);
    final foundedAt = _str(_institution, [
      'foundedAt',
      'createdAt',
      'establishedAt',
    ]);
    final postCount = _institution?['postCount'];

    final tiles = <Widget>[];

    if (memberCount is num) {
      tiles.add(_ActivityTile(
        icon: Icons.people_outline_rounded,
        label: 'Members',
        value: memberCount.toInt().toString(),
      ));
    }

    if (postCount is num) {
      tiles.add(_ActivityTile(
        icon: Icons.article_outlined,
        label: 'Public posts',
        value: postCount.toInt().toString(),
      ));
    }

    if (lastActivity.isNotEmpty) {
      tiles.add(_ActivityTile(
        icon: Icons.bolt_outlined,
        label: 'Last activity',
        value: _formatDate(lastActivity),
      ));
    }

    if (foundedAt.isNotEmpty) {
      tiles.add(_ActivityTile(
        icon: Icons.event_available_outlined,
        label: 'On Aura since',
        value: _formatDate(foundedAt),
      ));
    }

    if (tiles.isEmpty) {
      // No backend metrics yet — keep section honest, not chatty.
      return const InsCard(
        child: Row(
          children: [
            Icon(
              Icons.insights_outlined,
              size: 16,
              color: AuraSurface.faint,
            ),
            SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Text(
                'Activity insights will appear here once the workspace has data.',
                style: AuraText.small,
              ),
            ),
          ],
        ),
      );
    }

    return InsResponsiveGrid(
      maxCols: 4,
      minColWidth: 200,
      children: tiles,
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  // ── Action queue ("Needs your attention") ────────────────────────────────
  //
  // The single place an operator can see, at a glance, what requires a decision
  // right now. Admin/owner only — the underlying endpoints are admin-gated and
  // degrade to zero for everyone else. Returns null when there is nothing to
  // show the surface for (non-admin, no active workspace).

  Widget? _buildActionQueue() {
    if (!_isAdmin || !_canUseInstitutionTools || _institutionId.isEmpty) {
      return null;
    }

    final countsAsync = ref.watch(
      institutionPendingCountsProvider(_institutionId),
    );

    return InsSection(
      eyebrow: 'Attention',
      title: 'Needs your attention',
      child: countsAsync.when(
        loading: () => const InsCard(
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: AuraSpace.s10),
              Text('Checking for pending items…', style: AuraText.small),
            ],
          ),
        ),
        // Degrade quietly — a transient counts failure must never block the
        // overview or imply a problem that isn't there.
        error: (_, __) => const SizedBox.shrink(),
        data: (counts) {
          if (!counts.hasAny) {
            return const InsCard(
              tone: InsTone.ok,
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AuraSurface.coVerdant,
                  ),
                  SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Text(
                      "You're all caught up — no requests or invites need "
                      'action right now.',
                      style: AuraText.small,
                    ),
                  ),
                ],
              ),
            );
          }

          final cards = <Widget>[];
          if (counts.joinRequests > 0) {
            cards.add(InsActionCard(
              icon: Icons.person_add_outlined,
              title: 'Review join requests',
              body: '${counts.joinRequests} '
                  '${counts.joinRequests == 1 ? 'person is' : 'people are'} '
                  'waiting to be approved into the workspace.',
              cta: 'Review',
              badge: counts.joinRequests,
              tone: InsTone.warn,
              onTap: () => _go('/institution/$_institutionId/join-requests'),
            ));
          }
          if (counts.invites > 0) {
            cards.add(InsActionCard(
              icon: Icons.mail_outline_rounded,
              title: 'Outstanding invites',
              body: '${counts.invites} invite'
                  '${counts.invites == 1 ? '' : 's'} created and not yet used.',
              cta: 'Manage',
              badge: counts.invites,
              tone: InsTone.info,
              onTap: () => _go('/institution/$_institutionId/invites'),
            ));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1)
                  const SizedBox(height: InsSpacing.cardGap),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AuraLoadingState(message: 'Loading institution overview…');
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: AuraErrorState(
          title: 'Overview unavailable',
          body: _error!,
          action: AuraSecondaryButton(
            label: 'Try again',
            onPressed: _load,
            icon: Icons.refresh_rounded,
          ),
        ),
      );
    }

    final standing = _standing;
    final role = _role;
    final speech = _officialSpeech;
    final domain = _domainTrust;
    final actionQueue = _buildActionQueue();

    return RefreshIndicator(
      onRefresh: _load,
      child: InsScreen(
        children: [
          // Identity (name, badges, tagline, facts) now lives in the left
          // rail / mobile bar, so the overview no longer repeats it as a hero.
          // The page leads straight with its command row + action queue.
          InsModeHeader(
            title: 'Workspace overview',
            primaryAction: (_canUseInstitutionTools &&
                    _institutionId.isNotEmpty)
                ? AuraSecondaryButton(
                    label: 'Profile',
                    icon: Icons.badge_outlined,
                    onPressed: () => _go(institutionWorkspacePath(
                      _institutionId, InstitutionSection.profile)),
                  )
                : null,
          ),

          const InsModeHeaderGap(),

          // ── Action queue ("Needs your attention") ─────────────────────
          //     First content section for operators so pending decisions are
          //     impossible to miss. Hidden for non-admins / pre-active states.
          if (actionQueue != null) ...[
            actionQueue,
            const InsSectionGap(),
          ],

          // ── Standing grid (Section B) ─────────────────────────────────
          InsSection(
            eyebrow: 'Standing',
            title: 'Status at a glance',
            child: InsResponsiveGrid(
              children: [
                InsStatusCard(
                  title: 'Standing',
                  value: standing.value,
                  helper: standing.helper,
                  tone: standing.tone,
                ),
                InsStatusCard(
                  title: 'Role',
                  value: role.value,
                  helper: role.helper,
                  tone: role.tone,
                  icon: role.icon,
                ),
                InsStatusCard(
                  title: 'Official speech',
                  value: speech.value,
                  helper: speech.helper,
                  tone: speech.tone,
                ),
                InsStatusCard(
                  title: 'Domain trust',
                  value: domain.value,
                  helper: domain.helper,
                  tone: domain.tone,
                ),
              ],
            ),
          ),

          const InsSectionGap(),

          // ── Next actions (Section C) ──────────────────────────────────
          InsSection(
            eyebrow: 'Next',
            title: 'What to do next',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tile in _buildNextActions()) ...[
                  tile,
                  const SizedBox(height: InsSpacing.cardGap),
                ],
              ],
            ),
          ),

          // Trim trailing gap from the last action card spacer.
          const SizedBox(height: AuraSpace.s4),

          // ── Light activity (Section D) ────────────────────────────────
          InsSection(
            eyebrow: 'Activity',
            title: 'Workspace pulse',
            child: _buildActivity(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity tile — a tiny stat surface used inside the Light Activity grid.
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AuraSurface.faint),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: AuraText.micro.copyWith(
                  color: AuraSurface.faint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            value,
            style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
