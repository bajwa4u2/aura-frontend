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
  String _roleToGrant = 'MEMBER';

  @override
  void initState() {
    super.initState();
    _accessPolicy = _defaultAccessPolicyForDestination(_destinationType);
    _inviteMode = _defaultInviteModeForDestination(_destinationType);
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

  bool get _isSpaceInvite => _destinationType == 'JOIN_SPACE';
  bool get _isThreadInvite => _destinationType == 'JOIN_THREAD';
  bool get _isDirectInvite => _destinationType == 'START_1_TO_1';
  bool get _isAuraInvite => _destinationType == 'JOIN_AURA';

  bool get _supportsMemberPicker => _isSpaceInvite || _isThreadInvite || _isDirectInvite;

  bool get _forceKnownMemberMode => _isDirectInvite || _isThreadInvite;

  String get _effectiveInviteMode {
    if (_forceKnownMemberMode) return 'KNOWN_MEMBER';
    if (_isAuraInvite) return 'SHAREABLE';
    return _inviteMode;
  }

  bool get _showsModeSelector => _isSpaceInvite;

  bool get _showsInternalRecipientPicker {
    return _supportsMemberPicker && _effectiveInviteMode == 'KNOWN_MEMBER';
  }

  bool get _showsAccessPolicy {
    return _isSpaceInvite && _effectiveInviteMode == 'SHAREABLE';
  }

  bool get _showsRoleToGrant {
    return _isSpaceInvite;
  }

  List<_InviteCandidate> get _filteredCandidates {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allCandidates;
    return _allCandidates.where((candidate) {
      final hay = '${candidate.name} ${candidate.handle} ${candidate.subtitle}'.toLowerCase();
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
    } catch (_) {
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _searchCandidates = const <_InviteCandidate>[];
        _allCandidates = _mergeCandidates(_relationshipCandidates, _searchCandidates);
        _loading = false;
        _loadError = 'Member search is unavailable right now. Please try again.';
      });
    }
  }

  List<_InviteCandidate> _mergeCandidates(
    List<_InviteCandidate> primary,
    List<_InviteCandidate> secondary,
  ) {
    return _dedupeCandidates([...primary, ...secondary]);
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
        _submitError = 'Choose the Aura member you want to bring in.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final effectiveMode = _effectiveInviteMode;
      final invite = await ref.read(invitationsClientProvider).createInvite(
            destinationType: _destinationType,
            accessPolicy: _showsAccessPolicy ? _accessPolicy : _defaultAccessPolicyForDestination(_destinationType),
            deliveryChannel: 'LINK',
            recipientType: effectiveMode == 'KNOWN_MEMBER' ? 'KNOWN_AURA_USER' : 'OPEN_LINK',
            message: _messageController.text.trim(),
            recipientUserId: _selected?.userId,
            recipientHandle: _selected?.handle,
            spaceId: widget.spaceId,
            threadId: widget.threadId,
            roleToGrant: _showsRoleToGrant ? _roleToGrant : null,
            maxUses: effectiveMode == 'KNOWN_MEMBER' ? 1 : 1,
          );

      if (!mounted) return;

      final token = _pickString(invite, const ['token', 'inviteToken']);
      final link = token.isEmpty
          ? ''
          : '${Uri.base.origin}/invite/accept?token=${Uri.encodeComponent(token)}';

      final destinationMessage = switch (_destinationType) {
        'JOIN_AURA' => 'Aura invitation ready.',
        'START_1_TO_1' => 'Direct invitation ready.',
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
      title: _titleForDestination(_destinationType),
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
                const SizedBox(height: AuraSpace.s10),
                AuraTextBlock(
                  _pathSummary,
                  style: AuraText.small,
                ),
              ],
            ),
          ),
          if (_showsModeSelector) ...[
            const SizedBox(height: AuraSpace.s14),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How should they enter?', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s12),
                  DropdownButtonFormField<String>(
                    value: _inviteMode,
                    items: const [
                      DropdownMenuItem(value: 'KNOWN_MEMBER', child: Text('Aura member')),
                      DropdownMenuItem(value: 'SHAREABLE', child: Text('Shareable link')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _changeInviteMode(value);
                    },
                    decoration: const InputDecoration(labelText: 'Entry path'),
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  AuraTextBlock(
                    _inviteModeDescription(_destinationType, _effectiveInviteMode),
                    style: AuraText.small,
                  ),
                ],
              ),
            ),
          ],
          if (_showsInternalRecipientPicker) ...[
            const SizedBox(height: AuraSpace.s14),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose member', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search Aura members',
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
                      'No members matched that search.',
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
          if (_showsAccessPolicy || _showsRoleToGrant) ...[
            const SizedBox(height: AuraSpace.s14),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite settings', style: AuraText.title),
                  if (_showsAccessPolicy) ...[
                    const SizedBox(height: AuraSpace.s12),
                    DropdownButtonFormField<String>(
                      value: _accessPolicy,
                      items: _accessPolicyItems(_destinationType),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _accessPolicy = value);
                      },
                      decoration: const InputDecoration(labelText: 'Access'),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    AuraTextBlock(
                      _accessPolicyHint(_destinationType, _accessPolicy),
                      style: AuraText.small,
                    ),
                  ],
                  if (_showsRoleToGrant) ...[
                    const SizedBox(height: AuraSpace.s12),
                    DropdownButtonFormField<String>(
                      value: _roleToGrant,
                      items: const [
                        DropdownMenuItem(value: 'MEMBER', child: Text('Member')),
                        DropdownMenuItem(value: 'MODERATOR', child: Text('Moderator')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _roleToGrant = value);
                      },
                      decoration: const InputDecoration(labelText: 'Role on entry'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Optional note', style: AuraText.title),
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Add a short note if you want context to travel with the invite.',
                  ),
                ),
              ],
            ),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraTextBlock(
              _submitError!,
              style: AuraText.body.copyWith(color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: AuraSpace.s16),
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
                  child: Text(_submitting ? 'Creating...' : _submitLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _pathSummary {
    if (_isDirectInvite) {
      return 'This path is direct. Choose the member and send the invitation without extra routing choices.';
    }
    if (_isThreadInvite) {
      return 'This invitation is anchored to one ongoing thread, not to the whole room around it.';
    }
    if (_isSpaceInvite) {
      return _effectiveInviteMode == 'KNOWN_MEMBER'
          ? 'Choose one Aura member and bring them into this shared room directly.'
          : 'Create one clean link for this space. Access is decided here, before the invite travels.';
    }
    return 'This creates a clean outward path into Aura itself.';
  }

  String get _submitLabel {
    switch (_destinationType) {
      case 'START_1_TO_1':
        return 'Send direct invite';
      case 'JOIN_SPACE':
        return 'Create space invite';
      case 'JOIN_THREAD':
        return 'Create thread invite';
      case 'JOIN_AURA':
        return 'Create Aura invite';
      default:
        return 'Create invite';
    }
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
    final subtitle = candidate.handle.isNotEmpty
        ? '@${candidate.handle}${candidate.subtitle.isNotEmpty ? ' · ${candidate.subtitle}' : ''}'
        : candidate.subtitle;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(candidate.name, style: AuraText.small),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(width: AuraSpace.s6),
            Text(subtitle, style: AuraText.small),
          ],
          const SizedBox(width: AuraSpace.s8),
          InkWell(onTap: onClear, child: const Icon(Icons.close, size: 16)),
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

List<DropdownMenuItem<String>> _accessPolicyItems(String destinationType) {
  switch (destinationType) {
    case 'JOIN_SPACE':
      return const [
        DropdownMenuItem(value: 'OPEN', child: Text('Open')),
        DropdownMenuItem(value: 'APPROVAL_REQUIRED', child: Text('Approval required')),
        DropdownMenuItem(value: 'FOLLOW_INVITER_REQUIRED', child: Text('Follow inviter required')),
        DropdownMenuItem(value: 'FOLLOW_THEN_APPROVAL', child: Text('Follow then approval')),
      ];
    default:
      return const [
        DropdownMenuItem(value: 'OPEN', child: Text('Open')),
      ];
  }
}

String _defaultInviteModeForDestination(String destinationType) {
  switch (destinationType) {
    case 'JOIN_SPACE':
      return 'KNOWN_MEMBER';
    case 'JOIN_AURA':
      return 'SHAREABLE';
    default:
      return 'KNOWN_MEMBER';
  }
}

String _defaultAccessPolicyForDestination(String destinationType) {
  switch (destinationType) {
    case 'JOIN_SPACE':
      return 'OPEN';
    case 'START_1_TO_1':
      return 'FOLLOW_INVITER_REQUIRED';
    default:
      return 'OPEN';
  }
}

String _titleForDestination(String destinationType) {
  switch (destinationType) {
    case 'JOIN_AURA':
      return 'Invite to Aura';
    case 'START_1_TO_1':
      return 'Bring someone into a private conversation';
    case 'JOIN_SPACE':
      return 'Bring someone into this space';
    case 'JOIN_THREAD':
      return 'Bring someone into this thread';
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
      return 'Create a simple outward path into Aura for someone who is not yet inside.';
    case 'START_1_TO_1':
      return 'Choose one Aura member and create a direct private path. This should feel like one clear action, not a separate subsystem.';
    case 'JOIN_SPACE':
      return (spaceId ?? '').trim().isNotEmpty
          ? 'Bring someone into this shared space either directly as a member or through a shareable link.'
          : 'Bring someone into a shared space.';
    case 'JOIN_THREAD':
      return (threadId ?? '').trim().isNotEmpty
          ? 'Bring someone into this exact thread without widening access beyond what is needed.'
          : 'Bring someone into a specific thread.';
    default:
      return 'Create a structured invitation.';
  }
}

String _inviteModeDescription(String destinationType, String inviteMode) {
  if (inviteMode == 'KNOWN_MEMBER') {
    switch (destinationType) {
      case 'JOIN_SPACE':
        return 'Choose a specific Aura member and let them enter this space directly.';
      case 'JOIN_THREAD':
        return 'Choose the member who should enter this thread.';
      case 'START_1_TO_1':
        return 'Choose the member you want to speak with directly.';
      default:
        return 'Choose a specific Aura member.';
    }
  }

  switch (destinationType) {
    case 'JOIN_SPACE':
      return 'Create one link for this space and decide the access rules now.';
    case 'JOIN_AURA':
      return 'Create one clean entry link into Aura.';
    default:
      return 'Create a shareable link.';
  }
}

String _accessPolicyHint(String destinationType, String accessPolicy) {
  switch (accessPolicy) {
    case 'OPEN':
      return 'Anyone holding this link can enter directly.';
    case 'FOLLOW_INVITER_REQUIRED':
      return 'They will need to follow the inviter before entry.';
    case 'APPROVAL_REQUIRED':
      return 'They will wait for approval before entry.';
    case 'FOLLOW_THEN_APPROVAL':
      return 'They will need to follow first, then wait for approval.';
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
        final list = _extractList(nested);
        if (list.isNotEmpty) return list;
      }
    }
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _unwrapNestedUser(Map<String, dynamic> item) {
  final nested = item['user'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  return item;
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _cleanHandle(String value) {
  final out = value.trim();
  if (out.startsWith('@')) return out.substring(1);
  return out;
}

String _readApiError(DioException error, {required String fallback}) {
  final data = error.response?.data;
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final message = map['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
    final err = map['error'];
    if (err is Map) {
      final nested = Map<String, dynamic>.from(err);
      final nestedMessage = nested['message'];
      if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
        return nestedMessage.trim();
      }
    }
  }
  return fallback;
}
