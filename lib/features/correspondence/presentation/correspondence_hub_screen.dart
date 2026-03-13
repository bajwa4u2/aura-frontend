import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
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
                  'This space belongs to the signed-in account and is used for private and small-group conversations.',
            ),
            const SizedBox(height: AuraSpace.s14),
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
                            Text('Your spaces', style: AuraText.title),
                            const SizedBox(height: AuraSpace.s8),
                            Text(
                              'These are the correspondence spaces currently available to your account.',
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
                      onAction: () => ref.invalidate(
                        _correspondenceSpacesProvider,
                      ),
                    ),
                    data: (spaces) {
                      if (spaces.isEmpty) {
                        return _InlineStateCard(
                          title: 'No spaces yet',
                          body:
                              'Create your first correspondence space to begin organizing private conversations.',
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
                  DropdownMenuItem(
                    value: 'PRIVATE',
                    child: Text('Private'),
                  ),
                  DropdownMenuItem(
                    value: 'SHARED',
                    child: Text('Shared'),
                  ),
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

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({required this.space});

  final Map<String, dynamic> space;

  @override
  Widget build(BuildContext context) {
    final id = _pickString(space, const ['id', '_id', 'spaceId']);
    final name = _pickString(space, const ['name', 'title']);
    final description = _pickString(space, const ['description', 'summary']);
    final visibility = _pickString(space, const ['visibility', 'type']);
    final memberCount = _pickInt(space, const ['memberCount', 'membersCount']);
    final threadCount = _pickInt(space, const ['threadCount', 'threadsCount']);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: id.isEmpty ? null : () => context.go('/me/correspondence/$id'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  name.isEmpty ? 'Untitled space' : name,
                  style: AuraText.title,
                ),
                if (visibility.isNotEmpty)
                  _Pill(label: visibility.replaceAll('_', ' ')),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s8),
              Text(description, style: AuraText.body),
            ],
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                _MetaChip(label: 'Members', value: '$memberCount'),
                _MetaChip(label: 'Threads', value: '$threadCount'),
                if (id.isNotEmpty) _MetaChip(label: 'ID', value: id),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStateCard extends StatelessWidget {
  const _InlineStateCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(body, style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

int _pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return 0;
}