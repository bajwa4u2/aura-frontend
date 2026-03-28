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
  final Set<String> _applyingSuggestionIds = <String>{};
  final Set<String> _dismissedSuggestionIds = <String>{};

  List<_DirectoryEntry> _relationshipEntries = const [];
  List<_DirectoryEntry> _searchEntries = const [];
  List<_DirectoryEntry> _allEntries = const [];
  bool _loading = true;
  bool _searching = false;
  bool _submitting = false;
  bool _initialSelectionApplied = false;
  String? _loadError;
  String? _submitError;
  String _spaceType = 'CIRCLE';

  Timer? _searchDebounce;
  Timer? _suggestionDebounce;

  bool _suggestionsBusy = false;
  String? _suggestionsError;
  CompositionReviewResult? _spaceSuggestions;
  String? _reviewedSnapshot;

  bool _translationBusy = false;
  String? _translationError;
  String _translationTargetLanguage = 'ur';
  CompositionTranslationResult? _translationPreview;
  String? _translationSourceSnapshot;

  String? _currentUserId;
  String? _currentUserHandle;

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

  List<CompositionSuggestion> get _visibleSuggestions {
    final review = _spaceSuggestions;
    if (review == null) return const [];

    final out = <CompositionSuggestion>[];
    for (final suggestion in review.suggestions) {
      if (_dismissedSuggestionIds.contains(suggestion.id)) continue;
      out.add(suggestion);
      if (out.length >= 2) break;
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadDirectory());
    _searchController.addListener(_handleSearchChanged);
    _titleController.addListener(_onSpaceDraftChanged);
    _descriptionController.addListener(_onSpaceDraftChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _suggestionDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _titleController.removeListener(_onSpaceDraftChanged);
    _descriptionController.removeListener(_onSpaceDraftChanged);
    _searchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onSpaceDraftChanged() {
    if (!mounted || !_isSharedSpaceMode) return;

    final current = _spaceDraftText();

    if (_reviewedSnapshot != null &&
        _normalizeText(_reviewedSnapshot!) != _normalizeText(current)) {
      setState(() {
        _spaceSuggestions = null;
        _suggestionsError = null;
        _dismissedSuggestionIds.clear();
      });
    }

    if (_translationSourceSnapshot != null &&
        _normalizeText(_translationSourceSnapshot!) != _normalizeText(current)) {
      setState(() {
        _translationPreview = null;
        _translationError = null;
      });
    }

    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 550), () {
      if (!mounted || !_isSharedSpaceMode) return;
      if (_spaceDraftText().trim().isEmpty) return;
      unawaited(_refreshSuggestions(silent: true));
    });

    if (mounted) setState(() {});
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();

    final query = _searchController.text.trim();

    setState(() => _searching = query.isNotEmpty);

    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      unawaited(_runMemberSearch(query));
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

      final meId = _pickString(me, const ['id', 'userId']);
      final meHandle = _normalizeHandle(_pickString(me, const ['handle', 'username']));

      if (!mounted) return;

      setState(() {
        _currentUserId = meId.isEmpty ? null : meId;
        _currentUserHandle = meHandle.isEmpty ? null : meHandle;
        _relationshipEntries = deduped;
        _searchEntries = const [];
        _allEntries = _mergeEntries(_relationshipEntries, _searchEntries);
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
      return _deepListOfMaps(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const <Map<String, dynamic>>[];
      rethrow;
    }
  }

  Future<void> _runMemberSearch(String rawQuery) async {
    final query = rawQuery.trim();

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchEntries = const [];
        _allEntries = _mergeEntries(_relationshipEntries, _searchEntries);
        _searching = false;
      });
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/search',
        queryParameters: {
          'q': query,
          'limit': 12,
        },
      );

      final root = _firstMap(response.data);
      final data = _firstMap(root['data']);
      final users = _deepListOfMaps(data['users']);

      final found = users
          .map(_memberEntryFromMap)
          .whereType<_DirectoryEntry>()
          .where((entry) {
            final sameId = (_currentUserId ?? '').isNotEmpty &&
                entry.userId.trim() == (_currentUserId ?? '');
            final sameHandle = (_currentUserHandle ?? '').isNotEmpty &&
                _normalizeHandle(entry.handle) == (_currentUserHandle ?? '');
            return !sameId && !sameHandle;
          })
          .toList(growable: false);

      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _searchEntries = found;
        _allEntries = _mergeEntries(_relationshipEntries, _searchEntries);
        _searching = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _searchEntries = const [];
        _allEntries = _mergeEntries(_relationshipEntries, _searchEntries);
        _searching = false;
        _loadError = 'Aura member search could not be loaded: $e';
      });
    }
  }

  List<_DirectoryEntry> _mergeEntries(
    List<_DirectoryEntry> primary,
    List<_DirectoryEntry> secondary,
  ) {
    return _dedupeEntries([
      ...primary,
      ...secondary,
    ]);
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

  String _spaceDraftText() {
    return [
      'Title:',
      _titleController.text.trim(),
      '',
      'Description:',
      _descriptionController.text.trim(),
    ].join('\n');
  }

  void _applySpaceDraftText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    final reg = RegExp(
      r'Title:\s*\n([\s\S]*?)\n\s*Description:\s*\n([\s\S]*)$',
      multiLine: true,
    );
    final match = reg.firstMatch(normalized);

    if (match != null) {
      final title = (match.group(1) ?? '').trim();
      final description = (match.group(2) ?? '').trim();
      _replaceControllerText(_titleController, title);
      _replaceControllerText(_descriptionController, description);
      return;
    }

    _replaceControllerText(_descriptionController, normalized);
  }

  Future<void> _refreshSuggestions({bool silent = false}) async {
    if (!_isSharedSpaceMode) return;

    final draft = _spaceDraftText();
    if (draft.trim().isEmpty) return;

    if (!silent) {
      setState(() {
        _suggestionsBusy = true;
        _suggestionsError = null;
      });
    } else if (!_suggestionsBusy) {
      setState(() {
        _suggestionsBusy = true;
      });
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/v1/composition/review',
        data: {
          'text': draft,
          'surface': 'space',
        },
      );

      final parsed = _parseLightReview(_firstMap(response.data));
      if (!mounted) return;
      setState(() {
        _spaceSuggestions = parsed;
        _reviewedSnapshot = draft;
        _dismissedSuggestionIds.clear();
        _suggestionsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestionsError = silent ? null : 'Suggestions could not be loaded: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _suggestionsBusy = false;
      });
    }
  }

  Future<void> _applySuggestion(CompositionSuggestion suggestion) async {
    final review = _spaceSuggestions;
    if (review == null || suggestion.id.trim().isEmpty) return;

    final currentDraft = _spaceDraftText();

    setState(() {
      _applyingSuggestionIds.add(suggestion.id);
      _submitError = null;
      _suggestionsError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/v1/composition/apply',
        data: {
          'sessionId': review.sessionId,
          'findingId': suggestion.id,
          'currentText': currentDraft,
        },
      );

      final root = _firstMap(response.data);
      final nextText = _firstNonEmptyString(root, const [
        ['text'],
        ['updatedText'],
        ['resultText'],
        ['revisedText'],
        ['content'],
        ['data', 'text'],
        ['data', 'updatedText'],
      ]);

      if (nextText.trim().isNotEmpty) {
        _applySpaceDraftText(nextText);
      }

      final refreshed = _safeParseLightReview(root);

      if (!mounted) return;
      setState(() {
        _reviewedSnapshot = _spaceDraftText();
        if (refreshed != null) {
          _spaceSuggestions = refreshed;
          _dismissedSuggestionIds.clear();
        } else {
          _dismissedSuggestionIds.add(suggestion.id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestionsError = 'Suggestion could not be applied: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _applyingSuggestionIds.remove(suggestion.id);
      });
    }
  }

  void _dismissSuggestion(String id) {
    setState(() {
      _dismissedSuggestionIds.add(id);
    });
  }

  Future<void> _translateDraft() async {
    if (!_isSharedSpaceMode) return;

    final draft = _spaceDraftText();
    if (draft.trim().isEmpty) return;

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/v1/composition/translate',
        data: {
          'text': draft,
          'targetLanguage': _translationTargetLanguage,
        },
      );

      final root = _firstMap(response.data);
      final translatedText = _firstNonEmptyString(root, const [
        ['translatedText'],
        ['text'],
        ['translation'],
        ['data', 'translatedText'],
        ['data', 'text'],
      ]);

      if (!mounted) return;
      setState(() {
        _translationPreview = CompositionTranslationResult(
          translatedText: translatedText,
          targetLanguage: _translationTargetLanguage,
        );
        _translationSourceSnapshot = draft;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translationError = 'Translation could not be prepared: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _translationBusy = false;
      });
    }
  }

  void _applyTranslation() {
    final preview = _translationPreview;
    if (preview == null || preview.translatedText.trim().isEmpty) return;

    _applySpaceDraftText(preview.translatedText);
    setState(() {
      _translationSourceSnapshot = _spaceDraftText();
      _translationPreview = null;
      _suggestionsError = null;
      _spaceSuggestions = null;
      _dismissedSuggestionIds.clear();
      _reviewedSnapshot = null;
    });
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
            _isSharedSpaceMode ? 'Selection' : 'Member',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            _isSharedSpaceMode
                ? 'Choose who belongs in this space and set its details.'
                : 'Choose the member you want to write to.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s14),
          if (_selectedEntries.isEmpty)
            Text(
              _isSharedSpaceMode
                  ? 'No members selected yet.'
                  : 'No member selected yet.',
              style: AuraText.body,
            )
          else
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                for (final entry in _selectedEntries)
                  _SelectedChip(
                    label: entry.displayName,
                    onRemoved: () => _removeSelected(entry.id),
                  ),
              ],
            ),
          if (_isSharedSpaceMode) ...[
            const SizedBox(height: AuraSpace.s16),
            Container(height: 1, color: AuraSurface.divider),
            const SizedBox(height: AuraSpace.s16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: AuraSpace.s12),
            DropdownButtonFormField<String>(
              value: _spaceType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'CIRCLE', child: Text('Circle')),
                DropdownMenuItem(value: 'WORKROOM', child: Text('Workroom')),
                DropdownMenuItem(value: 'SALON', child: Text('Salon')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _spaceType = value);
              },
            ),
            const SizedBox(height: AuraSpace.s16),
            _buildWritingAssistCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildWritingAssistCard() {
    final suggestions = _visibleSuggestions;
    final hasDraft = _spaceDraftText().trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuraSurface.divider),
      ),
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
                      'Writing assist',
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    Text(
                      'Light suggestions only. Writing stays here.',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: hasDraft && !_suggestionsBusy ? () => _refreshSuggestions() : null,
                icon: _suggestionsBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_outlined),
                label: Text(_suggestionsBusy ? 'Checking...' : 'Check'),
              ),
            ],
          ),
          if ((_suggestionsError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              _suggestionsError!,
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            for (final suggestion in suggestions) ...[
              _SuggestionTile(
                suggestion: suggestion,
                applying: _applyingSuggestionIds.contains(suggestion.id),
                onApply: suggestion.canApply
                    ? () => _applySuggestion(suggestion)
                    : null,
                onDismiss: () => _dismissSuggestion(suggestion.id),
              ),
              if (suggestion != suggestions.last)
                const SizedBox(height: AuraSpace.s10),
            ],
          ] else if (!_suggestionsBusy && hasDraft) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              'No suggestions right now.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          const SizedBox(height: AuraSpace.s14),
          Container(height: 1, color: AuraSurface.divider),
          const SizedBox(height: AuraSpace.s14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _translationTargetLanguage,
                  decoration: const InputDecoration(labelText: 'Translate to'),
                  items: const [
                    DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _translationTargetLanguage = value;
                      _translationPreview = null;
                      _translationError = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              OutlinedButton.icon(
                onPressed: hasDraft && !_translationBusy ? _translateDraft : null,
                icon: _translationBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate),
                label: Text(_translationBusy ? 'Preparing...' : 'Preview'),
              ),
            ],
          ),
          if ((_translationError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              _translationError!,
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
          if (_translationPreview != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s12),
              decoration: BoxDecoration(
                color: AuraSurface.elevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    _translationPreview!.translatedText.trim().isEmpty
                        ? 'No translated text returned.'
                        : _translationPreview!.translatedText,
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _translationPreview!.translatedText.trim().isEmpty
                          ? null
                          : _applyTranslation,
                      child: const Text('Use translation'),
                    ),
                  ),
                ],
              ),
            ),
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

  CompositionReviewResult _parseLightReview(Map<String, dynamic> root) {
    final sessionId = _firstNonEmptyString(root, const [
      ['sessionId'],
      ['session', 'id'],
      ['review', 'sessionId'],
      ['review', 'session', 'id'],
      ['data', 'sessionId'],
      ['data', 'session', 'id'],
    ]);

    final rawFindings = _findRawFindings(root);
    final suggestions = <CompositionSuggestion>[];

    for (var i = 0; i < rawFindings.length; i++) {
      final item = rawFindings[i];
      final id = _firstNonEmptyString(item, const [
        ['id'],
        ['findingId'],
        ['key'],
      ], fallback: 'suggestion_$i');
      final message = _firstNonEmptyString(item, const [
        ['message'],
        ['title'],
        ['summary'],
      ]);
      final replacement = _firstNonEmptyString(item, const [
        ['replacement'],
        ['suggestion'],
        ['text'],
        ['body'],
      ]);
      final canApply = _boolAt(item, const ['canApply']) ??
          _boolAt(item, const ['allowApply']) ??
          replacement.trim().isNotEmpty;

      if (message.trim().isEmpty && replacement.trim().isEmpty) continue;

      suggestions.add(
        CompositionSuggestion(
          id: id,
          message: message.trim().isEmpty ? 'Suggested refinement' : message,
          replacement: replacement,
          canApply: canApply,
        ),
      );
    }

    return CompositionReviewResult(
      sessionId: sessionId,
      suggestions: suggestions,
    );
  }

  CompositionReviewResult? _safeParseLightReview(Map<String, dynamic> root) {
    try {
      final parsed = _parseLightReview(root);
      if (parsed.sessionId.trim().isEmpty && parsed.suggestions.isEmpty) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _findRawFindings(Map<String, dynamic> root) {
    for (final path in const [
      ['findings'],
      ['review', 'findings'],
      ['data', 'findings'],
      ['result', 'findings'],
      ['items'],
      ['data', 'items'],
    ]) {
      final value = _valueAtPath(root, path);
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (value is Map) {
        final flattened = <Map<String, dynamic>>[];
        value.forEach((_, grouped) {
          if (grouped is List) {
            flattened.addAll(
              grouped
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e)),
            );
          }
        });
        if (flattened.isNotEmpty) return flattened;
      }
    }
    return const [];
  }

  dynamic _valueAtPath(Map<String, dynamic> root, List<String> path) {
    dynamic current = root;
    for (final segment in path) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }

  bool? _boolAt(Map<String, dynamic> root, List<String> path) {
    final value = _valueAtPath(root, path);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  String _firstNonEmptyString(
    Map<String, dynamic> root,
    List<List<String>> paths, {
    String fallback = '',
  }) {
    for (final path in paths) {
      final value = _valueAtPath(root, path);
      final s = (value ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  void _replaceControllerText(TextEditingController controller, String text) {
    final selection = controller.selection;
    final targetOffset = selection.baseOffset >= 0
        ? selection.baseOffset.clamp(0, text.length)
        : text.length;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: targetOffset),
      composing: TextRange.empty,
    );
  }

  String _normalizeText(String input) {
    return input.replaceAll('\r\n', '\n').trim();
  }

  Map<String, dynamic> _firstMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _deepFirstMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map) {
        return _deepFirstMap(data['data']);
      }
      return data;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['data'] is Map) {
        return _deepFirstMap(map['data']);
      }
      return map;
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _deepListOfMaps(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in const ['data', 'items', 'results', 'rows']) {
        final value = map[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      for (final value in map.values) {
        if (value is List) {
          final out = value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (out.isNotEmpty) return out;
        }
      }
    }
    return const [];
  }

  List<_DirectoryEntry> _dedupeEntries(List<_DirectoryEntry> entries) {
    final seen = <String>{};
    final out = <_DirectoryEntry>[];
    for (final entry in entries) {
      final key = entry.userId.trim().isNotEmpty
          ? 'user:${entry.userId.trim()}'
          : 'handle:${_normalizeHandle(entry.handle)}';
      if (seen.add(key)) {
        out.add(entry);
      }
    }
    return out;
  }

  _DirectoryEntry? _memberEntryFromMap(Map<String, dynamic> map) {
    final id = _pickString(map, const ['id', '_id', 'userId']);
    final userId = _pickString(map, const ['userId', 'id', '_id']);
    final handle = _pickString(map, const ['handle', 'username']);
    final name = _pickString(map, const ['displayName', 'name', 'fullName']);
    final avatarUrl = _pickString(map, const ['avatarUrl', 'avatar', 'image']);

    final displayName = name.isNotEmpty
        ? name
        : (handle.isNotEmpty ? handle.replaceFirst('@', '') : 'Member');

    final subtitle =
        handle.isNotEmpty ? '@${handle.replaceFirst('@', '')}' : 'Member';
    final profileRoute = handle.isNotEmpty ? '/$handle' : null;

    final stableId = id.isNotEmpty
        ? id
        : (userId.isNotEmpty
            ? userId
            : handle.isNotEmpty
                ? handle
                : displayName);

    if (stableId.trim().isEmpty) return null;

    return _DirectoryEntry(
      id: stableId,
      userId: userId,
      handle: handle,
      displayName: displayName,
      subtitle: subtitle,
      avatarUrl: avatarUrl,
      profileRoute: profileRoute,
    );
  }

  String _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      final s = (value ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _normalizeHandle(String? handle) {
    final value = (handle ?? '').trim().toLowerCase();
    if (value.startsWith('@')) return value.substring(1);
    return value;
  }

  Future<List<Map<String, dynamic>>> _fetchRequiredList(Dio dio, String path) async {
    final res = await dio.get(path);
    return _deepListOfMaps(res.data);
  }

  String _extractSpaceId(dynamic data) {
    final map = _deepFirstMap(data);
    return _pickString(map, const ['id', '_id', 'spaceId']);
  }

  String _extractThreadId(dynamic data) {
    final map = _deepFirstMap(data);
    return _pickString(map, const ['threadId', 'id', '_id']);
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.applying,
    required this.onApply,
    required this.onDismiss,
  });

  final CompositionSuggestion suggestion;
  final bool applying;
  final VoidCallback? onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  suggestion.message,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          if (suggestion.replacement.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              suggestion.replacement,
              style: AuraText.body.copyWith(color: AuraSurface.muted),
            ),
          ],
          if (onApply != null) ...[
            const SizedBox(height: AuraSpace.s10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: applying ? null : onApply,
                icon: applying
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(applying ? 'Applying...' : 'Apply'),
              ),
            ),
          ],
        ],
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
              TextButton(
                onPressed: onOpenProfile,
                child: const Text('View'),
              ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
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
    required this.avatarUrl,
    required this.profileRoute,
  });

  const _DirectoryEntry.empty()
      : id = '',
        userId = '',
        handle = '',
        displayName = '',
        subtitle = '',
        avatarUrl = '',
        profileRoute = null;

  final String id;
  final String userId;
  final String handle;
  final String displayName;
  final String subtitle;
  final String avatarUrl;
  final String? profileRoute;

  String get avatarLetter {
    final base =
        displayName.trim().isNotEmpty ? displayName.trim() : handle.trim();
    if (base.isEmpty) return '?';
    return base.characters.first.toUpperCase();
  }
}
