import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';

/// Institution Messaging — institution-context inbox built on Spaces.
///
/// Lists the institution's Spaces, each tappable to open the existing
/// space-thread surface (`/me/correspondence/:spaceId`). Wraps the existing
/// Spaces backend; no separate "messaging" endpoint is called.
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

  void _newConversation() {
    // Existing space creation flow, prefilled with the institution. The
    // hub picks up the institution from the active member context.
    context.push(
      '/me/correspondence/create/space?institutionId=${widget.institutionId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final title = identity?.name.isNotEmpty == true
        ? 'Institution Messages — ${identity!.name}'
        : 'Institution Messages';

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s20,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: AuraText.headline),
                      ),
                      AuraPrimaryButton(
                        label: 'New conversation',
                        icon: Icons.add_rounded,
                        onPressed: _newConversation,
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s6),
                  Text(
                    'Spaces are this institution\'s messaging primitive. '
                    'Tap a space to open its threads.',
                    style: AuraText.body
                        .copyWith(color: AuraSurface.muted, height: 1.5),
                  ),
                  const SizedBox(height: AuraSpace.s20),
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
                    const AuraEmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No conversations yet',
                      body:
                          'Create a space to start a thread with members of this institution.',
                    )
                  else
                    ..._spaces.map((space) => _SpaceTile(space: space)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({required this.space});

  final Map<String, dynamic> space;

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
            : () => context.push('/me/correspondence/$id'),
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
