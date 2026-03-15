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

    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _searching = false);
    });
  }

  List<_InviteCandidate> get _filteredCandidates {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allCandidates;

    return _allCandidates.where((person) {
      return person.name.toLowerCase().contains(q) ||
          person.handle.toLowerCase().contains(q) ||
          person.subtitle.toLowerCase().contains(q) ||
          person.searchBlob.toLowerCase().contains(q);
    }).toList();
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
      final handle = _pickString(me, const ['handle', 'username']);

      if (handle.isEmpty) {
        throw Exception('Could not determine the current user handle.');
      }

      final results = await Future.wait<List<Map<String, dynamic>>>([
        _fetchList(dio, '/users/$handle/followers'),
        _fetchList(dio, '/users/$handle/following'),
      ]);

      final merged = results.expand((e) => e).toList();
      final candidates = merged
          .map(_candidateFromMap)
          .whereType<_InviteCandidate>()
          .toList();

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
    return _unwrapMap(_asMap(res.data));
  }

  Future<List<Map<String, dynamic>>> _fetchList(
    Dio dio,
    String path,
  ) async {
    try {
      final res = await dio.get(path);
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
          content: Text(
            'Invite sent to ${selected.name}.',
          ),
        ),
      );

      context.pop(true);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String message = e.message ?? 'Could not send invite.';

      if (responseData is Map) {
        final map = Map<String, dynamic>.from(responseData);
        final nestedError = map['error'];
        if (nestedError is Map) {
          final nestedMap = Map<String, dynamic>.from(nestedError);
          final nestedMessage = (nestedMap['message'] ?? '').toString().trim();
          if (nestedMessage.isNotEmpty) {
            message = nestedMessage;
          }
        } else {
          final directMessage = (map['message'] ?? '').toString().trim();
          if (directMessage.isNotEmpty) {
            message = directMessage;
          }
        }
      } else if (responseData != null) {
        message = responseData.toString();
      }

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
                    'Invites are limited to people in your followers and following relationships.',
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
                  Text('Search', style: AuraText.title),
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
                  if (_loading)
                    const _LoadingBlock(label: 'Loading people...')
                  else if (_loadError != null)
                    _InlineErrorBlock(
                      title: 'Could not load people',
                      body: _loadError!,
                      onRetry: _loadCandidates,
                    )
                  else if (filteredCandidates.isEmpty)
                    Text(
                      'No matching people found.',
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
                                : () => context.go(
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
                  Text(
                    person.name,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${person.handle} · ${person.subtitle}',
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
  });

  final String id;
  final String userId;
  final String name;
  final String handle;
  final String subtitle;
  final String searchBlob;
  final String? profileRoute;
}

_InviteCandidate? _candidateFromMap(Map<String, dynamic> item) {
  final user = _unwrapNestedUser(item);

  final userId = _pickString(user, const ['id', 'userId', '_id']);
  final handle = _cleanHandle(
    _pickString(user, const ['handle', 'username', 'userHandle']),
  );
  final name = _pickString(
    user,
    const ['displayName', 'fullName', 'name', 'username', 'handle'],
  );

  if (userId.isEmpty || name.isEmpty && handle.isEmpty) {
    return null;
  }

  final relationship = _pickString(
    item,
    const ['state', 'relationship', 'followState', 'status'],
  ).replaceAll('_', ' ');

  final subtitleParts = <String>[
    if (relationship.isNotEmpty) relationship,
  ];

  return _InviteCandidate(
    id: userId,
    userId: userId,
    name: name.isNotEmpty ? name : handle,
    handle: handle.isNotEmpty ? '@$handle' : '',
    subtitle: subtitleParts.isEmpty ? 'Connected' : subtitleParts.join(' · '),
    searchBlob: [name, handle, relationship].join(' '),
    profileRoute: handle.isEmpty ? null : '/u/$handle',
  );
}

List<_InviteCandidate> _dedupeCandidates(List<_InviteCandidate> items) {
  final map = <String, _InviteCandidate>{};
  for (final item in items) {
    map[item.id] = item;
  }
  return map.values.toList();
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