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
import '../data/invitations_client.dart';

class InviteCreateScreen extends ConsumerStatefulWidget {
  const InviteCreateScreen({
    super.key,
    required this.destinationType,
    this.spaceId,
    this.threadId,
  });

  final String destinationType;
  final String? spaceId;
  final String? threadId;

  @override
  ConsumerState<InviteCreateScreen> createState() => _InviteCreateScreenState();
}

class _InviteCreateScreenState extends ConsumerState<InviteCreateScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  List<_InviteCandidate> _allCandidates = const <_InviteCandidate>[];
  _InviteCandidate? _selected;

  bool _loading = false;
  bool _submitting = false;
  String? _loadError;
  String? _submitError;

  String _accessPolicy = 'OPEN';
  String _deliveryChannel = 'LINK';
  String _recipientType = 'OPEN_LINK';
  String _roleToGrant = 'MEMBER';

  @override
  void initState() {
    super.initState();
    if (_requiresKnownRecipient) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCandidates();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _destinationType => widget.destinationType.trim().toUpperCase();

  bool get _requiresKnownRecipient {
    return _destinationType == 'JOIN_SPACE' ||
        _destinationType == 'JOIN_THREAD' ||
        _destinationType == 'START_1_TO_1';
  }

  List<_InviteCandidate> get _filteredCandidates {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allCandidates;
    return _allCandidates.where((candidate) {
      final hay = '${candidate.name} ${candidate.handle} ${candidate.subtitle}'.toLowerCase();
      return hay.contains(q);
    }).toList(growable: false);
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final meRes = await dio.get('/users/me');
      final me = _extractMap(meRes.data);
      final handle = _pickString(me, const ['handle', 'username']);
      if (handle.isEmpty) throw Exception('Could not identify current handle.');

      final followersRes = await _safeGet(dio, '/users/$handle/followers');
      final followingRes = await _safeGet(dio, '/users/$handle/following');
      final merged = <Map<String, dynamic>>[
        ..._extractList(followersRes?.data),
        ..._extractList(followingRes?.data),
      ];

      final items = <String, _InviteCandidate>{};
      for (final item in merged) {
        final candidate = _candidateFromMap(item);
        if (candidate == null) continue;
        final key = candidate.userId.isNotEmpty ? candidate.userId : candidate.handle;
        if (key.isEmpty) continue;
        items[key] = candidate;
      }

      if (!mounted) return;
      setState(() {
        _allCandidates = items.values.toList(growable: false)
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  Future<void> _submit() async {
    if (_submitting) return;

    if (_requiresKnownRecipient && _selected == null) {
      setState(() => _submitError = 'Choose the person you want to invite.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final invite = await ref.read(invitationsClientProvider).createInvite(
            destinationType: _destinationType,
            accessPolicy: _accessPolicy,
            deliveryChannel: _deliveryChannel,
            recipientType: _requiresKnownRecipient ? 'KNOWN_AURA_USER' : _recipientType,
            message: _messageController.text.trim(),
            recipientUserId: _selected?.userId,
            recipientHandle: _selected?.handle,
            spaceId: widget.spaceId,
            threadId: widget.threadId,
            roleToGrant: _destinationType == 'JOIN_SPACE' ? _roleToGrant : null,
            maxUses: _requiresKnownRecipient ? 1 : 1,
          );

      if (!mounted) return;

      final token = _pickString(invite, const ['token', 'inviteToken']);
      final link = token.isEmpty ? '' : '${Uri.base.origin}/invite/accept?token=${Uri.encodeComponent(token)}';

      if (link.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite ready: $link')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation created.')),
        );
      }

      context.go('/me/invitations');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = _readApiError(e, fallback: 'Could not create invitation.');
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCandidates;

    return AuraScaffold(
      title: 'Create invite',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_titleForDestination(_destinationType), style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                AuraTextBlock(
                  _bodyForDestination(_destinationType, spaceId: widget.spaceId, threadId: widget.threadId),
                  style: AuraText.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          if (_requiresKnownRecipient) ...[
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose recipient', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search people',
                      hintText: 'Search name or handle',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  if (_loading)
                    const _LoadingRow(label: 'Loading connected people...')
                  else if (_loadError != null)
                    AuraTextBlock(_loadError!, style: AuraText.body)
                  else if (filtered.isEmpty)
                    AuraTextBlock(
                      'No connected people are available here yet.',
                      style: AuraText.body,
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          _CandidateRow(
                            candidate: filtered[i],
                            selected: _selected?.id == filtered[i].id,
                            onTap: () => setState(() => _selected = filtered[i]),
                          ),
                          if (i != filtered.length - 1) const Divider(height: 1),
                        ],
                      ],
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
                Text('Invite settings', style: AuraText.title),
                const SizedBox(height: AuraSpace.s12),
                DropdownButtonFormField<String>(
                  value: _accessPolicy,
                  items: _accessPolicyItems(_destinationType),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _accessPolicy = value);
                  },
                  decoration: const InputDecoration(labelText: 'Access policy'),
                ),
                const SizedBox(height: AuraSpace.s12),
                DropdownButtonFormField<String>(
                  value: _deliveryChannel,
                  items: const [
                    DropdownMenuItem(value: 'LINK', child: Text('Link')),
                    DropdownMenuItem(value: 'COPY_LINK', child: Text('Copy link')),
                    DropdownMenuItem(value: 'LINKEDIN_SHARE', child: Text('LinkedIn share')),
                    DropdownMenuItem(value: 'TIKTOK_SHARE', child: Text('TikTok share')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _deliveryChannel = value);
                  },
                  decoration: const InputDecoration(labelText: 'Delivery'),
                ),
                if (!_requiresKnownRecipient) ...[
                  const SizedBox(height: AuraSpace.s12),
                  DropdownButtonFormField<String>(
                    value: _recipientType,
                    items: const [
                      DropdownMenuItem(value: 'OPEN_LINK', child: Text('Open link')),
                      DropdownMenuItem(value: 'EXTERNAL_CONTACT', child: Text('External contact')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _recipientType = value);
                    },
                    decoration: const InputDecoration(labelText: 'Recipient type'),
                  ),
                ],
                if (_destinationType == 'JOIN_SPACE') ...[
                  const SizedBox(height: AuraSpace.s12),
                  DropdownButtonFormField<String>(
                    value: _roleToGrant,
                    items: const [
                      DropdownMenuItem(value: 'MEMBER', child: Text('Member')),
                      DropdownMenuItem(value: 'EDITOR', child: Text('Editor')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _roleToGrant = value);
                    },
                    decoration: const InputDecoration(labelText: 'Role to grant'),
                  ),
                ],
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Add context to this invitation',
                  ),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Text(
                    _submitError!,
                    style: AuraText.small.copyWith(color: Colors.red.shade700),
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
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Creating...' : 'Create invite'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final _InviteCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(
                candidate.name.isEmpty ? '?' : candidate.name[0].toUpperCase(),
                style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuraTextBlock(
                    candidate.name,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  AuraTextBlock(
                    candidate.subtitle,
                    style: AuraText.small,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Radio<bool>(value: true, groupValue: selected, onChanged: (_) => onTap()),
          ],
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: AuraSpace.s10),
        Text(label, style: AuraText.body),
      ],
    );
  }
}

