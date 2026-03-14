import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_scaffold.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<_SelectablePerson> _allPeople = const [
    _SelectablePerson(
      id: 'u_1',
      name: 'Nimra',
      handle: '@nimra',
      subtitle: 'Follower',
    ),
    _SelectablePerson(
      id: 'u_2',
      name: 'Hamza',
      handle: '@hamza',
      subtitle: 'Follower',
    ),
    _SelectablePerson(
      id: 'u_3',
      name: 'Ali Raza',
      handle: '@aliraza',
      subtitle: 'Follower',
    ),
    _SelectablePerson(
      id: 'u_4',
      name: 'Sara Khan',
      handle: '@sarakhan',
      subtitle: 'Follower',
    ),
    _SelectablePerson(
      id: 'u_5',
      name: 'Ayesha',
      handle: '@ayesha',
      subtitle: 'Follower',
    ),
  ];

  final Set<String> _selectedIds = <String>{};

  String _spaceVisibility = 'PRIVATE';
  bool _submitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isSharedSpaceMode {
    final location = GoRouterState.of(context).uri.toString();
    return location.contains('/create/space');
  }

  String get _pageTitle {
    return _isSharedSpaceMode ? 'Create shared space' : 'New conversation';
  }

  String get _pageIntro {
    return _isSharedSpaceMode
        ? 'Choose participants from your allowed relationship circle, then define the space.'
        : 'Choose one or more people to begin a direct or group conversation.';
  }

  List<_SelectablePerson> get _filteredPeople {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allPeople;

    return _allPeople.where((person) {
      return person.name.toLowerCase().contains(q) ||
          person.handle.toLowerCase().contains(q) ||
          person.subtitle.toLowerCase().contains(q);
    }).toList();
  }

  List<_SelectablePerson> get _selectedPeople {
    return _allPeople.where((p) => _selectedIds.contains(p.id)).toList();
  }

  bool get _canSubmit {
    if (_selectedIds.isEmpty || _submitting) return false;

    if (_isSharedSpaceMode) {
      return _titleController.text.trim().isNotEmpty;
    }

    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;

      final participantCount = _selectedIds.length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSharedSpaceMode
                ? 'Shared space draft ready for $participantCount participant${participantCount == 1 ? '' : 's'}.'
                : 'Conversation draft ready for $participantCount participant${participantCount == 1 ? '' : 's'}.',
          ),
        ),
      );

      context.go('/me/correspondence');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _togglePerson(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _removeSelected(String id) {
    setState(() {
      _selectedIds.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedPeople = _selectedPeople;
    final filteredPeople = _filteredPeople;
    final isGroup = selectedPeople.length > 1;

    return AuraScaffold(
      title: _pageTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pageTitle, style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                Text(_pageIntro, style: AuraText.body),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Participants', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  'Search and select from allowed people only.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search followers',
                    labelText: 'Search',
                  ),
                ),
                if (selectedPeople.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      for (final person in selectedPeople)
                        _SelectedPersonChip(
                          label: person.name,
                          onRemoved: () => _removeSelected(person.id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('People', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                if (filteredPeople.isEmpty)
                  Text(
                    'No matching people found.',
                    style: AuraText.body,
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < filteredPeople.length; i++) ...[
                        _PersonRow(
                          person: filteredPeople[i],
                          selected: _selectedIds.contains(filteredPeople[i].id),
                          onTap: () => _togglePerson(filteredPeople[i].id),
                        ),
                        if (i != filteredPeople.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSharedSpaceMode ? 'Space details' : 'Conversation details',
                  style: AuraText.title,
                ),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  _isSharedSpaceMode
                      ? 'Shared spaces can hold continuing group exchange.'
                      : isGroup
                          ? 'Multiple participants will begin as a group conversation.'
                          : 'One participant will begin as a direct conversation.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                if (_isSharedSpaceMode) ...[
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Space title',
                      hintText: 'Research Circle, Studio, Family',
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Optional context for this shared space',
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  DropdownButtonFormField<String>(
                    value: _spaceVisibility,
                    decoration: const InputDecoration(
                      labelText: 'Visibility',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'PRIVATE',
                        child: Text('Private'),
                      ),
                      DropdownMenuItem(
                        value: 'INVITE_ONLY',
                        child: Text('Invite only'),
                      ),
                      DropdownMenuItem(
                        value: 'DISCOVERABLE',
                        child: Text('Discoverable'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _spaceVisibility = value);
                    },
                  ),
                ] else ...[
                  _ModeInfoRow(
                    label: 'Mode',
                    value: isGroup ? 'Group conversation' : 'Direct conversation',
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  _ModeInfoRow(
                    label: 'Participants',
                    value: '${selectedPeople.length}',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(
                    _submitting
                        ? (_isSharedSpaceMode ? 'Creating...' : 'Starting...')
                        : (_isSharedSpaceMode
                            ? 'Create shared space'
                            : 'Start conversation'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final _SelectablePerson person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(
                person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name, style: AuraText.body),
                  const SizedBox(height: 2),
                  Text(
                    '${person.handle} · ${person.subtitle}',
                    style: AuraText.small,
                  ),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedPersonChip extends StatelessWidget {
  const _SelectedPersonChip({
    required this.label,
    required this.onRemoved,
  });

  final String label;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s8,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AuraText.small),
          const SizedBox(width: AuraSpace.s8),
          InkWell(
            onTap: onRemoved,
            child: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }
}

class _ModeInfoRow extends StatelessWidget {
  const _ModeInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(value, style: AuraText.body),
        ),
      ],
    );
  }
}

class _SelectablePerson {
  const _SelectablePerson({
    required this.id,
    required this.name,
    required this.handle,
    required this.subtitle,
  });

  final String id;
  final String name;
  final String handle;
  final String subtitle;
}