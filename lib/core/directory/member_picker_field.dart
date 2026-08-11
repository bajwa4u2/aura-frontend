import 'package:flutter/material.dart';

import '../ui/aura_platform_components.dart';
import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'directory_entry.dart';

/// Reusable member/person selection field built on the canonical
/// [DirectoryEntry] identity model -- Identity Foundation Phase 1's shared
/// identity resolution repair.
///
/// This is the "smallest durable implementation that reuses the already
/// -fixed canonical member identity path" for surfaces other than
/// `NewConversationScreen`: it loads a candidate list once (via
/// [loadCandidates]) and filters/selects client-side, so any surface with
/// a bounded, already-known candidate set (an institution's own member
/// roster, for example -- there is no server-side search endpoint for
/// that today) can offer member selection without re-implementing
/// selection/dedupe/rendering logic, and without inventing a second
/// identity model. Surfaces with a genuine server-side search (the
/// platform-wide `/search` + relationships used by Thread/personal-space
/// creation) keep their own richer flow in `NewConversationScreen` --
/// the identity *model* is shared via `directory_entry.dart`, not this
/// widget, so the two surfaces' differing contracts (bounded roster vs.
/// live search) don't have to be forced into one UI.
class MemberPickerField extends StatefulWidget {
  const MemberPickerField({
    super.key,
    required this.loadCandidates,
    required this.onSelectionChanged,
    this.excludeUserIds = const {},
    this.initialSelected = const [],
    this.searchHintText = 'Search members',
    this.emptyLabel = 'No members found.',
    this.errorLabel = 'Could not load members.',
  });

  /// Loads the full candidate list once. Client-side text filtering is
  /// applied on top of this, matching the same substring-match convention
  /// `NewConversationScreen._filteredEntries` already uses.
  final Future<List<DirectoryEntry>> Function() loadCandidates;

  final ValueChanged<List<DirectoryEntry>> onSelectionChanged;

  /// Canonical userIds to exclude from candidates entirely (e.g. the
  /// current user, who is added separately as the space owner).
  final Set<String> excludeUserIds;

  final List<DirectoryEntry> initialSelected;
  final String searchHintText;
  final String emptyLabel;
  final String errorLabel;

  @override
  State<MemberPickerField> createState() => _MemberPickerFieldState();
}

class _MemberPickerFieldState extends State<MemberPickerField> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  List<DirectoryEntry> _candidates = const [];

  final Set<String> _selectedIds = <String>{};
  final Map<String, DirectoryEntry> _selectedEntriesById =
      <String, DirectoryEntry>{};

  @override
  void initState() {
    super.initState();
    for (final entry in widget.initialSelected) {
      _selectedIds.add(entry.id);
      _selectedEntriesById[entry.id] = entry;
    }
    _searchController.addListener(_handleSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded = await widget.loadCandidates();
      final filtered = dedupeDirectoryEntries(
        loaded
            .where((entry) => !widget.excludeUserIds.contains(entry.userId))
            .toList(growable: false),
      )..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _candidates = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  List<DirectoryEntry> get _filteredCandidates {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _candidates;
    return _candidates.where((entry) {
      final haystack = [
        entry.displayName,
        entry.subtitle,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  List<DirectoryEntry> get _selectedEntries => _selectedIds
      .map((id) => _selectedEntriesById[id])
      .whereType<DirectoryEntry>()
      .toList(growable: false);

  void _toggle(DirectoryEntry entry) {
    setState(() {
      if (_selectedIds.contains(entry.id)) {
        _selectedIds.remove(entry.id);
        _selectedEntriesById.remove(entry.id);
      } else {
        _selectedIds.add(entry.id);
        _selectedEntriesById[entry.id] = entry;
      }
    });
    widget.onSelectionChanged(_selectedEntries);
  }

  void _remove(String id) {
    setState(() {
      _selectedIds.remove(id);
      _selectedEntriesById.remove(id);
    });
    widget.onSelectionChanged(_selectedEntries);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedEntries.isNotEmpty) ...[
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              for (final entry in _selectedEntries)
                _PickerChip(
                  label: entry.displayName,
                  avatarUrl: entry.avatarUrl,
                  onRemoved: () => _remove(entry.id),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
        ],
        TextField(
          controller: _searchController,
          style: AuraText.body,
          decoration: InputDecoration(hintText: widget.searchHintText),
        ),
        const SizedBox(height: AuraSpace.s8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: _buildList(),
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s12),
        child: Text(
          widget.errorLabel,
          style: AuraText.small.copyWith(color: AuraSurface.coRose),
        ),
      );
    }
    final filtered = _filteredCandidates;
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s12),
        child: Text(
          widget.emptyLabel,
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        final selected = _selectedIds.contains(entry.id);
        return _PickerRow(
          entry: entry,
          selected: selected,
          onTap: () => _toggle(entry),
        );
      },
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final DirectoryEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s8,
        ),
        child: Row(
          children: [
            AuraAvatar(name: entry.displayName, imageUrl: entry.avatarUrl, size: 32),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.displayName, style: AuraText.body),
                  Text(
                    entry.subtitle,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AuraSurface.accentText : AuraSurface.faint,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.label,
    required this.onRemoved,
    this.avatarUrl,
  });

  final String label;
  final String? avatarUrl;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.elevated,
          border: Border.all(color: AuraSurface.divider),
          borderRadius: BorderRadius.circular(AuraRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AuraAvatar(name: label, imageUrl: avatarUrl, size: 20),
            const SizedBox(width: AuraSpace.s8),
            Flexible(
              child: Text(
                label,
                style: AuraText.small,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            InkWell(onTap: onRemoved, child: const Icon(Icons.close, size: 16)),
          ],
        ),
      ),
    );
  }
}
