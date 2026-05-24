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

final _institutionSpacesForMessagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, institutionId) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  final spaces = await repo.listInstitutionSpaces(institutionId);
  spaces.sort((a, b) {
    final aTime = _parseTime(a['updatedAt'] ?? a['lastMessageAt'] ?? a['createdAt']);
    final bTime = _parseTime(b['updatedAt'] ?? b['lastMessageAt'] ?? b['createdAt']);
    return bTime.compareTo(aTime);
  });
  return spaces;
});

DateTime _parseTime(dynamic val) {
  if (val == null) return DateTime.fromMillisecondsSinceEpoch(0);
  try {
    return DateTime.parse(val.toString());
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class InstitutionCorrespondenceScreen extends ConsumerWidget {
  const InstitutionCorrespondenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);

    if (identity == null) {
      return AuraScaffold(
        showHeader: false,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: const [
            AuraLoadingState(message: 'Loading messages…'),
          ],
        ),
      );
    }

    final spacesAsync = ref.watch(
      _institutionSpacesForMessagesProvider(identity.id),
    );

    return AuraScaffold(
      showHeader: false,
      body: spacesAsync.when(
        loading: () => const AuraLoadingState(message: 'Loading messages…'),
        error: (e, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            AuraErrorState(
              title: 'Failed to load messages',
              body: '$e',
              action: AuraSecondaryButton(
                label: 'Try again',
                onPressed: () => ref.invalidate(
                  _institutionSpacesForMessagesProvider(identity.id),
                ),
                icon: Icons.refresh_rounded,
              ),
            ),
          ],
        ),
        data: (spaces) => _CorrespondenceBody(
          identity: identity,
          spaces: spaces,
          onRefresh: () => ref.invalidate(
            _institutionSpacesForMessagesProvider(identity.id),
          ),
        ),
      ),
    );
  }
}

class _CorrespondenceBody extends ConsumerStatefulWidget {
  const _CorrespondenceBody({
    required this.identity,
    required this.spaces,
    required this.onRefresh,
  });

  final InstitutionIdentity identity;
  final List<Map<String, dynamic>> spaces;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_CorrespondenceBody> createState() => _CorrespondenceBodyState();
}

class _CorrespondenceBodyState extends ConsumerState<_CorrespondenceBody> {
  bool _creating = false;
  bool _showCreate = false;
  String? _createError;
  final _titleCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _creating = true;
      _createError = null;
    });

    try {
      final repo = ref.read(institutionsRepositoryProvider);
      await repo.createInstitutionSpace(
        widget.identity.id,
        title: title,
        description: '',
        visibility: 'INVITE_ONLY',
      );
      _titleCtrl.clear();
      setState(() {
        _showCreate = false;
        _creating = false;
      });
      widget.onRefresh();
    } catch (e) {
      setState(() {
        _createError = 'Could not create channel: $e';
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.identity.isAdmin;

    return ListView(
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
                    const Expanded(
                      child: Text('Messages', style: AuraText.headline),
                    ),
                    if (isAdmin)
                      AuraPrimaryButton(
                        label: 'New channel',
                        icon: Icons.add_rounded,
                        onPressed: () => setState(() {
                          _showCreate = !_showCreate;
                          _createError = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s6),
                Text(
                  'Institution message channels — conversations sorted by most recent activity.',
                  style: AuraText.body.copyWith(color: AuraSurface.muted),
                ),

                if (_showCreate) ...[
                  const SizedBox(height: AuraSpace.s16),
                  _CreateChannelCard(
                    ctrl: _titleCtrl,
                    creating: _creating,
                    error: _createError,
                    onSubmit: _createChannel,
                    onCancel: () => setState(() {
                      _showCreate = false;
                      _createError = null;
                    }),
                  ),
                ],

                const SizedBox(height: AuraSpace.s24),

                if (widget.spaces.isEmpty)
                  _EmptyChannels(isAdmin: isAdmin, onCreate: () => setState(() => _showCreate = true))
                else
                  ...widget.spaces.map(
                    (space) => Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                      child: _ChannelCard(space: space),
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

class _CreateChannelCard extends StatelessWidget {
  const _CreateChannelCard({
    required this.ctrl,
    required this.creating,
    required this.error,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController ctrl;
  final bool creating;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  static const Color _accent = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEW CHANNEL',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          TextField(
            controller: ctrl,
            style: AuraText.body,
            decoration: InputDecoration(
              hintText: 'Channel name…',
              hintStyle: AuraText.body.copyWith(color: AuraSurface.faint),
              filled: true,
              fillColor: AuraSurface.subtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AuraRadius.md),
                borderSide: const BorderSide(color: AuraSurface.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AuraRadius.md),
                borderSide: const BorderSide(color: AuraSurface.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AuraRadius.md),
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s14,
                vertical: AuraSpace.s12,
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          if (error != null) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              error!,
              style: AuraText.small.copyWith(color: AuraSurface.coRose),
            ),
          ],
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: AuraPrimaryButton(
                  label: creating ? 'Creating…' : 'Create channel',
                  onPressed: creating ? null : onSubmit,
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              AuraSecondaryButton(label: 'Cancel', onPressed: onCancel),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.space});

  final Map<String, dynamic> space;

  static const Color _accent = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final id = (space['id'] ?? '').toString();
    final title = (space['title'] ?? space['name'] ?? 'Untitled channel').toString();
    final description = (space['description'] ?? '').toString();
    final lastMsg = (space['lastMessage'] ?? space['lastMessagePreview'] ?? '').toString();
    final memberCount = space['memberCount'] ?? space['_count']?['members'];
    final updatedAt = space['updatedAt'] ?? space['lastMessageAt'] ?? space['createdAt'];
    final archived = (space['archivedAt'] ?? space['deletedAt']) != null;

    final preview = lastMsg.isNotEmpty
        ? lastMsg
        : description.isNotEmpty
            ? description
            : 'No messages yet';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: id.isNotEmpty ? () => context.push('/me/correspondence/$id') : null,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x1E0D9488),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 18,
                  color: _accent,
                ),
              ),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (archived)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AuraSurface.subtle,
                              borderRadius: BorderRadius.circular(AuraRadius.pill),
                            ),
                            child: Text(
                              'Archived',
                              style: AuraText.micro.copyWith(color: AuraSurface.faint),
                            ),
                          ),
                        if (updatedAt != null) ...[
                          const SizedBox(width: AuraSpace.s8),
                          Text(
                            _formatTime(updatedAt.toString()),
                            style: AuraText.micro.copyWith(color: AuraSurface.faint),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      preview,
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (memberCount != null) ...[
                      const SizedBox(height: AuraSpace.s6),
                      Row(
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 12, color: AuraSurface.faint),
                          const SizedBox(width: 3),
                          Text(
                            '$memberCount',
                            style: AuraText.micro.copyWith(color: AuraSurface.faint),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AuraSurface.faint),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels({required this.isAdmin, required this.onCreate});

  final bool isAdmin;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s24),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.forum_outlined, size: 40, color: AuraSurface.faint),
          const SizedBox(height: AuraSpace.s14),
          const Text('No message channels', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s6),
          Text(
            isAdmin
                ? 'Create a channel to start a conversation with institution members.'
                : 'No message channels are available yet.',
            style: AuraText.body.copyWith(color: AuraSurface.muted),
            textAlign: TextAlign.center,
          ),
          if (isAdmin) ...[
            const SizedBox(height: AuraSpace.s16),
            AuraPrimaryButton(
              label: 'Create channel',
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
          ],
        ],
      ),
    );
  }
}
