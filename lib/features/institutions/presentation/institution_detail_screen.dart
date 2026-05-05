import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/interactions/actor_context.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/interactions/interaction_service.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../domain/institution.dart';
import '../domain/institution_post.dart';
import '../units/institution_unit_card.dart';

final institutionDetailProvider = FutureProvider.family<Institution, String>((
  ref,
  slug,
) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.getBySlug(slug);
});

/// Public posts feed for the institution-detail page. Always uses the
/// `public` scope so signed-out callers and members see the same content.
final institutionPublicPostsProvider =
    FutureProvider.family<List<InstitutionPost>, String>((ref, institutionId) async {
  if (institutionId.trim().isEmpty) return const [];
  final repo = ref.watch(institutionsRepositoryProvider);
  final page = await repo.listInstitutionPosts(
    institutionId: institutionId,
    scope: 'public',
    limit: 10,
  );
  return page.items;
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
    final coverUrl = institution.coverUrl?.trim() ?? '';
    final postsAsync =
        ref.watch(institutionPublicPostsProvider(institution.id));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (coverUrl.isNotEmpty) _PublicCoverBanner(coverUrl: coverUrl),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s16,
                    AuraSpace.s20,
                    AuraSpace.s16,
                    AuraSpace.s32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._buildContent(),
                      const SizedBox(height: AuraSpace.s10),
                      _InstitutionProfileCtaRow(institutionId: institution.id),
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

  List<Widget> _buildContent() {
    final title = institution.name.trim().isNotEmpty
        ? institution.name.trim()
        : 'Institution';

    final subtitleParts = <String>[
      if (institution.slug.trim().isNotEmpty) institution.slug.trim(),
      if (institution.domain.trim().isNotEmpty) institution.domain.trim(),
    ];

    final isVerified = institution.isVerified;
    final logoUrl = institution.logoUrl?.trim() ?? '';

    return [
      // Hero header card
      Container(
        padding: const EdgeInsets.all(AuraSpace.s20),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.xl),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PublicInstitutionAvatar(
                  size: 52,
                  name: title,
                  logoUrl: logoUrl,
                ),
                const SizedBox(width: AuraSpace.s14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: Text(title, style: AuraText.title)),
                          if (isVerified) ...[
                            const SizedBox(width: AuraSpace.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s8,
                                vertical: AuraSpace.s4,
                              ),
                              decoration: BoxDecoration(
                                color: AuraSurface.goodBg,
                                borderRadius: BorderRadius.circular(
                                  AuraRadius.pill,
                                ),
                                border: Border.all(
                                  color: AuraSurface.goodInk.withValues(
                                    alpha: 0.3,
                                  ),
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
                                  const SizedBox(width: AuraSpace.s4),
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
                        ],
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s6),
                        Text(
                          subtitleParts.join(' · '),
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (institution.description.trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s16),
              Text(
                institution.description.trim(),
                style: AuraText.body.copyWith(
                  color: AuraSurface.muted,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AuraSpace.s14),
      // Standing card
      _InfoSection(
        title: 'Standing',
        rows: [
          _InfoRow(
            label: 'Verification',
            value: isVerified ? 'Verified' : 'Not verified',
            valueColor: isVerified ? AuraSurface.goodInk : AuraSurface.muted,
          ),
          if (institution.jurisdiction.trim().isNotEmpty)
            _InfoRow(
              label: 'Jurisdiction',
              value: institution.jurisdiction.trim(),
            ),
          if (institution.domain.trim().isNotEmpty)
            _InfoRow(label: 'Domain', value: institution.domain.trim()),
        ],
      ),
      const SizedBox(height: AuraSpace.s14),
      // Details card
      _InfoSection(
        title: 'Details',
        rows: [
          _InfoRow(label: 'Name', value: institution.name),
          _InfoRow(label: 'Slug', value: institution.slug),
          if (institution.domain.trim().isNotEmpty)
            _InfoRow(label: 'Domain', value: institution.domain),
          if (institution.jurisdiction.trim().isNotEmpty)
            _InfoRow(label: 'Jurisdiction', value: institution.jurisdiction),
          if (institution.website.trim().isNotEmpty)
            _InfoRow(label: 'Website', value: institution.website),
          _InfoRow(
            label: 'Standing',
            value: isVerified ? 'Verified' : 'Unverified',
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
    ];
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

class _PublicPostsSection extends StatelessWidget {
  const _PublicPostsSection({required this.postsAsync});

  final AsyncValue<List<InstitutionPost>> postsAsync;

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
            data: (posts) {
              if (posts.isEmpty) {
                return Text(
                  'This institution has no public posts yet.',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: posts
                    .asMap()
                    .entries
                    .map((entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key < posts.length - 1
                                ? AuraSpace.s10
                                : 0,
                          ),
                          child: _PublicPostCard(post: entry.value),
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

class _PublicPostCard extends StatelessWidget {
  const _PublicPostCard({required this.post});

  final InstitutionPost post;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (post.publishedAt != null)
                Text(
                  _formatDate(post.publishedAt!),
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
            ],
          ),
          if (post.body.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              post.body,
              style: AuraText.small
                  .copyWith(color: AuraSurface.muted, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Public-shell cover banner ────────────────────────────────────────────────

class _PublicCoverBanner extends StatelessWidget {
  const _PublicCoverBanner({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: AuraSurface.accentSoft,
      child: Image.network(
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
      // Acting as the institution viewing its own public profile — show a
      // shortcut into the workspace rather than self-follow buttons.
      return Wrap(
        spacing: AuraSpace.s10,
        children: [
          AuraPrimaryButton(
            label: 'Open workspace',
            icon: Icons.dashboard_rounded,
            onPressed: () => context.push('/institution/dashboard'),
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
