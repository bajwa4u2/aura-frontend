import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<_InviteCandidate> _allCandidates = const [
    _InviteCandidate(
      id: 'u_1',
      name: 'Nimra',
      handle: '@nimra',
      sub
    ),
    _InviteCandidate(
      id: 'u_2',
      name: 'Hamza',
      handle: '@hamza',
      sub
    ),
    _InviteCandidate(
      id: 'u_3',
      name: 'Ali Raza',
      handle: '@aliraza',
      sub
    ),
    _InviteCandidate(
      id: 'u_4',
      name: 'Sara Khan',
      handle: '@sarakhan',
      sub
    ),
    _InviteCandidate(
      id: 'u_5',
      name: 'Ayesha',
      handle: '@ayesha',
      sub
    ),
  ];

  _InviteCandidate? _selectedPerson;
  String _selectedRole = 'MEMBER';
  bool _submitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_InviteCandidate> get _filteredCandidates {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allCandidates;

    return _allCandidates.where((person) {
      return person.name.toLowerCase().contains(q) ||
          person.handle.toLowerCase().contains(q) ||
          person.subtitle.toLowerCase().contains(q);
    }).toList();
  }

  bool get _canSubmit {
    return !_submitting && _selectedPerson != null;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invite prepared for ${_selectedPerson!.name} as $_selectedRole.',
          ),
        ),
      );

      context.pop(true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _selectPerson(_InviteCandidate person) {
    setState(() {
      if (_selectedPerson?.id == person.id) {
        _selectedPerson = null;
      } else {
        _selectedPerson = person;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCandidates = _filteredCandidates;

    return AuraScaffold(
      
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite member', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  'Search and invite from allowed followers only. This is not an open platform-wide search.',
                  style: AuraText.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Search followers', style: AuraText.title),
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search',
                    hintText: 'Search followers',
                  ),
                ),
                if (_selectedPerson != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  _SelectedInviteChip(
                    label: _selectedPerson!.name,
                    onRemoved: () {
                      setState(() => _selectedPerson = null);
                    },
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
                if (filteredCandidates.isEmpty)
                  Text(
                    'No matching followers found.',
                    style: AuraText.body,
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < filteredCandidates.length; i++) ...[
                        _InvitePersonRow(
                          person: filteredCandidates[i],
                          selected: _selectedPerson?.id == filteredCandidates[i].id,
                          onTap: () => _selectPerson(filteredCandidates[i]),
                        ),
                        if (i != filteredCandidates.length - 1)
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
                Text('Invite settings', style: AuraText.title),
                const SizedBox(height: AuraSpace.s12),
                _DetailRow(
                  label: 'Space ID',
                  value: widget.spaceId,
                ),
                const SizedBox(height: AuraSpace.s12),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'MEMBER',
                      child: Text('Member'),
                    ),
                    DropdownMenuItem(
                      value: 'ADMIN',
                      child: Text('Admin'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedRole = value);
                  },
                ),
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
                  child: Text(_submitting ? 'Inviting...' : 'Send invite'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvitePersonRow extends StatelessWidget {
  const _InvitePersonRow({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final _InviteCandidate person;
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
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => onTap(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedInviteChip extends StatelessWidget {
  const _SelectedInviteChip({
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AuraText.body,
          ),
        ),
      ],
    );
  }
}

class _InviteCandidate {
  const _InviteCandidate({
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