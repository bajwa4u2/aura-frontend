import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../composition/data/composition_repository.dart';
import '../../composition/domain/composition_models.dart';

class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({
    super.key,
    this.isSharedSpaceMode = false,
    this.initialUserId,
    this.initialHandle,
    this.initialName,
  });

  final bool isSharedSpaceMode;
  final String? initialUserId;
  final String? initialHandle;
  final String? initialName;

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
  bool _initialSelectionApplied = false;
  String? _loadError;
  String? _submitError;
  String _spaceType = 'CIRCLE';

  CompositionReviewResult? _spaceCompositionReview;
  String? _spaceCompositionError;
  bool _spaceCompositionReviewing = false;
  final Set<String> _applyingFindingIds = <String>{};

  Timer? _searchDebounce;

  bool get _isSharedSpaceMode => widget.isSharedSpaceMode;

  List<_DirectoryEntry> get _selectedEntries => _allEntries
      .where((entry) => _selectedIds.contains(entry.id))
      .toList(growable: false);

  int get _selectedMemberCount => _selectedEntries.length;

  bool get _canSubmit {
    if (_submitting || _loading) return false;

    if (_isSharedSpaceMode) {
      return _selectedMemberCount >= 1 &&
          _titleController.text.trim().isNotEmpty;
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
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadDirectory());
    _searchController.addListener(_handleSearchChanged);
    _titleController.addListener(_onDetailsChanged);
    _titleController.addListener(_handleCompositionInputChanged);
    _descriptionController.addListener(_handleCompositionInputChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _titleController.removeListener(_onDetailsChanged);
    _searchController.dispose();
    _titleController.removeListener(_handleCompositionInputChanged);
    _descriptionController.removeListener(_handleCompositionInputChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onDetailsChanged() {
    if (!mounted) return;
    setState(() {});
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

      final relationshipEntries = await _loadRelationshipEntries(
        dio,
        handle: handle,
      );

      final deduped = _dedupeEntries(relationshipEntries)
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

      _applyInitialSelectionIfNeeded();
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
    return _deepFirstMap(res.data);
  }

  Future<List<_DirectoryEntry>> _loadRelationshipEntries(
    Dio dio, {
    required String handle,
  }) async {
    if (handle.trim().isEmpty) return const <_DirectoryEntry>[];

    final results = await Future.wait<List<Map<String, dynamic>>>([
      _fetchDirectoryList(dio, '/users/$handle/followers'),
      _fetchDirectoryList(dio, '/users/$handle/following'),
    ]);

    return results
        .expand((e) => e)
        .map(_memberEntryFromMap)
        .whereType<_DirectoryEntry>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchDirectoryList(
    Dio dio,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await dio.get(path, queryParameters: query);
      return _deepFirstList(res.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403 || status == 404) {
        return const <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRequiredList(
    Dio dio,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await dio.get(path, queryParameters: query);
    return _deepFirstList(res.data);
  }

  void _applyInitialSelectionIfNeeded() {
    if (_initialSelectionApplied || _allEntries.isEmpty) return;

    final wantedUserId = (widget.initialUserId ?? '').trim();
    final wantedHandle = _normalizeHandle(widget.initialHandle);
    final wantedName = (widget.initialName ?? '').trim().toLowerCase();

    _DirectoryEntry? matched;

    for (final entry in _allEntries) {
      final entryHandle = _normalizeHandle(entry.handle);

      final sameUserId =
          wantedUserId.isNotEmpty && entry.userId.trim() == wantedUserId;
      final sameHandle = wantedHandle.isNotEmpty && entryHandle == wantedHandle;
      final sameName = wantedName.isNotEmpty &&
          entry.displayName.trim().toLowerCase() == wantedName;

      if (sameUserId || sameHandle || sameName) {
        matched = entry;
        break;
      }
    }

    _initialSelectionApplied = true;

    if (matched == null) return;

    setState(() {
      if (_isSharedSpaceMode) {
        _selectedIds.add(matched!.id);
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = matched.displayName;
        }
      } else {
        _selectedIds
          ..clear()
          ..add(matched!.id);
      }
    });
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

  void _handleCompositionInputChanged() {
    if (!mounted) return;
    if (_spaceCompositionReview == null && _spaceCompositionError == null) return;
    setState(() {
      _spaceCompositionReview = null;
      _spaceCompositionError = null;
    });
  }

  bool get _canRunCreateCompositionReview {
    if (!_isSharedSpaceMode || _submitting || _loading || _spaceCompositionReviewing) {
      return false;
    }
    return _createSpaceCompositeText().trim().isNotEmpty;
  }

  String _createSpaceCompositeText() {
    return [
      'Title:',
      _titleController.text.trim(),
      '',
      'Description:',
      _descriptionController.text.trim(),
    ].join('\n');
  }

  void _setCreateSpaceCompositeText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    final reg = RegExp(r'Title:\s*\n([\s\S]*?)\n\s*Description:\s*\n([\s\S]*)$', multiLine: true);
    final match = reg.firstMatch(normalized);
    if (match != null) {
      _titleController.text = (match.group(1) ?? '').trim();
      _descriptionController.text = (match.group(2) ?? '').trim();
      return;
    }

    _descriptionController.text = normalized;
  }

  Future<void> _runCreateCompositionReview() async {
    if (!_canRunCreateCompositionReview) return;

    setState(() {
      _spaceCompositionReviewing = true;
      _spaceCompositionError = null;
      _spaceCompositionReview = null;
    });

    try {
      final repo = ref.read(compositionRepositoryProvider);
      final review = await repo.review(
        text: _createSpaceCompositeText(),
        surface: CompositionSurface.space,
      );

      if (!mounted) return;
      setState(() {
        _spaceCompositionReview = review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _spaceCompositionError = 'Review could not be completed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _spaceCompositionReviewing = false);
      }
    }
  }

  Future<void> _applyCreateCompositionFinding(CompositionFinding finding) async {
    final review = _spaceCompositionReview;
    if (review == null || finding.id.trim().isEmpty) return;

    setState(() {
      _applyingFindingIds.add(finding.id);
      _spaceCompositionError = null;
    });

    try {
      final repo = ref.read(compositionRepositoryProvider);
      final applied = await repo.apply(
        sessionId: review.sessionId,
        findingId: finding.id,
        text: _createSpaceCompositeText(),
        surface: CompositionSurface.space,
      );

      if (!mounted) return;
      if (applied.text.trim().isNotEmpty) {
        _setCreateSpaceCompositeText(applied.text);
      }
      setState(() {
        _spaceCompositionReview = applied.review ?? review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _spaceCompositionError = 'Apply failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _applyingFindingIds.remove(finding.id);
        });
      }
    }
  }

  Map<String, List<CompositionFinding>> _groupCreateFindings(
    List<CompositionFinding> findings,
  ) {
    final grouped = <String, List<CompositionFinding>>{};
    for (final finding in findings) {
      grouped.putIfAbsent(finding.chapterLabel, () => <CompositionFinding>[]).add(finding);
    }
    return grouped;
  }

  Widget _buildSpaceCompositionCard() {
    final review = _spaceCompositionReview;
    final grouped = review == null
        ? const <String, List<CompositionFinding>>{}
        : _groupCreateFindings(review.findings);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Composition review',
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      'Review the title and description before creating the space.',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _canRunCreateCompositionReview ? _runCreateCompositionReview : null,
                icon: _spaceCompositionReviewing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_outlined),
                label: Text(_spaceCompositionReviewing ? 'Reviewing...' : 'Review'),
              ),
            ],
          ),
          if (review != null) ...[
            const SizedBox(height: AuraSpace.s10),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                _MetaChip(label: 'Surface: ${review.surface.label}'),
                if (review.intensityLabel.isNotEmpty)
                  _MetaChip(label: 'Intensity: ${review.intensityLabel}'),
                _MetaChip(label: 'Findings: ${review.findings.length}'),
              ],
            ),
          ],
          if ((review?.summary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(review!.summary, style: AuraText.body),
          ],
          if ((_spaceCompositionError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              _spaceCompositionError!,
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
          if (review != null && review.findings.isEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              'No findings returned for this space draft.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          for (final entry in grouped.entries) ...[
            const SizedBox(height: AuraSpace.s12),
            Text(
              entry.key,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AuraSpace.s8),
            for (final finding in entry.value) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AuraSpace.s10),
                padding: const EdgeInsets.all(AuraSpace.s12),
                decoration: BoxDecoration(
                  color: AuraSurface.page,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AuraSpace.s8,
                      runSpacing: AuraSpace.s8,
                      children: [
                        Text(
                          finding.message,
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        _MetaChip(label: finding.stateLabel),
                      ],
                    ),
                    if (finding.suggestion.trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s8),
                      Text(finding.suggestion, style: AuraText.body),
                    ],
                    if (review.allowApply) ...[
                      const SizedBox(height: AuraSpace.s10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _applyingFindingIds.contains(finding.id)
                              ? null
                              : () => _applyCreateCompositionFinding(finding),
                          icon: _applyingFindingIds.contains(finding.id)
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.rule_folder_outlined),
                          label: Text(
                            _applyingFindingIds.contains(finding.id)
                                ? 'Applying...'
                                : (finding.actionLabel.trim().isNotEmpty
                                    ? finding.actionLabel
                                    : 'Apply'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final created = await _createSpaceFromSelection();

      final spaceId = _extractSpaceId(created);
      if (spaceId.isEmpty) {
        throw Exception(
          'Space was created but the response did not return a usable space id.',
        );
      }

      if (_isSharedSpaceMode) {
        if (!mounted) return;
        context.go('/me/correspondence/$spaceId');
        return;
      }

      final member = _selectedEntries.first;
      final threadId = await _ensureDirectThreadId(
        dio,
        createdResponse: created,
        spaceId: spaceId,
        member: member,
      );

      if (!mounted) return;
      context.go('/me/correspondence/$spaceId/thread/$threadId');
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

  Future<String> _ensureDirectThreadId(
    Dio dio, {
    required dynamic createdResponse,
    required String spaceId,
    required _DirectoryEntry member,
  }) async {
    final returnedThreadId = _extractThreadId(createdResponse);
    if (returnedThreadId.isNotEmpty) {
      return returnedThreadId;
    }

    final existingThreads =
        await _fetchRequiredList(dio, '/spaces/$spaceId/threads');
    final preferredExistingThreadId = _pickPreferredThreadId(existingThreads);
    if (preferredExistingThreadId.isNotEmpty) {
      return preferredExistingThreadId;
    }

    final res = await dio.post(
      '/spaces/$spaceId/threads',
      data: <String, dynamic>{
        'title': member.displayName.trim().isEmpty
            ? 'Conversation'
            : member.displayName.trim(),
        'kind': 'DIRECT',
        if (member.userId.trim().isNotEmpty) 'memberIds': [member.userId.trim()],
      },
    );

    final createdThreadId = _extractThreadId(res.data);
    if (createdThreadId.isNotEmpty) {
      return createdThreadId;
    }

    final createdThreadMap = _deepFirstMap(res.data);
    final directId = _pickString(
      createdThreadMap,
      const ['id', '_id', 'threadId'],
    );
    if (directId.isNotEmpty) {
      return directId;
    }

    final refreshedThreads =
        await _fetchRequiredList(dio, '/spaces/$spaceId/threads');
    final preferredRefreshedThreadId = _pickPreferredThreadId(refreshedThreads);
    if (preferredRefreshedThreadId.isNotEmpty) {
      return preferredRefreshedThreadId;
    }

    throw Exception(
      'Conversation space was created, but no usable thread could be opened.',
    );
  }

  String _pickPreferredThreadId(List<Map<String, dynamic>> threads) {
    if (threads.isEmpty) return '';

    for (final thread in threads) {
      final kind = _pickString(thread, const ['kind', 'type']).toUpperCase();
      final id = _pickString(thread, const ['id', '_id', 'threadId']);
      if (id.isNotEmpty && kind == 'DIRECT') {
        return id;
      }
    }

    for (final thread in threads) {
      final id = _pickString(thread, const ['id', '_id', 'threadId']);
      if (id.isNotEmpty) return id;
    }

    return '';
  }

  Future<dynamic> _createSpaceFromSelection() async {
    final dio = ref.read(dioProvider);

    final participantIds = _selectedEntries
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
      final member = _selectedEntries.first;
      payload['title'] = member.displayName;
    }

    final res = await dio.post('/spaces', data: payload);
    return res.data;
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredEntries;
    final pageTitle = _isSharedSpaceMode ? 'Create space' : 'New conversation';

    return AuraScaffold(
      title: pageTitle,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: [
              _LeadCard(
                title: pageTitle,
                subtitle: _isSharedSpaceMode
                    ? 'Select members and set the space.'
                    : 'Select one member.',
              ),
              const SizedBox(height: AuraSpace.s16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 860;
                  final directory = _buildDirectoryCard(context, filteredEntries);
                  final side = _buildSelectionRail(context);

                  if (stacked) {
                    return Column(
                      children: [
                        side,
                        const SizedBox(height: AuraSpace.s14),
                        directory,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: side),
                      const SizedBox(width: AuraSpace.s14),
                      Expanded(flex: 6, child: directory),
                    ],
                  );
                },
              ),
              const SizedBox(height: AuraSpace.s18),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                  child: Text(
                    _submitError!,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.warnInk,
                    ),
                  ),
                ),
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
      ),
    );
  }

  Widget _buildSelectionRail(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSharedSpaceMode ? 'Selection' : 'Conversation',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            _isSharedSpaceMode
                ? '${_selectedMemberCount.toString()} selected'
                : (_selectedEntries.isEmpty ? 'No member selected' : 'One member selected'),
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          if (_selectedEntries.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                for (final entry in _selectedEntries)
                  _SelectedEntryChip(
                    label: entry.displayName,
                    onRemoved: () => _removeSelected(entry.id),
                  ),
              ],
            ),
          ],
          if (_isSharedSpaceMode) ...[
            const SizedBox(height: AuraSpace.s16),
            Container(
              height: 1,
              color: AuraSurface.divider,
            ),
            const SizedBox(height: AuraSpace.s16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            DropdownButtonFormField<String>(
              value: _spaceType,
              decoration: const InputDecoration(
                labelText: 'Type',
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
            const SizedBox(height: AuraSpace.s16),
            _buildSpaceCompositionCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectoryCard(
    BuildContext context,
    List<_DirectoryEntry> filteredEntries,
  ) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Members',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AuraSpace.s12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search members',
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
          const SizedBox(height: AuraSpace.s14),
          if (_loading)
            const _LoadingBlock(label: 'Loading members...')
          else if (_loadError != null)
            _InlineErrorBlock(
              title: 'Could not load members',
              body: _loadError!,
              onRetry: _loadDirectory,
            )
          else if (filteredEntries.isEmpty)
            Text(
              _searchController.text.trim().isEmpty
                  ? 'No members available.'
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
                    onTap: () => _toggleEntry(filteredEntries[i].id),
                    onOpenProfile: filteredEntries[i].profileRoute == null
                        ? null
                        : () => context.push(filteredEntries[i].profileRoute!),
                  ),
                  if (i != filteredEntries.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            subtitle,
            style: AuraText.body.copyWith(color: AuraSurface.muted),
          ),
        ],
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
                  Text(
                    entry.displayName,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    entry.subtitle,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                ],
              ),
            ),
            if (onOpenProfile != null)
              IconButton(
                tooltip: 'Open profile',
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
        color: AuraSurface.elevated,
        border: Border.all(color: AuraSurface.divider),
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

class _DirectoryEntry {
  const _DirectoryEntry({
    required this.id,
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.subtitle,
    required this.avatarLetter,
    required this.profileRoute,
  });

  const _DirectoryEntry.empty()
      : id = '',
        userId = '',
        handle = '',
        displayName = '',
        subtitle = '',
        avatarLetter = '?',
        profileRoute = null;

  final String id;
  final String userId;
  final String handle;
  final String displayName;
  final String subtitle;
  final String avatarLetter;
  final String? profileRoute;
}

_DirectoryEntry? _memberEntryFromMap(Map<String, dynamic> raw) {
  final user = _unwrapNestedUser(raw);

  final id = _pickString(user, const ['id', '_id', 'userId']);
  final handle = _normalizeHandle(
    _pickString(user, const ['handle', 'username']),
  );
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
    userId: id,
    handle: handle,
    displayName: resolvedName,
    subtitle: subtitleParts.isEmpty ? 'Member' : subtitleParts.join(' · '),
    avatarLetter: _avatarLetterFrom(resolvedName),
    profileRoute: handle.isNotEmpty ? '/author/$handle' : null,
  );
}

List<_DirectoryEntry> _dedupeEntries(List<_DirectoryEntry> entries) {
  final byId = <String, _DirectoryEntry>{};

  for (final entry in entries) {
    byId.putIfAbsent(entry.id, () => entry);
  }

  return byId.values.toList(growable: false);
}

Map<String, dynamic> _unwrapNestedUser(Map<String, dynamic> raw) {
  const nestedKeys = [
    'user',
    'profile',
    'member',
    'account',
    'author',
    'follower',
    'following',
  ];

  for (final key in nestedKeys) {
    final value = raw[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
  }

  return raw;
}

Map<String, dynamic> _deepFirstMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    final direct = raw;
    const candidateKeys = [
      'data',
      'item',
      'result',
      'space',
      'thread',
      'payload',
    ];

    for (final key in candidateKeys) {
      final nested = direct[key];
      if (nested is Map) {
        return _deepFirstMap(Map<String, dynamic>.from(nested));
      }
    }

    return direct;
  }

  if (raw is Map) {
    return _deepFirstMap(Map<String, dynamic>.from(raw));
  }

  return <String, dynamic>{};
}

List<Map<String, dynamic>> _deepFirstList(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);

    const candidateKeys = [
      'items',
      'results',
      'list',
      'users',
      'followers',
      'following',
      'threads',
      'data',
    ];

    for (final key in candidateKeys) {
      final value = map[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (value is Map) {
        final nested = _deepFirstList(Map<String, dynamic>.from(value));
        if (nested.isNotEmpty) return nested;
      }
    }
  }

  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  return const <Map<String, dynamic>>[];
}

