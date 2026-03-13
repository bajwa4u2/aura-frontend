import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../data/spaces_repository.dart';

final _correspondenceSpacesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authStatusProvider);

  if (auth != AuthStatus.authed) {
    return [];
  }

  final repo = ref.watch(spacesRepositoryProvider);
  return repo.listMySpaces();
});

class CorrespondenceHubScreen extends ConsumerWidget {
  const CorrespondenceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _MemberCorrespondenceScreen();
  }
}

class _SectionIntroCard extends StatelessWidget {
  const _SectionIntroCard({
    required this.title,
    required this.body,
    this.backLabel = 'Back to account',
    this.backRoute = '/me',
  });

  final String title;
  final String body;
  final String backLabel;
  final String backRoute;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Text(body, style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),
          OutlinedButton(
            onPressed: () => context.go(backRoute),
            child: Text(backLabel),
          ),
        ],
      ),
    );
  }
}

class _MemberCorrespondenceScreen extends ConsumerWidget {
  const _MemberCorrespondenceScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStatusProvider);

    final spacesAsync = auth == AuthStatus.authed
        ? ref.watch(_correspondenceSpacesProvider)
        : const AsyncValue<List<Map<String, dynamic>>>.loading();

    return AuraScaffold(
      title: 'Correspondence',
      body: RefreshIndicator(
        onRefresh: () async {
          if (ref.read(authStatusProvider) != AuthStatus.authed) return;

          ref.invalidate(_correspondenceSpacesProvider);
          await ref.read(_correspondenceSpacesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const _SectionIntroCard(
              title: 'Correspondence',
              body:
                  'Private conversations and small group discussions connected to your account.',
            ),

            const SizedBox(height: AuraSpace.s16),

            /// NEW CONVERSATION ENTRY
            FilledButton.icon(
              onPressed: auth == AuthStatus.authed
                  ? () => context.go('/me/correspondence/create/conversation')
                  : null,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Start new conversation'),
            ),

            const SizedBox(height: AuraSpace.s16),

            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Spaces', style: AuraText.title),
                            const SizedBox(height: AuraSpace.s8),
                            Text(
                              'Spaces organize ongoing conversations with specific groups.',
                              style: AuraText.body,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      FilledButton(
                        onPressed: auth == AuthStatus.authed
                            ? () => _showCreateSpaceDialog(context, ref)
                            : null,
                        child: const Text('New space'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s14),

                  spacesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                    error: (error, _) => _InlineStateCard(
                      title: 'Could not load spaces',
                      body: '$error',
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.invalidate(_correspondenceSpacesProvider),
                    ),

                    data: (spaces) {
                      if (spaces.isEmpty) {
                        return _InlineStateCard(
                          title: 'No spaces yet',
                          body:
                              'Create your first space to organize conversations with others.',
                          actionLabel: 'Create space',
                          onAction: auth == AuthStatus.authed
                              ? () => _showCreateSpaceDialog(context, ref)
                              : () {},
                        );
                      }

                      return Column(
                        children: [
                          for (var i = 0; i < spaces.length; i++) ...[
                            _SpaceTile(space: spaces[i]),
                            if (i != spaces.length - 1)
                              const SizedBox(height: AuraSpace.s10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateSpaceDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateSpaceDialog(),
    );

    if (created == true) {
      ref.invalidate(_correspondenceSpacesProvider);
    }
  }
}

class _CreateSpaceDialog extends ConsumerStatefulWidget {
  const _CreateSpaceDialog();

  @override
  ConsumerState<_CreateSpaceDialog> createState() => _CreateSpaceDialogState();
}

class _CreateSpaceDialogState extends ConsumerState<_CreateSpaceDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _visibility = 'PRIVATE';
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorText = 'Please enter a space name.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final repo = ref.read(spacesRepositoryProvider);

      await repo.createSpace(
        name: name,
        description: description.isEmpty ? null : description,
        visibility: _visibility,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorText = '$e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create space'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Space name',
                  hintText: 'Family, Research, Outreach',
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional context for this space',
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              DropdownButtonFormField<String>(
                value: _visibility,
                items: const [
                  DropdownMenuItem(value: 'PRIVATE', child: Text('Private')),
                  DropdownMenuItem(value: 'SHARED', child: Text('Shared')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _visibility = value);
                      },
                decoration: const InputDecoration(
                  labelText: 'Visibility',
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: AuraSpace.s12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorText!,
                    style: AuraText.small.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Creating...' : 'Create'),
        ),
      ],
    );
  }
}
