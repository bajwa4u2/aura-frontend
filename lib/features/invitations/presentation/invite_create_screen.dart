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

  List<_InviteCandidate> _relationshipCandidates = const <_InviteCandidate>[];
  List<_InviteCandidate> _searchCandidates = const <_InviteCandidate>[];
  List<_InviteCandidate> _allCandidates = const <_InviteCandidate>[];
  _InviteCandidate? _selected;

  String? _currentUserId;
  String? _currentUserHandle;
  Timer? _searchDebounce;

  bool _loading = false;
  bool _submitting = false;
  String? _loadError;
  String? _submitError;

  String _inviteMode = 'SHAREABLE';
  String _accessPolicy = 'OPEN';
  String _deliveryChannel = 'LINK';
  String _recipientType = 'OPEN_LINK';
  String _roleToGrant = 'MEMBER';

  @override
  void initState() {
    super.initState();
    _accessPolicy = _defaultAccessPolicyForDestination(_destinationType);
    _inviteMode = _defaultInviteModeForDestination(_destinationType);
    _recipientType = _defaultRecipientTypeForMode(_inviteMode);
    _searchController.addListener(_handleSearchChanged);
    if (_showsInternalRecipientPicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCandidates();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _destinationType => widget.destinationType.trim().toUpperCase();

  bool get _supportsInternalAuraMemberMode {
    return _destinationType == 'JOIN_SPACE' ||
        _destinationType == 'JOIN_THREAD' ||
        _destinationType == 'START_1_TO_1';
  }

  bool get _showsInternalRecipientPicker {
    return _supportsInternalAuraMemberMode && _inviteMode == 'KNOWN_MEMBER';
  }

  List<_InviteCandidate> get _filteredCandidates {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allCandidates;
    return _allCandidates.where((candidate) {
      final hay =
          '${candidate.name} ${candidate.handle} ${candidate.subtitle}'.toLowerCase();
      return hay.contains(q);
    }).toList(growable: false);
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();

    final query = _searchController.text.trim();
    if (!_showsInternalRecipientPicker) return;

    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchCandidates = const <_InviteCandidate>[];
          _allCandidates = _mergeCandidates(_relationshipCandidates, _searchCandidates);
          _loadError = null;
        });
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      unawaited(_runMemberSearch(query));
    });
  }

  Future<void> _runMemberSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/search',
        queryParameters: {
          'q': query,
          'limit': 12,
        },
      );

      final root = _extractMap(res.data);
      final data = _extractMap(root['data']);
      final rawUsers = _extractList(data['users']);

      final found = <_InviteCandidate>[];
      for (final item in rawUsers) {
        final candidate = _candidateFromMap(item);
        if (candidate == null) continue;

        final sameId = (_currentUserId ?? '').isNotEmpty &&
            candidate.userId.trim() == (_currentUserId ?? '');
        final sameHandle = (_currentUserHandle ?? '').isNotEmpty &&
            _normalizeHandle(candidate.handle) == (_currentUserHandle ?? '');

        if (sameId || sameHandle) continue;
        found.add(candidate);
      }

      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _searchCandidates = _dedupeCandidates(found);
        _allCandidates = _mergeCandidates(_relationshipCandidates, _searchCandidates);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _searchCandidates = const <_InviteCandidate>[];
        _allCandidates = _mergeCandidates(_relationshipCandidates, _searchCandidates);
        _loading = false;
        _loadError = 'Aura member search could not be loaded: $e';
      });
    }
  }

  List<_InviteCandidate> _mergeCandidates(
    List<_InviteCandidate> primary,
    List<_InviteCandidate> secondary,
  ) {
    return _dedupeCandidates([
      ...primary,
      ...secondary,
    ]);
  }

  List<_InviteCandidate> _dedupeCandidates(List<_InviteCandidate> input) {
    final seen = <String>{};
    final out = <_InviteCandidate>[];
    for (final candidate in input) {
      final key = candidate.userId.isNotEmpty
          ? 'id:${candidate.userId}'
          : 'handle:${_normalizeHandle(candidate.handle)}';
      if (key.trim().isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(candidate);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  String _normalizeHandle(String? value) {
    final handle = (value ?? '').trim().toLowerCase();
    return handle.startsWith('@') ? handle.substring(1) : handle;
  }

  Future<void> _loadCandidates() async {
    if (!_showsInternalRecipientPicker) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final meRes = await dio.get('/users/me');
      final me = _extractMap(meRes.data);
      final handle = _pickString(me, const ['handle', 'username']);
      final meId = _pickString(me, const ['id', 'userId']);
      final normalizedHandle = _normalizeHandle(handle);
      if (handle.isEmpty) {
        throw Exception('Could not identify the current member.');
      }

      final followersRes = await _safeGet(dio, '/users/$handle/followers');
      final followingRes = await _safeGet(dio, '/users/$handle/following');
      final merged = <Map<String, dynamic>>[
        ..._extractList(followersRes?.data),
        ..._extractList(followingRes?.data),
      ];

      final candidates = <_InviteCandidate>[];
      for (final item in merged) {
        final candidate = _candidateFromMap(item);
        if (candidate == null) continue;
        candidates.add(candidate);
      }

      if (!mounted) return;
      setState(() {
        _currentUserId = meId.isEmpty ? null : meId;
        _currentUserHandle = normalizedHandle.isEmpty ? null : normalizedHandle;
        _relationshipCandidates = _dedupeCandidates(candidates);
        _searchCandidates = const <_InviteCandidate>[];
        _allCandidates = _mergeCandidates(_relationshipCandidates, _searchCandidates);
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

  void _changeInviteMode(String value) {
    if (value == _inviteMode) return;

    setState(() {
      _inviteMode = value;
      _recipientType = _defaultRecipientTypeForMode(value);
      _selected = null;
      _searchController.clear();
      _loadError = null;
      _submitError = null;
      if (value != 'KNOWN_MEMBER') {
        _relationshipCandidates = const <_InviteCandidate>[];
        _searchCandidates = const <_InviteCandidate>[];
        _allCandidates = const <_InviteCandidate>[];
      }
    });

    if (value == 'KNOWN_MEMBER') {
      _loadCandidates();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (_showsInternalRecipientPicker && _selected == null) {
      setState(() {
        _submitError = 'Choose the Aura member you want to invite.';
      });
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
            recipientType: _showsInternalRecipientPicker
                ? 'KNOWN_AURA_USER'
                : _recipientType,
            message: _messageController.text.trim(),
            recipientUserId: _selected?.userId,
            recipientHandle: _selected?.handle,
            spaceId: widget.spaceId,
            threadId: widget.threadId,
            roleToGrant: _destinationType == 'JOIN_SPACE' ? _roleToGrant : null,
            maxUses: 1,
          );

      if (!mounted) return;

      final token = _pickString(invite, const ['token', 'inviteToken']);
      final link = token.isEmpty
          ? ''
          : '${Uri.base.origin}/invite/accept?token=${Uri.encodeComponent(token)}';

      final destinationMessage = switch (_destinationType) {
        'JOIN_AURA' => 'Aura invitation ready.',
        'START_1_TO_1' => '1:1 invitation ready.',
        'JOIN_SPACE' => 'Space invitation ready.',
        'JOIN_THREAD' => 'Thread invitation ready.',
        _ => 'Invitation created.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            link.isNotEmpty ? '$destinationMessage Link created.' : destinationMessage,
          ),
        ),
      );

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
                  _bodyForDestination(
                    _destinationType,
                    spaceId: widget.spaceId,
                    threadId: widget.threadId,
                  ),
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
                Text('Invite mode', style: AuraText.title),
                const SizedBox(height: AuraSpace.s12),
                DropdownButtonFormField<String>(
                  value: _inviteMode,
                  items: _inviteModeItems(_destinationType),
                  onChanged: (value) {
                    if (value == null) return;
                    _changeInviteMode(value);
                  },
                  decoration: const InputDecoration(labelText: 'How to create this invite'),
                ),
                const SizedBox(height: AuraSpace.s10),
                AuraTextBlock(
                  _inviteModeDescription(_destinationType, _inviteMode),
                  style: AuraText.small.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          if (_showsInternalRecipientPicker) ...[
            const SizedBox(height: AuraSpace.s14),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose Aura member', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search members',
                      hintText: 'Search name or handle',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  if (_selected != null) ...[
                    const SizedBox(height: AuraSpace.s12),
                    _SelectedCandidateChip(
                      candidate: _selected!,
                      onClear: () => setState(() => _selected = null),
                    ),
                  ],
                  const SizedBox(height: AuraSpace.s12),
                  if (_loading)
                    const _LoadingRow(label: 'Loading Aura members...')
                  else if (_loadError != null)
                    AuraTextBlock(_loadError!, style: AuraText.body)
                  else if (filtered.isEmpty)
                    AuraTextBlock(
                      'No Aura members matched your search yet.',
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
          ],
          const SizedBox(height: AuraSpace.s14),
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
                  items: _deliveryItems(_inviteMode),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _deliveryChannel = value);
                  },
                  decoration: const InputDecoration(labelText: 'Delivery'),
                ),
                if (!_showsInternalRecipientPicker) ...[
                  const SizedBox(height: AuraSpace.s12),
                  DropdownButtonFormField<String>(
                    value: _recipientType,
                    items: const [
                      DropdownMenuItem(
                        value: 'OPEN_LINK',
                        child: Text('Open link'),
                      ),
                      DropdownMenuItem(
                        value: 'EXTERNAL_CONTACT',
                        child: Text('External contact'),
                      ),
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
                const SizedBox(height: AuraSpace.s10),
                AuraTextBlock(
                  _accessPolicyHint(_destinationType, _accessPolicy),
                  style: AuraText.small.copyWith(color: Colors.black54),
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

class _SelectedCandidateChip extends StatelessWidget {
  const _SelectedCandidateChip({
    required this.candidate,
    required this.onClear,
  });

  final _InviteCandidate candidate;
  final VoidCallback onClear;

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
            candidate.name,
            style: AuraText.small,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (candidate.handle.isNotEmpty) ...[
            const SizedBox(width: AuraSpace.s6),
            AuraTextBlock(
              '@${candidate.handle}',
              style: AuraText.small.copyWith(color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(width: AuraSpace.s8),
          InkWell(
            onTap: onClear,
            child: const Icon(Icons.close, size: 16),
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
    final subtitle = candidate.handle.isNotEmpty
        ? '@${candidate.handle}${candidate.subtitle.isNotEmpty ? ' · ${candidate.subtitle}' : ''}'
        : candidate.subtitle;

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
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    AuraTextBlock(
                      subtitle,
                      style: AuraText.small,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.label});

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

List<DropdownMenuItem<String>> _inviteModeItems(String destinationType) {
  switch (destinationType) {
    case 'JOIN_AURA':
      return const [
        DropdownMenuItem(value: 'SHAREABLE', child: Text('Shareable invitation')),
      ];
    case 'START_1_TO_1':
    case 'JOIN_SPACE':
    case 'JOIN_THREAD':
      return const [
        DropdownMenuItem(value: 'SHAREABLE', child: Text('Shareable invitation')),
        DropdownMenuItem(value: 'KNOWN_MEMBER', child: Text('Aura member')),
      ];
    default:
      return const [
        DropdownMenuItem(value: 'SHAREABLE', child: Text('Shareable invitation')),
      ];
  }
}

List<DropdownMenuItem<String>> _deliveryItems(String inviteMode) {
  if (inviteMode == 'KNOWN_MEMBER') {
    return const [
      DropdownMenuItem(value: 'LINK', child: Text('Link')),
      DropdownMenuItem(value: 'COPY_LINK', child: Text('Copy link')),
    ];
  }

  return const [
    DropdownMenuItem(value: 'LINK', child: Text('Link')),
    DropdownMenuItem(value: 'COPY_LINK', child: Text('Copy link')),
    DropdownMenuItem(value: 'LINKEDIN_SHARE', child: Text('LinkedIn share')),
    DropdownMenuItem(value: 'TIKTOK_SHARE', child: Text('TikTok share')),
  ];
}

List<DropdownMenuItem<String>> _accessPolicyItems(String destinationType) {
  switch (destinationType) {
    case 'START_1_TO_1':
      return const [
        DropdownMenuItem(
          value: 'FOLLOW_INVITER_REQUIRED',
          child: Text('Follow inviter required'),
        ),
        DropdownMenuItem(
          value: 'FOLLOW_THEN_APPROVAL',
          child: Text('Follow then approval'),
        ),
      ];
    case 'JOIN_THREAD':
    case 'JOIN_SPACE':
      return const [
        DropdownMenuItem(value: 'OPEN', child: Text('Open')),
        DropdownMenuItem(
          value: 'FOLLOW_INVITER_REQUIRED',
          child: Text('Follow inviter required'),
        ),
        DropdownMenuItem(
          value: 'APPROVAL_REQUIRED',
          child: Text('Approval required'),
        ),
        DropdownMenuItem(
          value: 'FOLLOW_THEN_APPROVAL',
          child: Text('Follow then approval'),
        ),
      ];
    default:
      return const [
        DropdownMenuItem(value: 'OPEN', child: Text('Open')),
      ];
  }
}

String _defaultInviteModeForDestination(String destinationType) {
  switch (destinationType) {
    case 'JOIN_AURA':
      return 'SHAREABLE';
    case 'START_1_TO_1':
    case 'JOIN_SPACE':
    case 'JOIN_THREAD':
      return 'SHAREABLE';
    default:
      return 'SHAREABLE';
  }
}

String _defaultAccessPolicyForDestination(String destinationType) {
  switch (destinationType) {
    case 'START_1_TO_1':
      return 'FOLLOW_INVITER_REQUIRED';
    default:
      return 'OPEN';
  }
}

String _defaultRecipientTypeForMode(String inviteMode) {
  return inviteMode == 'KNOWN_MEMBER' ? 'KNOWN_AURA_USER' : 'OPEN_LINK';
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

String _bodyForDestination(
  String destinationType, {
  String? spaceId,
  String? threadId,
}) {
  switch (destinationType) {
    case 'JOIN_AURA':
      return 'Create an outward path into Aura itself. This is for people who are not yet inside the system.';
    case 'START_1_TO_1':
      return 'Create an invitation into direct correspondence. The thread will only exist after acceptance.';
    case 'JOIN_SPACE':
      return (spaceId ?? '').trim().isNotEmpty
          ? 'Create an invitation into this space.'
          : 'Create an invitation into a shared space.';
    case 'JOIN_THREAD':
      return (threadId ?? '').trim().isNotEmpty
          ? 'Create an invitation into this thread.'
          : 'Create an invitation into a specific thread.';
    default:
      return 'Create a structured invitation.';
  }
}

String _inviteModeDescription(String destinationType, String inviteMode) {
  if (inviteMode == 'KNOWN_MEMBER') {
    switch (destinationType) {
      case 'START_1_TO_1':
        return 'Choose an Aura member directly. Entry still follows the access policy after the invite reaches them.';
      case 'JOIN_SPACE':
        return 'Choose an Aura member directly for this space. This is one mode, not the only mode.';
      case 'JOIN_THREAD':
        return 'Choose an Aura member directly for this thread. Entry still follows the access policy.';
      default:
        return 'Choose an Aura member directly.';
    }
  }

  switch (destinationType) {
    case 'JOIN_AURA':
      return 'Create a shareable invitation link that can travel outside Aura.';
    case 'START_1_TO_1':
      return 'Create a shareable path into a direct correspondence invitation. Follow or approval can still be enforced at entry.';
    case 'JOIN_SPACE':
      return 'Create a shareable path into this space. Access is decided when the invite is opened, not when it is created.';
    case 'JOIN_THREAD':
      return 'Create a shareable path into this thread. Access is decided when the invite is opened.';
    default:
      return 'Create a shareable invitation path.';
  }
}

String _accessPolicyHint(String destinationType, String accessPolicy) {
  if (destinationType == 'START_1_TO_1') {
    switch (accessPolicy) {
      case 'FOLLOW_INVITER_REQUIRED':
        return 'The invitee will need to follow you before they can enter this 1:1 path.';
      case 'FOLLOW_THEN_APPROVAL':
        return 'The invitee will need to follow you first, then wait for approval.';
    }
  }

  switch (accessPolicy) {
    case 'OPEN':
      return 'Anyone holding this invite can enter directly.';
    case 'FOLLOW_INVITER_REQUIRED':
      return 'The invitee will need to follow the inviter before entry.';
    case 'APPROVAL_REQUIRED':
      return 'The invitee will need approval before entry.';
    case 'FOLLOW_THEN_APPROVAL':
      return 'The invitee will need to follow first, then wait for approval.';
    default:
      return '';
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
  final name = _pickString(
    user,
    const ['displayName', 'name', 'fullName', 'username', 'handle'],
  );
  final state = _pickString(item, const ['state', 'status', 'relationship'])
      .replaceAll('_', ' ');

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
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    const keys = [
      'items',
      'results',
      'list',
      'users',
      'followers',
      'following',
      'data',
    ];
    for (final key in keys) {
      final nested = map[key];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
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
  const keys = [
    'user',
    'member',
    'profile',
    'author',
    'follower',
    'following',
    'requester',
    'target',
  ];
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
