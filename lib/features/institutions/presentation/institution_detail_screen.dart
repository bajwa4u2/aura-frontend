import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/institutions/institution_paths.dart';
import '../../../core/interactions/actor_context.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/interactions/interaction_service.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../data/institutions_repository.dart';
import '../domain/institution.dart';
import '../units/institution_unit_card.dart';

final institutionDetailProvider = FutureProvider.family<Institution, String>((
  ref,
  slug,
) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.getBySlug(slug);
});

class InstitutionDetailScreen extends ConsumerWidget {
  const InstitutionDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanSlug = slug.trim();
    final institutionAsync = ref.watch(institutionDetailProvider(cleanSlug));

    return AuraScaffold(
      showHeader: false,
      body: institutionAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading institution…'),
        ),
        error: (e, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            AuraErrorState(
              title: 'Institution could not be loaded',
              body: '$e',
            ),
          ],
        ),
        data: (institution) => _InstitutionDetailBody(institution: institution),
      ),
    );
  }
}

class _InstitutionDetailBody extends ConsumerWidget {
  const _InstitutionDetailBody({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync =
        ref.watch(institutionProfileFeedProvider(institution.id));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PublicHero(institution: institution),
                const SizedBox(height: AuraSpace.s12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16,
                  ),
                  child: _PublicIdentity(institution: institution),
                ),
                const SizedBox(height: AuraSpace.s14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16,
                  ),
                  child: _InstitutionProfileCtaRow(
                    institutionId: institution.id,
                  ),
                ),
                const SizedBox(height: AuraSpace.s14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16,
                  ),
                  child: _PublicStatChips(institution: institution),
                ),
                const SizedBox(height: AuraSpace.s14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s16,
                    0,
                    AuraSpace.s16,
                    AuraSpace.s32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (institution.description.trim().isNotEmpty) ...[
                        _InfoSection(
                          title: 'About',
                          rows: [
                            _InfoRow(
                              label: 'Description',
                              value: institution.description.trim(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s14),
                      ],
                      if (institution.website.trim().isNotEmpty) ...[
                        _InfoSection(
                          title: 'Contact',
                          rows: [
                            _InfoRow(
                              label: 'Website',
                              value: institution.website.trim(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s14),
                      ],
                      _InfoSection(
                        title: 'Domains & verification',
                        rows: [
                          _InfoRow(
                            label: 'Verification',
                            value: institution.isVerified
                                ? 'Verified'
                                : 'Not verified',
                            valueColor: institution.isVerified
                                ? AuraSurface.goodInk
                                : AuraSurface.muted,
                          ),
                          if (institution.domain.trim().isNotEmpty)
                            _InfoRow(
                              label: 'Domain',
                              value: institution.domain.trim(),
                            ),
                          if (institution.jurisdiction.trim().isNotEmpty)
                            _InfoRow(
                              label: 'Jurisdiction',
                              value: institution.jurisdiction.trim(),
                            ),
                          if ((institution.category ?? '').trim().isNotEmpty)
                            _InfoRow(
                              label: 'Category',
                              value: (institution.category ?? '').trim(),
                            ),
                        ],
                      ),
                      if (institution.units.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s14),
                        _UnitsSection(
                          institutionName: institution.name,
                          units: institution.units,
                        ),
                      ],
                      const SizedBox(height: AuraSpace.s14),
                      _PublicPostsSection(postsAsync: postsAsync),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Units section ──────────────────────────────────────────────────────────

class _UnitsSection extends StatelessWidget {
  const _UnitsSection({
    required this.institutionName,
    required this.units,
  });

  final String institutionName;
  final List<InstitutionUnit> units;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UNITS & BRANCHES',
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: AuraSurface.faint,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          ...units.asMap().entries.map(
            (e) => Padding(
              padding: EdgeInsets.only(
                bottom: e.key < units.length - 1 ? AuraSpace.s10 : 0,
              ),
              child: PublicUnitCard(
                unit: e.value,
                institutionName: institutionName,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info section ───────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: AuraSurface.faint,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          ...rows.asMap().entries.map(
            (e) => Padding(
              padding: EdgeInsets.only(
                bottom: e.key < rows.length - 1 ? AuraSpace.s10 : 0,
              ),
              child: e.value,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim().isEmpty ? '—' : value.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w600,
              color: AuraSurface.muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            cleanValue,
            style: AuraText.small.copyWith(
              color: valueColor ?? AuraSurface.ink,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Public posts section ────────────────────────────────────────────────────
//
// Consumes the unified `institutionProfileFeedProvider` and renders rows via
// the shared `UnifiedFeedCard`. Empty state only fires when the provider
// returns an empty page — never when posts exist (per Phase 2 rule:
// "❌ Remove false 'No posts' empty state").

class _PublicPostsSection extends StatelessWidget {
  const _PublicPostsSection({required this.postsAsync});

  final AsyncValue<FeedPage> postsAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POSTS',
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: AuraSurface.faint,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          postsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Could not load posts.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return Text(
                  'This institution has no public posts yet.',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: page.items
                    .asMap()
                    .entries
                    .map((entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key < page.items.length - 1
                                ? AuraSpace.s10
                                : 0,
                          ),
                          child: UnifiedFeedCard(item: entry.value),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Public hero (cover + avatar overlap) ─────────────────────────────────────

class _PublicHero extends StatelessWidget {
  const _PublicHero({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context) {
    const double coverHeight = 220;
    const double avatarSize = 96;
    final coverUrl = institution.coverUrl?.trim() ?? '';
    final logoUrl = institution.logoUrl?.trim() ?? '';
    final name = institution.name.trim().isNotEmpty
        ? institution.name.trim()
        : 'Institution';

    return SizedBox(
      height: coverHeight + avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: avatarSize / 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AuraSurface.accent.withValues(alpha: 0.30),
                    AuraSurface.accent.withValues(alpha: 0.08),
                    AuraSurface.subtle,
                  ],
                ),
              ),
              child: coverUrl.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 56,
                        color: AuraSurface.accentText,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AuraSurface.accentSoft,
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: AuraSurface.accentText,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            left: AuraSpace.s16,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AuraSurface.page,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _PublicInstitutionAvatar(
                size: avatarSize,
                name: name,
                logoUrl: logoUrl,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Public identity (name / verified / slug · domain / description) ─────────

class _PublicIdentity extends StatelessWidget {
  const _PublicIdentity({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context) {
    final title = institution.name.trim().isNotEmpty
        ? institution.name.trim()
        : 'Institution';
    final slug = institution.slug.trim();
    final domain = institution.domain.trim();
    final subtitleParts = <String>[
      if (slug.isNotEmpty) '@$slug',
      if (domain.isNotEmpty) domain,
    ];
    final description = institution.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s6,
          children: [
            Text(title, style: AuraText.title),
            if (institution.isVerified)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.goodBg,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(
                    color: AuraSurface.goodInk.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 12,
                      color: AuraSurface.goodInk,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.goodInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (subtitleParts.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s4),
          Text(
            subtitleParts.join(' · '),
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s10),
          Text(
            description,
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ── Public stat chips ────────────────────────────────────────────────────────

class _PublicStatChips extends StatelessWidget {
  const _PublicStatChips({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _PublicStatChip(
        icon: Icons.verified_rounded,
        label: institution.isVerified ? 'Verified' : 'Unverified',
        good: institution.isVerified,
      ),
      if (institution.domain.trim().isNotEmpty)
        _PublicStatChip(
          icon: Icons.dns_rounded,
          label: institution.domain.trim(),
        ),
      if (institution.jurisdiction.trim().isNotEmpty)
        _PublicStatChip(
          icon: Icons.public_rounded,
          label: institution.jurisdiction.trim(),
        ),
      if ((institution.category ?? '').trim().isNotEmpty)
        _PublicStatChip(
          icon: Icons.category_rounded,
          label: (institution.category ?? '').trim(),
        ),
      if ((institution.location ?? '').trim().isNotEmpty)
        _PublicStatChip(
          icon: Icons.place_rounded,
          label: (institution.location ?? '').trim(),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: chips,
    );
  }
}

class _PublicStatChip extends StatelessWidget {
  const _PublicStatChip({
    required this.icon,
    required this.label,
    this.good = false,
  });

  final IconData icon;
  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final fg = good ? AuraSurface.goodInk : AuraSurface.muted;
    final bg = good ? AuraSurface.goodBg : AuraSurface.subtle;
    final border = good
        ? AuraSurface.goodInk.withValues(alpha: 0.3)
        : AuraSurface.divider;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Public-shell institution avatar ──────────────────────────────────────────

class _PublicInstitutionAvatar extends StatelessWidget {
  const _PublicInstitutionAvatar({
    required this.size,
    required this.name,
    required this.logoUrl,
  });

  final double size;
  final String name;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    Widget fallback() {
      final initial = name.trim().isNotEmpty
          ? name.trim()[0].toUpperCase()
          : '';
      if (initial.isNotEmpty) {
        return Center(
          child: Text(
            initial,
            style: TextStyle(
              color: AuraSurface.accentText,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }
      return Icon(
        Icons.apartment_outlined,
        size: size * 0.46,
        color: AuraSurface.accentText,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isNotEmpty
          ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            )
          : fallback(),
    );
  }
}

// ── Profile Follow + Message CTAs ────────────────────────────────────────────

class _InstitutionProfileCtaRow extends ConsumerStatefulWidget {
  const _InstitutionProfileCtaRow({required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<_InstitutionProfileCtaRow> createState() =>
      _InstitutionProfileCtaRowState();
}

class _InstitutionProfileCtaRowState
    extends ConsumerState<_InstitutionProfileCtaRow> {
  bool _busy = false;
  String? _error;

  ActorRef _targetRef() => ActorRef.institution(widget.institutionId);

  ActorRef? _actorRefOf(ActorContext actor) {
    if (actor.isInstitution) {
      final id = (actor.institutionId ?? '').trim();
      if (id.isEmpty) return null;
      return ActorRef.institution(id);
    }
    final uid = (actor.userId ?? '').trim();
    if (uid.isEmpty) return null;
    return ActorRef.user(uid);
  }

  bool _isOwnInstitution(ActorContext actor) {
    return actor.isInstitution &&
        (actor.institutionId ?? '') == widget.institutionId;
  }

  Future<void> _toggleFollow(
    ActorContext actor,
    FollowState current,
    FollowStateKey key,
  ) async {
    final actorRef = _actorRefOf(actor);
    if (actorRef == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(followsRepositoryProvider);
      if (current.following) {
        await repo.unfollow(actor: actorRef, target: _targetRef());
      } else {
        await repo.follow(actor: actorRef, target: _targetRef());
      }
      ref.invalidate(followStateProvider(key));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _readError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMessage(ActorContext actor) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(interactionServiceProvider).openDirectThread(
            context: context,
            ref: ref,
            target: _targetRef(),
          );
    } on InteractionError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _readError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final m = data['message']?.toString().trim() ?? '';
        if (m.isNotEmpty) return m;
      }
      if (e.response?.statusCode == 403) {
        return 'Not allowed.';
      }
    }
    return 'Something went wrong. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStatusProvider);

    if (auth != AuthStatus.authed) {
      return Wrap(
        spacing: AuraSpace.s10,
        runSpacing: AuraSpace.s10,
        children: [
          AuraPrimaryButton(
            label: 'Sign in',
            icon: Icons.login_rounded,
            onPressed: () => context.push('/login'),
          ),
          AuraSecondaryButton(
            label: 'Join Aura',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => context.push('/register'),
          ),
        ],
      );
    }

    final actor = resolveActorContext(context, ref);
    if (actor == null) {
      return const SizedBox.shrink();
    }
    final actorRef = _actorRefOf(actor);
    if (actorRef == null) return const SizedBox.shrink();

    if (_isOwnInstitution(actor)) {
      return Wrap(
        spacing: AuraSpace.s10,
        runSpacing: AuraSpace.s10,
        children: [
          AuraPrimaryButton(
            label: 'Open workspace',
            icon: Icons.dashboard_rounded,
            onPressed: () => context.push('/institution/dashboard'),
          ),
          AuraSecondaryButton(
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            onPressed: () => context.push(
              widget.institutionId.isNotEmpty
                  ? institutionWorkspacePath(
                      widget.institutionId, InstitutionSection.editProfile)
                  : '/institution/dashboard',
            ),
          ),
        ],
      );
    }

    final key = FollowStateKey(actor: actorRef, target: _targetRef());
    final stateAsync = ref.watch(followStateProvider(key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stateAsync.when(
          loading: () => const SizedBox(
            height: 38,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Text(
            'Could not load follow state.',
            style:
                AuraText.small.copyWith(color: AuraSurface.dangerInk),
          ),
          data: (state) {
            return Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                AuraPrimaryButton(
                  label: _busy
                      ? 'Working…'
                      : (state.following ? 'Following' : 'Follow'),
                  icon: state.following
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                  onPressed: _busy
                      ? null
                      : () => _toggleFollow(actor, state, key),
                ),
                AuraSecondaryButton(
                  label: state.canMessage
                      ? (_busy ? 'Opening…' : 'Message')
                      : (actor.isUser
                          ? 'Follow to message'
                          : 'Cannot message'),
                  icon: Icons.mail_outline_rounded,
                  onPressed: state.canMessage && !_busy
                      ? () => _openMessage(actor)
                      : null,
                ),
              ],
            );
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.s8),
          Text(
            _error!,
            style: AuraText.small
                .copyWith(color: AuraSurface.dangerInk),
          ),
        ],
      ],
    );
  }
}