String _extractSpaceId(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);

    final direct = _pickString(map, const [
      'id',
      '_id',
      'spaceId',
    ]);
    if (direct.isNotEmpty) return direct;

    const nestedKeys = [
      'data',
      'item',
      'result',
      'space',
      'payload',
    ];

    for (final key in nestedKeys) {
      final nested = map[key];
      final candidate = _extractSpaceId(nested);
      if (candidate.isNotEmpty) return candidate;
    }
  }

  if (raw is List) {
    for (final item in raw) {
      final candidate = _extractSpaceId(item);
      if (candidate.isNotEmpty) return candidate;
    }
  }

  return '';
}

String _extractThreadId(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);

    final direct = _pickString(map, const [
      'threadId',
      'defaultThreadId',
      'id',
      '_id',
    ]);
    if (direct.isNotEmpty &&
        (map.containsKey('threadId') ||
            map.containsKey('defaultThreadId') ||
            map.containsKey('thread') ||
            map.containsKey('threads'))) {
      return direct;
    }

    final thread = map['thread'];
    if (thread is Map) {
      final id = _pickString(
        Map<String, dynamic>.from(thread),
        const ['id', '_id', 'threadId'],
      );
      if (id.isNotEmpty) return id;
    }

    final threads = map['threads'];
    if (threads is List && threads.isNotEmpty) {
      final first = threads.first;
      if (first is Map) {
        final id = _pickString(
          Map<String, dynamic>.from(first),
          const ['id', '_id', 'threadId'],
        );
        if (id.isNotEmpty) return id;
      }
    }

    const nestedKeys = [
      'data',
      'item',
      'result',
      'payload',
      'space',
    ];

    for (final key in nestedKeys) {
      final nested = map[key];
      final candidate = _extractThreadId(nested);
      if (candidate.isNotEmpty) return candidate;
    }
  }

  if (raw is List) {
    for (final item in raw) {
      final candidate = _extractThreadId(item);
      if (candidate.isNotEmpty) return candidate;
    }
  }

  return '';
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

String _normalizeHandle(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return '';
  return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
}