List<DropdownMenuItem<String>> _accessPolicyItems(String destinationType) {
  switch (destinationType) {
    case 'START_1_TO_1':
      return const [
        DropdownMenuItem(value: 'FOLLOW_INVITER_REQUIRED', child: Text('Follow inviter required')),
        DropdownMenuItem(value: 'FOLLOW_THEN_APPROVAL', child: Text('Follow then approval')),
      ];
    case 'JOIN_THREAD':
    case 'JOIN_SPACE':
      return const [
        DropdownMenuItem(value: 'OPEN', child: Text('Open')),
        DropdownMenuItem(value: 'FOLLOW_INVITER_REQUIRED', child: Text('Follow inviter required')),
        DropdownMenuItem(value: 'APPROVAL_REQUIRED', child: Text('Approval required')),
        DropdownMenuItem(value: 'FOLLOW_THEN_APPROVAL', child: Text('Follow then approval')),
      ];
    default:
      return const [
        DropdownMenuItem(value: 'OPEN', child: Text('Open')),
      ];
  }
}

String _titleForDestination(String destinationType) {
  switch (destinationType) {
    case 'JOIN_AURA':
      return 'Invite to Aura';
    case 'START_1_TO_1':
      return 'Invite to 1:1';
    case 'JOIN_SPACE':
      return 'Invite to space';
    case 'JOIN_THREAD':
      return 'Invite to thread';
    default:
      return 'Create invite';
  }
}

