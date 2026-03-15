import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key});

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final Set<String> _selectedIds = <String>{};

  List<_DirectoryEntry> _allEntries = const [];
  bool _loading = true;
  bool _searching = false;
  bool _submitting = false;
  String? _loadError;
  String? _submitError;
  String _spaceType = 'CIRCLE';

  Timer? _searchDebounce;

  bool get _isSharedSpaceMode {
    final location = GoRouterState.of(context).uri.toString().toLowerCase();
    return location.contains('/create/space');
  }

  List<_DirectoryEntry> get _selectedEntries => _allEntries
      .where((entry) => _selectedIds.contains(entry.id))
      .toList(growable: false);

  int get _selectedMemberCount =>
      _selectedEntries.where((e) => e.kind == _EntryKind.member).length;

  int get _selectedInstitutionCount =>
      _selectedEntries.where((e) => e.kind == _EntryKind.institution).length;

  bool get _canSubmit {
    if (_submitting || _loading) return false;

    if (_isSharedSpaceMode) {
      return _selectedMemberCount >= 1 && _titleController.text.trim().isNotEmpty;
    }

    return _selectedMemberCount == 1;
  }

  List<_DirectoryEntry> get _filteredEntries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allEntries;

    return _allEntries.where((entry) {
      final haystack = [
        entry.displayName,
        entry.subtitle,
        entry.kindLabel,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadDirectory());
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();

    setState(() => _searching = true);

    _searchDebounce = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() => _searching = false);
    });
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final me = await _loadMe(dio);
      final handle = _pickString(me, const ['handle', 'username']);

      final results = await Future.wait<List<_DirectoryEntry>>([
        _loadRelationshipEntries(dio, handle: handle),
        _loadInstitutionEntries(dio),
      ]);

      final merged = results.expand((e) => e).toList();
      final deduped = _dedupeEntries(merged)
        ..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
                b.displayName.toLowerCase(),
              ),
        );

      if (!mounted) return;
      setState(() {
        _allEntries = deduped;
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

  Future<Map<String, dynamic>> _loadMe(Dio dio) async {
    final res = await dio.get('/users/me');
    final raw = _asMap(res.data);
    return _unwrapMap(raw);
  }

  Future<List<_DirectoryEntry>> _loadRelationshipEntries(
    Dio dio, {
    required String handle,
  }) async {
    if (handle.trim().isEmpty) return const <_DirectoryEntry>[];

    final results = await Future.wait<List<Map<String, dynamic>>>([
      _fetchList(dio, '/users/$handle/followers'),
      _fetchList(dio, '/users/$handle/following'),
    ]);

    return results
        .expand((e) => e)
        .map(_memberEntryFromMap)
        .whereType<_DirectoryEntry>()
        .toList();
  }

  Future<List<_DirectoryEntry>> _loadInstitutionEntries(Dio dio) async {
    final candidates = <Future<List<Map<String, dynamic>>>>[
      _fetchList(dio, '/institutions', query: const {'limit': 20}),
      _fetchList(dio, '/institutions/search', query: const {'limit': 20}),
      _fetchList(dio, '/institution/search', query: const {'limit': 20}),
    ];

    for (final future in candidates) {
      try {
        final items = await future;
        if (items.isNotEmpty) {
          return items
              .map(_institutionEntryFromMap)
              .whereType<_DirectoryEntry>()
              .toList();
        }
      } catch (_) {}
    }

    return const <_DirectoryEntry>[];
  }

  Future<List<Map<String, dynamic>>> _fetchList(
    Dio dio,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await dio.get(path, queryParameters: query);
      return _unwrapItems(_asMap(res.data));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403 || status == 404) {
        return const <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  void _toggleEntry(String id) {
    final tapped = _allEntries.firstWhere(
      (entry) => entry.id == id,
      orElse: () => const _DirectoryEntry.empty(),
    );

    if (tapped.id.isEmpty) return;

    setState(() {
      _submitError = null;

      if (_isSharedSpaceMode) {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      } else {
        if (tapped.kind != _EntryKind.member) return;

        if (_selectedIds.contains(id)) {
          _selectedIds.clear();
        } else {
          _selectedIds
            ..clear()
            ..add(id);
        }
      }
    });
  }

  void _removeSelected(String id) {
    setState(() {
      _selectedIds.remove(id);
      _submitError = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final space = await _createSpaceFromSelection();
      final spaceId = _pickString(space, const ['id', 'spaceId', '_id']);
      final threadId = _pickDefaultThreadId(space);

      if (!mounted) return;

      if (spaceId.isEmpty) {
        context.go('/me/correspondence');
        return;
      }

      if (threadId.isNotEmpty) {
        context.go('/me/correspondence/$spaceId/thread/$threadId');
      } else {
        context.go('/me/correspondence/$spaceId');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<Map<String, dynamic>> _createSpaceFromSelection() async {
    final dio = ref.read(dioProvider);

    final selectedMembers =
        _selectedEntries.where((e) => e.kind == _EntryKind.member).toList();

    final participantIds = selectedMembers
        .map((e) => e.userId)
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (!_isSharedSpaceMode && participantIds.length != 1) {
      throw Exception('A direct conversation requires exactly one member.');
    }

    if (_isSharedSpaceMode && participantIds.isEmpty) {
      throw Exception('Select at least one member to create a space.');
    }

    final payload = <String, dynamic>{
      'type': _isSharedSpaceMode ? _spaceType : 'PRIVATE',
      'visibility': 'PRIVATE',
      'participantIds': participantIds,
    };

    if (_isSharedSpaceMode) {
      payload['title'] = _titleController.text.trim();
      if (_descriptionController.text.trim().isNotEmpty) {
        payload['description'] = _descriptionController.text.trim();
      }
    } else {
      final member = selectedMembers.first;
      payload['title'] = member.displayName;
    }

    final res = await dio.post('/spaces', data: payload);
    return _unwrapMap(_asMap(res.data));
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredEntries;
    final pageTitle = _isSharedSpaceMode ? 'Create space' : 'New conversation';
    final pageBody = _isSharedSpaceMode
        ? 'Choose members, then define the shared space.'
        : 'Choose one member to begin a private conversation.';

    return AuraScaffold(
      title: pageTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _PageIntro(
            title: pageTitle,
            body: pageBody,
          ),
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: _isSharedSpaceMode
                        ? 'Search members or institutions'
                        : 'Search members',
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_searchController.text.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              )),
                  ),
                ),
                if (_selectedEntries.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s14),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      for (final entry in _selectedEntries)
                        _SelectedEntryChip(
                          label: entry.displayName,
                          kindLabel: entry.kindLabel,
                          onRemoved: () => _removeSelected(entry.id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          if (_isSharedSpaceMode) ...[
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Space details', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Space title',
                      hintText: 'Research Circle, Studio, Family',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Optional context',
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  DropdownButtonFormField<String>(
                    value: _spaceType,
                    decoration: const InputDecoration(
                      labelText: 'Space type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'CIRCLE',
                        child: Text('Circle'),
                      ),
                      DropdownMenuItem(
                        value: 'STUDIO',
                        child: Text('Studio'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _spaceType = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s14),
          ],
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSharedSpaceMode ? 'Directory' : 'Members',
                  style: AuraText.title,
                ),
                const SizedBox(height: AuraSpace.s10),
                if (_loading)
                  const _LoadingBlock(label: 'Loading directory...')
                else if (_loadError != null)
                  _InlineErrorBlock(
                    title: 'Could not load directory',
                    body: _loadError!,
                    onRetry: _loadDirectory,
                  )
                else if (filteredEntries.isEmpty)
                  Text(
                    _searchController.text.trim().isEmpty
                        ? (_isSharedSpaceMode
                            ? 'No members or institutions available yet.'
                            : 'No members available yet.')
                        : 'No matches found.',
                    style: AuraText.body,
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < filteredEntries.length; i++) ...[
                        _DirectoryRow(
                          entry: filteredEntries[i],
                          selected: _selectedIds.contains(filteredEntries[i].id),
                          allowMultiSelect: _isSharedSpaceMode,
                          allowInstitutionSelection: _isSharedSpaceMode,
                          onTap: () => _toggleEntry(filteredEntries[i].id),
                          onOpenProfile: filteredEntries[i].profileRoute == null
                              ? null
                              : () => context.go(filteredEntries[i].profileRoute!),
                        ),
                        if (i != filteredEntries.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                if (_submitError != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Text(
                    _submitError!,
                    style: AuraText.small.copyWith(
                      color: Colors.red.shade700,
                    ),
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
                            ? 'Create space'
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

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s6),
        Text(body, style: AuraText.body),
      ],
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({
    required this.entry,
    required this.selected,
    required this.allowMultiSelect,
    required this.allowInstitutionSelection,
    required this.onTap,
    required this.onOpenProfile,
  });

  final _DirectoryEntry entry;
  final bool selected;
  final bool allowMultiSelect;
  final bool allowInstitutionSelection;
  final VoidCallback onTap;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final selectable =
        allowInstitutionSelection || entry.kind == _EntryKind.member;

    final trailing = !selectable
        ? const SizedBox(width: 20)
        : allowMultiSelect
            ? Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
              )
            : Radio<bool>(
                value: true,
                groupValue: selected,
                onChanged: (_) => onTap(),
              );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: selectable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(
                entry.avatarLetter,
                style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.displayName,
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      _KindPill(label: entry.kindLabel),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s4),
                  Text(entry.subtitle, style: AuraText.small),
                ],
              ),
            ),
            if (onOpenProfile != null)
              IconButton(
                tooltip: 'Open',
                onPressed: onOpenProfile,
                icon: const Icon(Icons.north_east, size: 18),
              ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SelectedEntryChip extends StatelessWidget {
  const _SelectedEntryChip({
    required this.label,
    required this.kindLabel,
    required this.onRemoved,
  });

  final String label;
  final String kindLabel;
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
          Text('$kindLabel · $label', style: AuraText.small),
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

class _KindPill extends StatelessWidget {
  const _KindPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: AuraSpace.s4,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AuraSpace.s10),
        Text(label, style: AuraText.body),
      ],
    );
  }
}

class _InlineErrorBlock extends StatelessWidget {
  const _InlineErrorBlock({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AuraSpace.s6),
        Text(body, style: AuraText.small),
        const SizedBox(height: AuraSpace.s10),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

enum _EntryKind {
  member,
  institution,
}

class _DirectoryEntry {
  const _DirectoryEntry({
    required this.id,
    required this.kind,
    required this.userId,
    required this.displayName,
    required this.subtitle,
    required this.avatarLetter,
    required this.profileRoute,
  });

  const _DirectoryEntry.empty()
      : id = '',
        kind = _EntryKind.member,
        userId = '',
        displayName = '',
        subtitle = '',
        avatarLetter = '?',
        profileRoute = null;

  final String id;
  final _EntryKind kind;
  final String userId;
  final String displayName;
  final String subtitle;
  final String avatarLetter;
  final String? profileRoute;

  String get kindLabel => kind == _EntryKind.member ? 'Member' : 'Institution';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapMap(Map<String, dynamic> raw) {
  final direct = raw['item'] ?? raw['data'] ?? raw['result'];
  if (direct is Map) return Map<String, dynamic>.from(direct);
  return raw;
}

List<Map<String, dynamic>> _unwrapItems(Map<String, dynamic> raw) {
  final candidates = [
    raw['items'],
    raw['results'],
    raw['data'],
    raw['list'],
  ];

  for (final candidate in candidates) {
    if (candidate is List) {
      return candidate
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  if (raw.isNotEmpty &&
      !raw.containsKey('items') &&
      !raw.containsKey('results') &&
      !raw.containsKey('data') &&
      !raw.containsKey('list')) {
    return [raw];
  }

  return const [];
}

Map<String, dynamic> _unwrapNestedUser(Map<String, dynamic> raw) {
  const nestedKeys = [
    'user',
    'profile',
    'member',
    'account',
    'author',
  ];

  for (final key in nestedKeys) {
    final value = raw[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
  }

  return raw;
}

_DirectoryEntry? _memberEntryFromMap(Map<String, dynamic> raw) {
  final user = _unwrapNestedUser(raw);

  final id = _pickString(user, const ['id', '_id', 'userId']);
  final handle = _pickString(user, const ['handle', 'username']);
  final displayName = _pickString(
    user,
    const ['displayName', 'name', 'fullName', 'title'],
  );

  if (id.isEmpty && handle.isEmpty && displayName.isEmpty) return null;

  final resolvedName = displayName.isNotEmpty
      ? displayName
      : (handle.isNotEmpty ? handle : 'Member');

  final subtitleParts = <String>[];
  if (handle.isNotEmpty) subtitleParts.add('@$handle');

  final bio = _pickString(user, const ['bio', 'headline', 'summary']);
  if (bio.isNotEmpty) subtitleParts.add(bio);

  return _DirectoryEntry(
    id: 'member:${id.isNotEmpty ? id : handle}',
    kind: _EntryKind.member,
    userId: id,
    displayName: resolvedName,
    subtitle: subtitleParts.isEmpty ? 'Member' : subtitleParts.join(' · '),
    avatarLetter: _avatarLetterFrom(resolvedName),
    profileRoute: handle.isNotEmpty ? '/author/$handle' : null,
  );
}

_DirectoryEntry? _institutionEntryFromMap(Map<String, dynamic> raw) {
  final item = _unwrapNestedUser(raw);

  final id = _pickString(item, const ['id', '_id', 'institutionId']);
  final slug = _pickString(item, const ['slug', 'handle']);
  final name = _pickString(item, const ['name', 'title', 'displayName']);

  if (id.isEmpty && slug.isEmpty && name.isEmpty) return null;

  final resolvedName = name.isNotEmpty ? name : (slug.isNotEmpty ? slug : 'Institution');

  final subtitleParts = <String>[];
  final kind = _pickString(item, const ['kind', 'type']);
  if (kind.isNotEmpty) subtitleParts.add(kind);
  final description = _pickString(item, const ['description', 'bio', 'summary']);
  if (description.isNotEmpty) subtitleParts.add(description);

  return _DirectoryEntry(
    id: 'institution:${id.isNotEmpty ? id : slug}',
    kind: _EntryKind.institution,
    userId: id,
    displayName: resolvedName,
    subtitle: subtitleParts.isEmpty ? 'Institution' : subtitleParts.join(' · '),
    avatarLetter: _avatarLetterFrom(resolvedName),
    profileRoute: slug.isNotEmpty ? '/institutions/$slug' : null,
  );
}

List<_DirectoryEntry> _dedupeEntries(List<_DirectoryEntry> entries) {
  final byId = <String, _DirectoryEntry>{};

  for (final entry in entries) {
    byId.putIfAbsent(entry.id, () => entry);
  }

  return byId.values.toList(growable: false);
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _avatarLetterFrom(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

String _pickDefaultThreadId(Map<String, dynamic> map) {
  final threads = map['threads'];
  if (threads is List && threads.isNotEmpty) {
    final first = threads.first;
    if (first is Map) {
      return _pickString(Map<String, dynamic>.from(first), const ['id', '_id']);
    }
  }

  return _pickString(map, const ['threadId', 'defaultThreadId']);
}