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
import '../../../core/ui/aura_text_block.dart';

class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  @override
  ConsumerState<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends ConsumerState<InviteMemberScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  List<_InviteCandidate> _allCandidates = const <_InviteCandidate>[];
  _InviteCandidate? _selectedPerson;

  String _selectedRole = 'MEMBER';
  bool _loading = true;
  bool _searching = false;
  bool _submitting = false;
  String? _loadError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCandidates();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    setState(() => _searching = true);

    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _searching = false);
    });
  }

  List<_InviteCandidate> get _filteredCandidates {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allCandidates;

    return _allCandidates.where((person) {
      final haystack = [
        person.name,
        person.handle,
        person.subtitle,
        person.searchBlob,
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList(growable: false);
  }

  bool get _canSubmit => !_submitting && _selectedPerson != null;

  Future<void> _loadCandidates() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _submitError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final me = await _loadMe(dio);
      final myHandle = _pickString(me, const ['handle', 'username']);

      if (myHandle.isEmpty) {
        throw Exception('Could not determine the current user handle.');
      }

      final results = await Future.wait<List<Map<String, dynamic>>>([
        _fetchList(dio, '/users/$myHandle/followers'),
        _fetchList(dio, '/users/$myHandle/following'),
      ]);

      final merged = results.expand((e) => e).toList(growable: false);

      final candidates = merged
          .map(_candidateFromMap)
          .whereType<_InviteCandidate>()
          .where((candidate) => candidate.userId.trim().isNotEmpty)
          .toList(growable: false);

      final deduped = _dedupeCandidates(candidates)
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

      if (!mounted) return;

      setState(() {
        _allCandidates = deduped;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadMe(Dio dio) async {
    final res = await dio.get('/users/me');
    return _deepFirstMap(res.data);
  }

  Future<List<Map<String, dynamic>>> _fetchList(
    Dio dio,
    String path,
  ) async {
    try {
      final res = await dio.get(path);
      return _deepFirstList(res.data);
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

    final selected = _selectedPerson;
    if (selected == null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final dio = ref.read(dioProvider);

      await dio.post(
        '/spaces/${widget.spaceId}/invites',
        data: {
          'userId': selected.userId,
          'role': _selectedRole,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AuraTextBlock(
            'Invite sent to ${selected.name}.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AuraText.body,
          ),
        ),
      );

      context.pop(true);
    } on DioException catch (e) {
      final message = _extractDioMessage(e);

      if (!mounted) return;
      setState(() {
        _submitError = message;
      });
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

  void _selectPerson(_InviteCandidate person) {
    setState(() {
      _submitError = null;
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
      title: 'Invite member',
      body: RefreshIndicator(
        onRefresh: _loadCandidates,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite member', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Connected members from your followers and following relationships appear here.',
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
                  Text('Find member', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: 'Search',
                      hintText: 'Search name or handle',
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
                  ),
                  if (_selectedPerson != null) ...[
                    const SizedBox(height: AuraSpace.s12),
                    _SelectedInviteChip(
                      label: _selectedPerson!.name,
                      languageCode: _selectedPerson!.languageCode,
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
                  Text('Members', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  if (_loading)
                    const _LoadingBlock(label: 'Loading members...')
                  else if (_loadError != null)
                    _InlineErrorBlock(
                      title: 'Could not load connected members',
                      body: _loadError!,
                      onRetry: _loadCandidates,
                    )
                  else if (_allCandidates.isEmpty)
                    Text(
                      'No connected members were found from followers or following yet.',
                      style: AuraText.body,
                    )
                  else if (filteredCandidates.isEmpty)
                    Text(
                      'No matching members found.',
                      style: AuraText.body,
                    )
                  else
                    Column(
                      children: [
                        for (int i = 0; i < filteredCandidates.length; i++) ...[
                          _InvitePersonRow(
                            person: filteredCandidates[i],
                            selected:
                                _selectedPerson?.id == filteredCandidates[i].id,
                            onTap: () => _selectPerson(filteredCandidates[i]),
                            onOpenProfile: filteredCandidates[i].profileRoute == null
                                ? null
                                : () => context.push(
                                      filteredCandidates[i].profileRoute!,
                                    ),
                          ),
                          if (i != filteredCandidates.length - 1)
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
                    child: Text(_submitting ? 'Inviting...' : 'Send invite'),
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

class _InvitePersonRow extends StatelessWidget {
  const _InvitePersonRow({
    required this.person,
    required this.selected,
    required this.onTap,
    required this.onOpenProfile,
  });

  final _InviteCandidate person;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(
                person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuraTextBlock(
                    person.name,
                    languageCode: person.languageCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  AuraTextBlock(
                    person.handle.isEmpty
                        ? person.subtitle
                        : '${person.handle} · ${person.subtitle}',
                    languageCode: person.languageCode,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small,
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
    this.languageCode,
  });

  final String label;
  final String? languageCode;
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
          AuraTextBlock(
            label,
            languageCode: languageCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.small,
          ),
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
          child: AuraTextBlock(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AuraText.body,
          ),
        ),
      ],
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
        AuraTextBlock(
          body,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: AuraText.small,
        ),
        const SizedBox(height: AuraSpace.s12),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _InviteCandidate {
  const _InviteCandidate({
    required this.id,
    required this.userId,
    required this.name,
    required this.handle,
    required this.subtitle,
    required this.searchBlob,
    required this.profileRoute,
    required this.languageCode,
  });

  final String id;
  final String userId;
  final String name;
  final String handle;
  final String subtitle;
  final String searchBlob;
  final String? profileRoute;
  final String? languageCode;
}

_InviteCandidate? _candidateFromMap(Map<String, dynamic> item) {
  final user = _unwrapNestedUser(item);

  final userId = _pickString(user, const ['id', 'userId', '_id']);
  final cleanHandle = _cleanHandle(
    _pickString(user, const ['handle', 'username', 'userHandle']),
  );
  final name = _pickString(
    user,
    const ['displayName', 'fullName', 'name', 'username', 'handle'],
  );

  if (userId.isEmpty && cleanHandle.isEmpty && name.isEmpty) {
    return null;
  }

  final languageCode = _pickString(
    user,
    const ['languageCode', 'language', 'locale', 'preferredLanguage'],
  );

  final relationship = _pickString(
    item,
    const ['state', 'relationship', 'followState', 'status'],
  ).replaceAll('_', ' ');

  final bio = _pickString(
    user,
    const ['bio', 'headline', 'summary', 'tagline'],
  );

  final subtitleParts = <String>[
    if (relationship.isNotEmpty) relationship,
    if (bio.isNotEmpty) bio,
  ];

  final resolvedName = name.isNotEmpty
      ? name
      : (cleanHandle.isNotEmpty ? cleanHandle : 'Member');

  final handleLabel = cleanHandle.isNotEmpty ? '@$cleanHandle' : '';

  return _InviteCandidate(
    id: userId.isNotEmpty ? userId : cleanHandle,
    userId: userId,
    name: resolvedName,
    handle: handleLabel,
    subtitle: subtitleParts.isEmpty ? 'Connected' : subtitleParts.join(' · '),
    searchBlob: [resolvedName, cleanHandle, relationship, bio].join(' '),
    profileRoute: cleanHandle.isEmpty ? null : '/u/$cleanHandle',
    languageCode: languageCode.isEmpty ? null : languageCode,
  );
}

List<_InviteCandidate> _dedupeCandidates(List<_InviteCandidate> items) {
  final map = <String, _InviteCandidate>{};
  for (final item in items) {
    final key = item.userId.isNotEmpty ? item.userId : item.id;
    map[key] = item;
  }
  return map.values.toList(growable: false);
}

Map<String, dynamic> _unwrapNestedUser(Map<String, dynamic> item) {
  const nestedKeys = [
    'user',
    'member',
    'profile',
    'author',
    'follower',
    'following',
    'account',
  ];

  for (final key in nestedKeys) {
    final value = item[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }

  return item;
}

Map<String, dynamic> _deepFirstMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    const candidateKeys = [
      'data',
      'item',
      'result',
      'payload',
      'user',
      'me',
    ];

    for (final key in candidateKeys) {
      final nested = raw[key];
      if (nested is Map) {
        return _deepFirstMap(Map<String, dynamic>.from(nested));
      }
    }

    return raw;
  }

  if (raw is Map) {
    return _deepFirstMap(Map<String, dynamic>.from(raw));
  }

  return <String, dynamic>{};
}

List<Map<String, dynamic>> _deepFirstList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);

    const candidateKeys = [
      'items',
      'results',
      'list',
      'users',
      'followers',
      'following',
      'data',
    ];

    for (final key in candidateKeys) {
      final value = map[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      if (value is Map) {
        final nested = _deepFirstList(Map<String, dynamic>.from(value));
        if (nested.isNotEmpty) return nested;
      }
    }
  }

  return const <Map<String, dynamic>>[];
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

String _cleanHandle(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
}

String _extractDioMessage(DioException e) {
  final responseData = e.response?.data;
  String message = e.message ?? 'Could not send invite.';

  if (responseData is Map) {
    final map = Map<String, dynamic>.from(responseData);
    final nestedError = map['error'];
    if (nestedError is Map) {
      final nestedMap = Map<String, dynamic>.from(nestedError);
      final nestedMessage = (nestedMap['message'] ?? '').toString().trim();
      if (nestedMessage.isNotEmpty) {
        return nestedMessage;
      }
    }

    final directMessage = (map['message'] ?? '').toString().trim();
    if (directMessage.isNotEmpty) {
      return directMessage;
    }
  } else if (responseData != null) {
    final text = responseData.toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }

  return message;
}