String _bodyForDestination(String destinationType, {String? spaceId, String? threadId}) {
  switch (destinationType) {
    case 'JOIN_AURA':
      return 'Create an outward path into Aura itself. This works for people who are not yet inside the system.';
    case 'START_1_TO_1':
      return 'Invite one person into a direct correspondence path. Thread creation will happen only after acceptance.';
    case 'JOIN_SPACE':
      return (spaceId ?? '').trim().isNotEmpty
          ? 'Create an invitation into this space.'
          : 'Create an invitation into a shared space.';
    case 'JOIN_THREAD':
      return (threadId ?? '').trim().isNotEmpty
          ? 'Create an invitation into this thread.'
          : 'Create an invitation into a specific conversation thread.';
    default:
      return 'Create a structured invitation.';
  }
}

class _InviteCandidate {
  const _InviteCandidate({
    required this.id,
    required this.userId,
    required this.name,
    required this.handle,
    required this.subtitle,
  });

  final String id;
  final String userId;
  final String name;
  final String handle;
  final String subtitle;
}

_InviteCandidate? _candidateFromMap(Map<String, dynamic> item) {
  final user = _unwrapNestedUser(item);
  final id = _pickString(user, const ['id', 'userId', '_id']);
  final handle = _cleanHandle(_pickString(user, const ['handle', 'username']));
  final name = _pickString(user, const ['displayName', 'name', 'fullName', 'username', 'handle']);
  final state = _pickString(item, const ['state', 'status', 'relationship']).replaceAll('_', ' ');

  if (id.isEmpty && handle.isEmpty && name.isEmpty) return null;

  return _InviteCandidate(
    id: id.isNotEmpty ? id : handle,
    userId: id,
    name: name.isNotEmpty ? name : (handle.isNotEmpty ? handle : 'Member'),
    handle: handle,
    subtitle: state.isNotEmpty ? state : 'Connected',
  );
}

Future<Response<dynamic>?> _safeGet(Dio dio, String path) async {
  try {
    return await dio.get(path);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _extractMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    const keys = ['data', 'user', 'item', 'result', 'payload'];
    for (final key in keys) {
      final nested = raw[key];
      if (nested is Map<String, dynamic>) return _extractMap(nested);
      if (nested is Map) return _extractMap(Map<String, dynamic>.from(nested));
    }
    return raw;
  }
  if (raw is Map) return _extractMap(Map<String, dynamic>.from(raw));
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _extractList(dynamic raw) {
  if (raw is List) {
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    const keys = ['items', 'results', 'list', 'users', 'followers', 'following', 'data'];
    for (final key in keys) {
      final nested = map[key];
      if (nested is List) {
        return nested.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
      }
      if (nested is Map) {
        final list = _extractList(Map<String, dynamic>.from(nested));
        if (list.isNotEmpty) return list;
      }
    }
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _unwrapNestedUser(Map<String, dynamic> item) {
  const keys = ['user', 'member', 'profile', 'author', 'follower', 'following', 'requester', 'target'];
  for (final key in keys) {
    final value = item[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return item;
}

String _cleanHandle(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _readApiError(DioException e, {required String fallback}) {
  final data = e.response?.data;
  if (data is Map) {
    final message = (data['message'] ?? '').toString().trim();
    if (message.isNotEmpty) return message;
    final error = data['error'];
    if (error is Map) {
      final nested = (error['message'] ?? '').toString().trim();
      if (nested.isNotEmpty) return nested;
    }
  }
  final direct = e.message?.trim() ?? '';
  return direct.isNotEmpty ? direct : fallback;
}
