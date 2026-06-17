import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../presentation/institution_page.dart';
import '../ui/institution_ds.dart';

/// Institution Messaging — institution-context inbox built on Spaces.
///
/// Lists the institution's Spaces, each tappable to open the institution-
/// scoped space-thread surface (`/institution/:id/spaces/:spaceId`). Wraps
/// the existing Spaces backend; no separate "messaging" endpoint is called.
class InstitutionMessagingScreen extends ConsumerStatefulWidget {
  const InstitutionMessagingScreen({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  ConsumerState<InstitutionMessagingScreen> createState() =>
      _InstitutionMessagingScreenState();
}

class _InstitutionMessagingScreenState
    extends ConsumerState<InstitutionMessagingScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _spaces = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(institutionsRepositoryProvider);
      final spaces = await repo.listInstitutionSpaces(widget.institutionId);
      if (!mounted) return;
      setState(() {
        _spaces = spaces;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _readError(e, 'Could not load institution messages.');
      });
    }
  }

  String _readError(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final m = data['message']?.toString().trim() ?? '';
        if (m.isNotEmpty) return m;
      }
    }
    return fallback;
  }

  void _goCreateSpace() {
    // Stay in institution context — the spaces screen has an inline create
    // form for admins. Routing to /me/correspondence/create/space leaves
    // the institution shell.
    context.push('/institution/${widget.institutionId}/spaces');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(institutionIdentityProvider);

    return InstitutionPage(
      title: 'Messages',
      // Distinct from Spaces: Messages is the conversation inbox (direct
      // messages + your existing spaces' threads). Group spaces are created
      // and managed under Spaces, so this screen no longer offers a second
      // "New space" action that competed with the Spaces tab.
      subtitle:
          'Direct messages and conversations across your institution’s spaces.',
      trailing: AuraSecondaryButton(
        label: 'Manage spaces',
        icon: Icons.workspaces_outline,
        onPressed: _goCreateSpace,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entry point to the new actor-aware direct inbox. Direct is an
          // *addition* — the workspace messaging (Spaces) below remains
          // the canonical institution-internal channel.
          InkWell(
            onTap: () => context.push(
              '/institution/${widget.institutionId}/messages/direct',
            ),
            borderRadius: BorderRadius.circular(AuraRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s14,
                vertical: AuraSpace.s12,
              ),
              decoration: BoxDecoration(
                color: AuraSurface.accentSoft,
                borderRadius: BorderRadius.circular(AuraRadius.md),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: const Row(
                children: [
                  Icon(Icons.forum_outlined,
                      size: 18, color: AuraSurface.accentText),
                  SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Text(
                      'Direct messages',
                      style: AuraText.body,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: AuraSurface.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          Text(
            'GROUP SPACES',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          if (_loading)
            const AuraLoadingState(message: 'Loading spaces…')
          else if (_error != null)
            AuraErrorState(
              title: 'Could not load spaces',
              body: _error!,
              action: AuraSecondaryButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: _load,
              ),
            )
          else if (_spaces.isEmpty)
            const InsEmptyState(
              icon: Icons.forum_outlined,
              title: 'No group spaces yet',
              description: 'Create one under Spaces.',
            )
          else
            ..._spaces.map((space) => _SpaceTile(
                  space: space,
                  institutionId: widget.institutionId,
                )),
        ],
      ),
    );
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({required this.space, required this.institutionId});

  final Map<String, dynamic> space;
  final String institutionId;

  @override
  Widget build(BuildContext context) {
    final id = (space['id'] ?? '').toString();
    final title =
        (space['title'] ?? space['name'] ?? 'Untitled space').toString();
    final description = (space['description'] ?? '').toString().trim();
    final visibility = (space['visibility'] ?? '').toString().toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: InkWell(
        onTap: id.isEmpty
            ? null
            : () => context.push('/institution/$institutionId/spaces/$id'),
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AuraSurface.subtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.forum_rounded,
                    size: 18, color: AuraSurface.muted),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          AuraText.body.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AuraText.small
                            .copyWith(color: AuraSurface.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (visibility.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AuraSurface.subtle,
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                  ),
                  child: Text(
                    visibility,
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.faint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: AuraSpace.s8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AuraSurface.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
