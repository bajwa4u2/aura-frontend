import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/net/dio_provider.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_scaffold.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';

class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key});

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState
    extends ConsumerState<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final Set<String> _selectedIds = <String>{};

  Timer? _debounce;
  bool _loading = true;
  bool _searching = false;
  bool _submitting = false;
  String? _loadError;
  String? _submitError;

  String _spaceType = 'CIRCLE';

  List<_DirectoryEntry> _allEntries = const <_DirectoryEntry>[];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDirectory();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isSharedSpaceMode {
    final location = GoRouterState.of(context).uri.toString();
    return location.contains('/create/space');
  }

  String get _pageTitle =>
      _isSharedSpaceMode ? 'Create space' : 'New conversation';

  String get _pageBody => _isSharedSpaceMode
      ? 'Bring people into a durable shared place.'
      : 'Start a direct conversation by creating a private space with one member.';

  List<_DirectoryEntry> get _selectedEntries {
    final selected = _allEntries.where((e) => _selectedIds.contains(e.id)).toList();
    selected.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
    );
    return selected;
  }

  List<_DirectoryEntry> get _filteredEntries {
    final q = _searchController.text.trim().toLowerCase();

    return _allEntries.where((entry) {
      if (q.isEmpty) return true;
      return entry.displayName.toLowerCase().contains(q) ||
          entry.handle.toLowerCase().contains(q) ||
          entry.subtitle.toLowerCase().contains(q) ||
          entry.searchBlob.toLowerCase().contains(q);
    }).toList();
  }

  int get _selectedMemberCount =>
      _selectedEntries.where((e) => e.kind == _EntryKind.member).length;

  int get _selectedInstitutionCount =>
      _selectedEntries.where((e) => e.kind == _EntryKind.institution).length;

  bool get _canSubmit {
    if (_submitting) return false;

    if (_isSharedSpaceMode) {
      return _selectedMemberCount >= 1 &&
          _titleController.text.trim().isNotEmpty;
    }

    return _selectedMemberCount == 1;
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    setState(() => _searching = true);

    _debounce = Timer(const Duration(milliseconds: 220), () {
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
      'participantIds': participantIds,
      if (_isSharedSpaceMode) 'title': _titleController.text.trim(),
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
    };

    final res = await dio.post('/spaces', data: payload);
    final raw = _asMap(res.data);
    final created = _unwrapMap(raw);

    final spaceId = _pickString(created, const ['id', 'spaceId', '_id']);
    if (spaceId.isEmpty) {
      throw Exception('Space was created but no space id was returned.');
    }

    return created;
  }

  void _toggleEntry(String id) {
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
    final selectedEntries = _selectedEntries;
    final filteredEntries = _filteredEntries;

    return AuraScaffold(
      title: _pageTitle,
      body: RefreshIndicator(
        onRefresh: _loadDirectory,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_pageTitle, style: AuraText.title),
                  const SizedBox(height: AuraSpace.s8),
                  Text(_pageBody, style: AuraText.body),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s14),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSharedSpaceMode ? 'Participants' : 'Member',
                    style: AuraText.title,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search name, handle, or institution',
                      labelText: 'Search',
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
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
                    onChanged: (_) => setState(() {}),
                  ),
                  if (selectedEntries.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s14),
                    Wrap(
                      spacing: AuraSpace.s8,
                      runSpacing: AuraSpace.s8,
                      children: [
                        for (final entry in selectedEntries)
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
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Directory', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  if (_loading)
                    const _LoadingBlock(label: 'Loading people and institutions...')
                  else if (_loadError != null)
                    _InlineErrorBlock(
                      title: 'Could not load directory',
                      body: _loadError!,
                      onRetry: _loadDirectory,
                    )
                  else if (filteredEntries.isEmpty)
                    const _EmptyStateBlock(
                      title: 'No matching results',
                      body: 'Try another name, handle, or institution.',
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < filteredEntries.length; i++) ...[
                          _DirectoryRow(
                            entry: filteredEntries[i],
                            selected: _selectedIds.contains(filteredEntries[i].id),
                            allowMultiSelect: _isSharedSpaceMode,
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
                  const SizedBox(height: AuraSpace.s10),
                  if (_isSharedSpaceMode) ...[
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
                  ] else ...[
                    const _MetaRow(
                      label: 'Type',
                      value: 'Private space',
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    _MetaRow(
                      label: 'Members',
                      value: '$_selectedMemberCount',
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    _MetaRow(
                      label: 'Institutions',
                      value: '$_selectedInstitutionCount',
                    ),
                  ],
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
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({
    required this.entry,
    required this.selected,
    required this.allowMultiSelect,
    required this.onTap,
    required this.onOpenProfile,
  });

  final _DirectoryEntry entry;
  final bool selected;
  final bool allowMultiSelect;
  final VoidCallback onTap;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final trailing = allowMultiSelect
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
      onTap: onTap,
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({
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
        Expanded(child: Text(value, style: AuraText.body)),
      ],
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
        Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AuraSpace.s6),
        Text(body, style: AuraText.small),
        const SizedBox(height: AuraSpace.s12),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _EmptyStateBlock extends StatelessWidget {
  const _EmptyStateBlock({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AuraSpace.s6),
          Text(body, style: AuraText.small),
        ],
      ),
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
    required this.displayName,
    required this.handle,
    required this.subtitle,
    required this.searchBlob,
    required this.userId,
    required this.profileRoute,
  });

  final String id;
  final _EntryKind kind;
  final String displayName;
  final String handle;
  final String subtitle;
  final String searchBlob;
  final String userId;
  final String? profileRoute;

  String get kindLabel => kind == _EntryKind.member ? 'Member' : 'Institution';

  String get avatarLetter {
    final source =
        displayName.trim().isNotEmpty ? displayName.trim() : handle.trim();
    if (source.isEmpty) return '?';
    return source.characters.first.toUpperCase();
  }
}

_DirectoryEntry? _memberEntryFromMap(Map<String, dynamic> item) {
  final user = _unwrapNestedUser(item);
  final userId = _pickString(user, const ['id', 'userId', '_id']);
  final handle = _cleanHandle(
    _pickString(user, const ['handle', 'username', 'userHandle']),
  );
  final displayName = _pickString(
    user,
    const ['displayName', 'fullName', 'name', 'username', 'handle'],
  );

  if (userId.isEmpty && handle.isEmpty && displayName.isEmpty) {
    return null;
  }

  final relationship = _pickString(
    item,
    const ['state', 'relationship', 'followState', 'status'],
  );

  final subtitleParts = <String>[
    if (handle.isNotEmpty) '@$handle',
    if (relationship.isNotEmpty) relationship.replaceAll('_', ' '),
  ];

  return _DirectoryEntry(
    id: userId.isNotEmpty ? 'member:$userId' : 'member:$handle',
    kind: _EntryKind.member,
    displayName: displayName.isEmpty ? handle : displayName,
    handle: handle,
    subtitle: subtitleParts.join(' · '),
    searchBlob: [displayName, handle, relationship].join(' '),
    userId: userId,
    profileRoute: handle.isEmpty ? null : '/u/$handle',
  );
}

_DirectoryEntry? _institutionEntryFromMap(Map<String, dynamic> item) {
  final id = _pickString(item, const ['id', 'institutionId', '_id']);
  final slug = _pickString(item, const ['slug', 'handle', 'username']);
  final name = _pickString(item, const ['name', 'displayName', 'title']);
  final subtitle = _pickString(
    item,
    const ['tagline', 'description', 'summary', 'type'],
  );

  if (id.isEmpty && slug.isEmpty && name.isEmpty) {
    return null;
  }

  return _DirectoryEntry(
    id: id.isNotEmpty ? 'institution:$id' : 'institution:$slug',
    kind: _EntryKind.institution,
    displayName: name.isEmpty ? slug : name,
    handle: _cleanHandle(slug),
    subtitle: subtitle.isEmpty ? 'Institution' : subtitle,
    searchBlob: [name, slug, subtitle].join(' '),
    userId: '',
    profileRoute: null,
  );
}

List<_DirectoryEntry> _dedupeEntries(List<_DirectoryEntry> entries) {
  final byId = <String, _DirectoryEntry>{};
  for (final entry in entries) {
    byId[entry.id] = entry;
  }
  return byId.values.toList();
}

String _pickDefaultThreadId(Map<String, dynamic> space) {
  const possibleListKeys = [
    'threads',
    'threadList',
    'items',
  ];

  for (final key in possibleListKeys) {
    final value = space[key];
    if (value is List && value.isNotEmpty) {
      for (final item in value) {
        if (item is Map) {
          final threadId = _pickString(
            Map<String, dynamic>.from(item),
            const ['id', 'threadId', '_id'],
          );
          if (threadId.isNotEmpty) return threadId;
        }
      }
    }
  }

  final nestedThread = space['defaultThread'];
  if (nestedThread is Map) {
    final threadId = _pickString(
      Map<String, dynamic>.from(nestedThread),
      const ['id', 'threadId', '_id'],
    );
    if (threadId.isNotEmpty) return threadId;
  }

  return _pickString(space, const ['defaultThreadId', 'threadId']);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapMap(Map<String, dynamic> raw) {
  final data = raw['data'];

  if (data is Map<String, dynamic>) {
    if (data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return data;
  }

  if (data is Map) {
    final mapped = Map<String, dynamic>.from(data);
    if (mapped['data'] is Map) {
      return Map<String, dynamic>.from(mapped['data'] as Map);
    }
    return mapped;
  }

  return raw;
}

List<Map<String, dynamic>> _unwrapItems(Map<String, dynamic> raw) {
  dynamic current = raw;

  if (current['data'] is Map) current = current['data'];
  if (current is Map && current['items'] is List) {
    return (current['items'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (current is Map && current['data'] is List) {
    return (current['data'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (current is Map && current['results'] is List) {
    return (current['results'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (raw['items'] is List) {
    return (raw['items'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (raw['data'] is List) {
    return (raw['data'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _unwrapNestedUser(Map<String, dynamic> item) {
  const nestedKeys = [
    'user',
    'member',
    'profile',
    'author',
    'follower',
    'following',
  ];

  for (final key in nestedKeys) {
    final value = item[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }

  return item;
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _cleanHandle(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
}