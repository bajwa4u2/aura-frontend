import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/profile_header.dart';

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  int _followersCount = 0;
  int _followingCount = 0;
  int _incomingRequestsCount = 0;
  int _outgoingRequestsCount = 0;

  Map<String, dynamic>? _tiktokAccount;
  bool _tiktokLoading = false;
  bool _tiktokActionBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dio = ref.read(dioProvider);

      final meResponse = await dio.get('/v1/users/me');
      final user = _unwrapUser(meResponse.data);

      final handle = _value(user['handle']);
      final userId = _value(user['id']);

      final futures = await Future.wait<dynamic>([
        if (handle.isNotEmpty)
          _safeGet(dio, '/users/$handle/followers')
        else
          Future.value(null),
        if (handle.isNotEmpty)
          _safeGet(dio, '/users/$handle/following')
        else
          Future.value(null),
        _safeGet(dio, '/users/me/follow/requests/inbox'),
        _safeGet(dio, '/users/me/follow/requests/outbox'),
        if (userId.isNotEmpty)
          _safeGet(
            dio,
            '/v1/integrations/tiktok/account',
            queryParameters: {'userId': userId},
          )
        else
          Future.value(null),
      ]);

      final followersRes = futures[0];
      final followingRes = futures[1];
      final inboxRes = futures[2];
      final outboxRes = futures[3];
      final tiktokRes = futures[4];

      if (!mounted) return;

      setState(() {
        _user = user;
        _followersCount = _countItemsFromPayload(followersRes?.data);
        _followingCount = _countItemsFromPayload(followingRes?.data);
        _incomingRequestsCount = _countItemsFromPayload(inboxRes?.data);
        _outgoingRequestsCount = _countItemsFromPayload(outboxRes?.data);
        _tiktokAccount = _unwrapTikTokAccount(tiktokRes?.data);
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _readApiError(e, fallback: 'Could not load your workspace.');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your workspace.';
        _loading = false;
      });
    }
  }

  Future<void> _reloadTikTokOnly() async {
    final userId = _currentUserId;
    if (userId.isEmpty) return;

    if (mounted) {
      setState(() {
        _tiktokLoading = true;
      });
    }

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/v1/integrations/tiktok/account',
        queryParameters: {'userId': userId},
      );

      if (!mounted) return;

      setState(() {
        _tiktokAccount = _unwrapTikTokAccount(res.data);
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() {
          _tiktokLoading = false;
        });
      }
    }
  }

  Future<void> _connectTikTok() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _tiktokActionBusy) return;

    setState(() {
      _tiktokActionBusy = true;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/v1/integrations/tiktok/connect/start',
        queryParameters: {'userId': userId},
      );

      final payload = _asMap(res.data);
      final authorizationUrl = _firstNonEmpty([
        _value(payload['authorizationUrl']),
        _value(payload['url']),
        _value(payload['authUrl']),
      ]);

      if (authorizationUrl.isEmpty) {
        throw Exception('TikTok authorization URL was not returned.');
      }

      final uri = Uri.tryParse(authorizationUrl);
      if (uri == null) {
        throw Exception('TikTok authorization URL is invalid.');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (!launched) {
        throw Exception('Could not open TikTok authorization.');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TikTok authorization opened. Return here after approval.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start TikTok connection: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _tiktokActionBusy = false;
        });
      }
    }
  }

  Future<void> _refreshTikTokToken() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _tiktokActionBusy) return;

    setState(() {
      _tiktokActionBusy = true;
    });

    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/v1/integrations/tiktok/refresh',
        data: {'userId': userId},
      );

      await _reloadTikTokOnly();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TikTok connection refreshed.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _readApiError(e, fallback: 'Could not refresh TikTok connection.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh TikTok connection: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _tiktokActionBusy = false;
        });
      }
    }
  }

  Future<void> _disconnectTikTok() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _tiktokActionBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Disconnect TikTok'),
          content: const Text(
            'This will remove your TikTok connection from Aura.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _tiktokActionBusy = true;
    });

    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/v1/integrations/tiktok/disconnect',
        data: {'userId': userId},
      );

      if (!mounted) return;

      setState(() {
        _tiktokAccount = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TikTok disconnected.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _readApiError(e, fallback: 'Could not disconnect TikTok.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not disconnect TikTok: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _tiktokActionBusy = false;
        });
      }
    }
  }

  String get _currentUserId => _value((_user ?? const <String, dynamic>{})['id']);

  bool get _isTikTokConnected {
    final account = _tiktokAccount;
    if (account == null) return false;

    final connected = account['connected'];
    if (connected is bool) return connected;

    final userId = _value(account['platformUserId']);
    return userId.isNotEmpty || account.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Me',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildStateCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: AuraText.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildContent(context),
                ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final user = _user ?? <String, dynamic>{};

    final displayName = _firstNonEmpty([
      _value(user['displayName']),
      _value(user['name']),
    ]);
    final handle = _value(user['handle']);
    final bio = _firstNonEmpty([
      _value(user['bio']),
      _value(user['headline']),
      _value(user['summary']),
    ]);

    final avatarUrl = _resolveMediaUrl(
      _firstNonEmpty([
        _value(user['avatarUrl']),
        _value(user['avatar']),
        _value(user['photoUrl']),
      ]),
    );

    final coverUrl = _resolveMediaUrl(
      _firstNonEmpty([
        _value(user['coverUrl']),
        _value(user['bannerUrl']),
        _value(user['coverImageUrl']),
        _value(user['headerImageUrl']),
      ]),
    );

    final locationText = _locationText(user);
    final websiteUrl = _websiteText(user);
    final websiteLabel = _websiteLabel(websiteUrl);

    final displayTitle = displayName.isNotEmpty ? displayName : 'Profile';
    final displayHandle = handle;
    final meta = <Widget>[
      if (locationText.isNotEmpty) _metaChip(label: locationText),
      if (websiteLabel.isNotEmpty) _metaChip(label: websiteLabel),
      if (_incomingRequestsCount > 0)
        _metaChip(label: 'Requests $_incomingRequestsCount'),
      if (_outgoingRequestsCount > 0)
        _metaChip(label: 'Sent $_outgoingRequestsCount'),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PresenceHeader(
                  displayName: displayTitle,
                  handle: displayHandle,
                  bio: bio,
                  avatarUrl: avatarUrl,
                  coverUrl: coverUrl,
                  trailingMeta: meta,
                  actions: [
                    PresenceHeaderAction(
                      label: 'Edit profile',
                      icon: Icons.edit_outlined,
                      primary: true,
                      onTap: () async {
                        await context.push('/me/edit');
                        if (!mounted) return;
                        await _load();
                      },
                    ),
                    PresenceHeaderAction(
                      label: 'Security',
                      icon: Icons.lock_outline,
                      onTap: () => context.push('/security'),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.lg),
                _summaryStrip(
                  context: context,
                  handle: handle,
                ),
                const SizedBox(height: AuraSpace.lg),
                _section(
                  title: 'Personal',
                  children: [
                    if (handle.isNotEmpty)
                      _item(
                        label: 'View public profile',
                        icon: Icons.visibility_outlined,
                        subtitle: '@$handle',
                        onTap: () => context.push('/u/$handle'),
                      ),
                    _item(
                      label: 'Compose',
                      icon: Icons.edit_note_outlined,
                      onTap: () => context.push('/compose'),
                    ),
                    _item(
                      label: 'Saved',
                      icon: Icons.bookmark_border_outlined,
                      onTap: () => context.push('/saved'),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.lg),
                _section(
                  title: 'Correspondence',
                  children: [
                    _item(
                      label: 'Correspondence hub',
                      icon: Icons.forum_outlined,
                      onTap: () => context.push('/me/correspondence'),
                    ),
                    _item(
                      label: 'New conversation',
                      icon: Icons.chat_bubble_outline,
                      onTap: () =>
                          context.push('/me/correspondence/create/conversation'),
                    ),
                    _item(
                      label: 'Create space',
                      icon: Icons.groups_outlined,
                      onTap: () =>
                          context.push('/me/correspondence/create/space'),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.lg),
                _section(
                  title: 'Institution',
                  children: [
                    _item(
                      label: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      onTap: () => context.push('/institution/dashboard'),
                    ),
                    _item(
                      label: 'Profile',
                      icon: Icons.apartment_outlined,
                      onTap: () => context.push('/institution/profile'),
                    ),
                    _item(
                      label: 'Domains',
                      icon: Icons.domain_verification_outlined,
                      onTap: () => context.push('/institution/domains'),
                    ),
                    _item(
                      label: 'Announcements',
                      icon: Icons.campaign_outlined,
                      onTap: () => context.push('/institution/announcements'),
                    ),
                    _item(
                      label: 'Correspondence',
                      icon: Icons.mail_outline,
                      onTap: () => context.push('/institution/correspondence'),
                    ),
                    _item(
                      label: 'Verification',
                      icon: Icons.verified_outlined,
                      onTap: () =>
                          context.push('/institution/request-verification'),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.lg),
                _section(
                  title: 'Platform',
                  children: [
                    _tiktokBlock(),
                    _item(
                      label: 'Announcements workspace',
                      icon: Icons.campaign_outlined,
                      onTap: () => context.push('/announcements'),
                    ),
                    _item(
                      label: 'Create announcement',
                      icon: Icons.add_circle_outline,
                      onTap: () => context.push('/create'),
                    ),
                    _item(
                      label: 'Updates',
                      icon: Icons.notifications_none_outlined,
                      onTap: () => context.push('/updates'),
                    ),
                    _item(
                      label: 'Institution approvals',
                      icon: Icons.approval_outlined,
                      subtitle: 'Place route when ready',
                      onTap: null,
                    ),
                    _item(
                      label: 'Contact CRM',
                      icon: Icons.perm_contact_calendar_outlined,
                      subtitle: 'Place route when ready',
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.lg),
                _section(
                  title: 'Account',
                  children: [
                    _item(
                      label: 'Security',
                      icon: Icons.lock_outline,
                      onTap: () => context.push('/security'),
                    ),
                    _item(
                      label: 'Activity',
                      icon: Icons.notifications_none_outlined,
                      onTap: () => context.push('/updates'),
                    ),
                    _item(
                      label: 'Search',
                      icon: Icons.search,
                      onTap: () => context.push('/search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tiktokBlock() {
    final connected = _isTikTokConnected;
    final platformUserId = _value((_tiktokAccount ?? const <String, dynamic>{})['platformUserId']);
    final username = _value((_tiktokAccount ?? const <String, dynamic>{})['username']);
    final accountLabel = _firstNonEmpty([
      username,
      platformUserId,
      connected ? 'Connected' : '',
    ]);

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AuraSpace.s12,
        horizontal: AuraSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note_outlined, size: 18, color: AuraSurface.ink),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TikTok',
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tiktokLoading
                          ? 'Checking connection…'
                          : connected
                              ? accountLabel
                              : 'Not connected',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_tiktokActionBusy || _tiktokLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (!connected)
                OutlinedButton(
                  onPressed: _tiktokActionBusy ? null : _connectTikTok,
                  child: const Text('Connect'),
                ),
              if (connected)
                OutlinedButton(
                  onPressed: _tiktokActionBusy ? null : _refreshTikTokToken,
                  child: const Text('Refresh'),
                ),
              OutlinedButton(
                onPressed: (_tiktokActionBusy || _tiktokLoading)
                    ? null
                    : _reloadTikTokOnly,
                child: const Text('Check'),
              ),
              if (connected)
                OutlinedButton(
                  onPressed: _tiktokActionBusy ? null : _disconnectTikTok,
                  child: const Text('Disconnect'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStrip({
    required BuildContext context,
    required String handle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s18),
      child: Wrap(
        spacing: AuraSpace.s12,
        runSpacing: AuraSpace.s12,
        children: [
          _summaryButton(
            label: 'Followers',
            value: _followersCount,
            onTap: handle.isEmpty ? null : () => context.push('/u/$handle/followers'),
          ),
          _summaryButton(
            label: 'Following',
            value: _followingCount,
            onTap: handle.isEmpty ? null : () => context.push('/u/$handle/following'),
          ),
          _summaryButton(
            label: 'Requests',
            value: _incomingRequestsCount,
            onTap: () => context.push('/me/follow-requests'),
          ),
          if (_outgoingRequestsCount > 0)
            _summaryButton(
              label: 'Sent',
              value: _outgoingRequestsCount,
              onTap: () => context.push('/me/follow-requests'),
            ),
        ],
      ),
    );
  }

  Widget _summaryButton({
    required String label,
    required int value,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minWidth: 140),
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s14,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.page,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: AuraText.title.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    label,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AuraSurface.muted,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateCard({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          margin: const EdgeInsets.all(AuraSpace.s16),
          padding: const EdgeInsets.all(AuraSpace.s20),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    final visibleChildren = children.where((child) => child is! SizedBox).toList();

    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AuraText.title),
            const SizedBox(height: AuraSpace.s14),
            ..._withDividers(visibleChildren),
          ],
        ),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
            color: AuraSurface.divider,
          ),
        );
      }
    }
    return items;
  }

  Widget _item({
    required String label,
    required IconData icon,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: enabled ? 1 : 0.72,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AuraSpace.s12,
            horizontal: AuraSpace.s4,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AuraSurface.ink),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle.trim(),
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (enabled)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AuraSurface.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(
          fontWeight: FontWeight.w700,
          color: AuraSurface.muted,
        ),
      ),
    );
  }

  Future<Response<dynamic>?> _safeGet(
    Dio dio,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.get(path, queryParameters: queryParameters);
    } catch (_) {
      return null;
    }
  }

  int _countItemsFromPayload(dynamic raw) {
    if (raw is List) return raw.length;

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      final items = map['items'];
      if (items is List) return items.length;

      final data = map['data'];
      if (data is List) return data.length;
      if (data is Map) {
        final nestedItems = data['items'];
        if (nestedItems is List) return nestedItems.length;

        final nestedData = data['data'];
        if (nestedData is List) return nestedData.length;
      }
    }

    return 0;
  }

  String _readApiError(DioException e, {required String fallback}) {
    final data = e.response?.data;

    if (data is Map) {
      final direct = data['message'];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }

      final error = data['error'];
      if (error is Map) {
        final nested = error['message'];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
    }

    final msg = e.message?.trim() ?? '';
    return msg.isNotEmpty ? msg : fallback;
  }

  Map<String, dynamic> _unwrapUser(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      final user = map['user'];
      if (user is Map) return Map<String, dynamic>.from(user);

      final data = map['data'];
      if (data is Map) {
        final nestedData = Map<String, dynamic>.from(data);
        final nestedUser = nestedData['user'];
        if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
        return nestedData;
      }

      return map;
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic>? _unwrapTikTokAccount(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);

    final account = map['account'];
    if (account is Map) {
      final out = Map<String, dynamic>.from(account);
      out['connected'] = true;
      return out;
    }

    final data = map['data'];
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);

      final nestedAccount = nested['account'];
      if (nestedAccount is Map) {
        final out = Map<String, dynamic>.from(nestedAccount);
        out['connected'] = true;
        return out;
      }

      if (nested.containsKey('connected') || nested.containsKey('platformUserId')) {
        return nested;
      }
    }

    if (map.containsKey('connected') || map.containsKey('platformUserId')) {
      return map;
    }

    return null;
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String _value(dynamic v) => (v ?? '').toString().trim();

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _locationText(Map<String, dynamic> user) {
    final location = _firstNonEmpty([
      _value(user['location']),
      _value(user['place']),
    ]);
    if (location.isNotEmpty) return location;

    final city = _value(user['city']);
    final country = _value(user['country']);
    return [city, country].where((e) => e.isNotEmpty).join(', ');
  }

  String _websiteText(Map<String, dynamic> user) {
    return _firstNonEmpty([
      _value(user['websiteUrl']),
      _value(user['website']),
      _value(user['site']),
      _value(user['url']),
    ]);
  }

  String _websiteLabel(String website) {
    final value = website.trim();
    if (value.isEmpty) return '';

    final withScheme = value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value';

    final uri = Uri.tryParse(withScheme);
    final host = uri?.host.trim() ?? '';
    if (host.isEmpty) return value;

    return host.startsWith('www.') ? host.substring(4) : host;
  }

  String _resolveMediaUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;

    final baseOrigin = Uri.base.origin;
    if (value.startsWith('/')) {
      return '$baseOrigin$value';
    }

    return '$baseOrigin/$value';
  }
}