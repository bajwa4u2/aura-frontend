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
  // Presence surface kept under existing route/widget contract for compatibility.
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

  Map<String, dynamic>? _linkedinAccount;
  bool _linkedinLoading = false;
  bool _linkedinActionBusy = false;
  bool _handledLinkedInRedirect = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleLinkedInRedirectIfNeeded());
    });
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
        if (userId.isNotEmpty)
          _safeGet(
            dio,
            '/v1/integrations/linkedin/account',
            queryParameters: {'userId': userId},
          )
        else
          Future.value(null),
        if (userId.isNotEmpty)
          _safeGet(
            dio,
            '/integrations/linkedin/account',
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
      final linkedinRes = futures[5];
      final linkedinAltRes = futures[6];

      if (!mounted) return;

      setState(() {
        _user = user;
        _followersCount = _countItemsFromPayload(followersRes?.data);
        _followingCount = _countItemsFromPayload(followingRes?.data);
        _incomingRequestsCount = _countItemsFromPayload(inboxRes?.data);
        _outgoingRequestsCount = _countItemsFromPayload(outboxRes?.data);
        _tiktokAccount = _unwrapTikTokAccount(tiktokRes?.data);
        _linkedinAccount = _unwrapLinkedInAccount(
          linkedinRes?.data ?? linkedinAltRes?.data,
        );
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _readApiError(e, fallback: 'Could not load your presence.');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your presence.';
        _loading = false;
      });
    }
  }

  Future<void> _handleLinkedInRedirectIfNeeded() async {
    if (_handledLinkedInRedirect || !mounted) return;
    _handledLinkedInRedirect = true;

    final query = Uri.base.queryParameters;
    if (!query.containsKey('linkedin')) return;

    final state = query['linkedin']?.trim() ?? '';
    final message = query['message']?.trim() ?? '';

    await _load();
    if (!mounted) return;

    final cleanPath = Uri.base.path.isEmpty ? '/me' : Uri.base.path;
    context.go(cleanPath);

    final snack = state.toLowerCase() == 'connected'
        ? 'LinkedIn connected.'
        : (message.isNotEmpty ? message : 'LinkedIn flow finished.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snack)),
    );
  }

  Future<void> _reloadLinkedInOnly() async {
    final userId = _currentUserId;
    if (userId.isEmpty) return;

    if (mounted) {
      setState(() {
        _linkedinLoading = true;
      });
    }

    try {
      final dio = ref.read(dioProvider);
      final primary = await _safeGet(
        dio,
        '/v1/integrations/linkedin/account',
        queryParameters: {'userId': userId},
      );
      final secondary = await _safeGet(
        dio,
        '/integrations/linkedin/account',
        queryParameters: {'userId': userId},
      );

      if (!mounted) return;

      setState(() {
        _linkedinAccount = _unwrapLinkedInAccount(
          primary?.data ?? secondary?.data,
        );
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() {
          _linkedinLoading = false;
        });
      }
    }
  }

  Future<void> _connectLinkedIn() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _linkedinActionBusy) return;

    setState(() {
      _linkedinActionBusy = true;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await _getFirstSuccessful(
        dio,
        [
          '/v1/integrations/linkedin/connect/start',
          '/integrations/linkedin/connect/start',
        ],
        queryParameters: {'userId': userId},
      );

      final root = _asMap(res.data);
      final nestedData = _asMap(root['data']);
      final nestedInnerData = _asMap(nestedData['data']);

      final authorizationUrl = _firstNonEmpty([
        _value(root['authorizationUrl']),
        _value(root['url']),
        _value(root['authUrl']),
        _value(root['authorization_url']),
        _value(nestedData['authorizationUrl']),
        _value(nestedData['url']),
        _value(nestedData['authUrl']),
        _value(nestedData['authorization_url']),
        _value(nestedInnerData['authorizationUrl']),
        _value(nestedInnerData['url']),
        _value(nestedInnerData['authUrl']),
        _value(nestedInnerData['authorization_url']),
      ]);

      if (authorizationUrl.isEmpty) {
        throw Exception('LinkedIn authorization URL was not returned.');
      }

      final uri = Uri.tryParse(authorizationUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw Exception('LinkedIn authorization URL is invalid.');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (!launched) {
        throw Exception('Could not open LinkedIn authorization.');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('LinkedIn authorization opened. Return here after approval.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start LinkedIn connection: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _linkedinActionBusy = false;
        });
      }
    }
  }

  Future<void> _disconnectLinkedIn() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _linkedinActionBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Disconnect LinkedIn'),
          content: const Text(
            'This will remove your LinkedIn connection from Aura.',
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
      _linkedinActionBusy = true;
    });

    try {
      final dio = ref.read(dioProvider);
      await _postFirstSuccessful(
        dio,
        [
          '/v1/integrations/linkedin/disconnect',
          '/integrations/linkedin/disconnect',
        ],
        data: {'userId': userId},
      );

      if (!mounted) return;

      setState(() {
        _linkedinAccount = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LinkedIn disconnected.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _readApiError(e, fallback: 'Could not disconnect LinkedIn.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not disconnect LinkedIn: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _linkedinActionBusy = false;
        });
      }
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

      final root = _asMap(res.data);
      final nestedData = _asMap(root['data']);
      final nestedInnerData = _asMap(nestedData['data']);

      final authorizationUrl = _firstNonEmpty([
        _value(root['authorizationUrl']),
        _value(root['url']),
        _value(root['authUrl']),
        _value(root['authorization_url']),
        _value(nestedData['authorizationUrl']),
        _value(nestedData['url']),
        _value(nestedData['authUrl']),
        _value(nestedData['authorization_url']),
        _value(nestedInnerData['authorizationUrl']),
        _value(nestedInnerData['url']),
        _value(nestedInnerData['authUrl']),
        _value(nestedInnerData['authorization_url']),
      ]);

      if (authorizationUrl.isEmpty) {
        throw Exception('TikTok authorization URL was not returned.');
      }

      final uri = Uri.tryParse(authorizationUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
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

  bool get _isLinkedInConnected {
    final account = _linkedinAccount;
    if (account == null) return false;

    final connected = account['connected'];
    if (connected is bool) return connected;

    return _firstNonEmpty([
      _value(account['linkedinMemberId']),
      _value(account['memberId']),
      _value(account['id']),
      _value(account['sub']),
      _value(account['name']),
      _value(account['email']),
    ]).isNotEmpty;
  }

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
      title: 'Presence',
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

    final displayTitle = displayName.isNotEmpty ? displayName : 'Presence';
    final displayHandle = handle;
    final meta = <Widget>[
      if (locationText.isNotEmpty) _metaChip(label: locationText),
      if (websiteLabel.isNotEmpty)
        _metaLinkChip(
          label: websiteLabel,
          onTap: () async {
            final uri = Uri.tryParse(websiteUrl);
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          },
        ),
      if (handle.isNotEmpty)
        _metaLinkChip(
          label: '$_followersCount Followers',
          onTap: () => context.push('/u/$handle/followers'),
        ),
      if (handle.isNotEmpty)
        _metaLinkChip(
          label: '$_followingCount Following',
          onTap: () => context.push('/u/$handle/following'),
        ),
      if (_incomingRequestsCount > 0 || _outgoingRequestsCount > 0)
        _metaLinkChip(
          label: _outgoingRequestsCount > 0
              ? 'Requests $_incomingRequestsCount / $_outgoingRequestsCount'
              : 'Requests $_incomingRequestsCount',
          onTap: () => context.push('/me/follow-requests'),
        ),
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
                      label: 'Edit presence',
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
                _section(
                  title: 'Identity',
                  children: [
                    if (handle.isNotEmpty)
                      _item(
                        label: 'View public presence',
                        icon: Icons.visibility_outlined,
                        subtitle: '@$handle',
                        onTap: () => context.push('/u/$handle'),
                      ),
                  ],
                ),
                const SizedBox(height: AuraSpace.lg),
                _section(
                  title: 'Saved',
                  children: [
                    _item(
                      label: 'Saved works',
                      icon: Icons.bookmark_outline,
                      onTap: () => context.push('/saved'),
                    ),
                  ],
                ),
                if (_hasInstitutionStanding(user)) ...[
                  const SizedBox(height: AuraSpace.lg),
                  _section(
                    title: 'Institutional standing',
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
                ],
                const SizedBox(height: AuraSpace.lg),
                _section(
                  title: 'Connected accounts',
                  children: [
                    _linkedinBlock(),
                    _tiktokBlock(),
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
    final platformUserId =
        _value((_tiktokAccount ?? const <String, dynamic>{})['platformUserId']);
    final username =
        _value((_tiktokAccount ?? const <String, dynamic>{})['username']);
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

  Widget _linkedinBlock() {
    final connected = _isLinkedInConnected;
    final accountLabel = _firstNonEmpty([
      _value((_linkedinAccount ?? const <String, dynamic>{})['name']),
      _value((_linkedinAccount ?? const <String, dynamic>{})['email']),
      _value((_linkedinAccount ?? const <String, dynamic>{})['linkedinMemberId']),
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
              const Icon(
                Icons.business_center_outlined,
                size: 18,
                color: AuraSurface.ink,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LinkedIn',
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _linkedinLoading
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
              if (_linkedinActionBusy || _linkedinLoading)
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
                  onPressed: _linkedinActionBusy ? null : _connectLinkedIn,
                  child: const Text('Connect'),
                ),
              OutlinedButton(
                onPressed: (_linkedinActionBusy || _linkedinLoading)
                    ? null
                    : _reloadLinkedInOnly,
                child: const Text('Check'),
              ),
              if (connected)
                OutlinedButton(
                  onPressed: _linkedinActionBusy ? null : _disconnectLinkedIn,
                  child: const Text('Disconnect'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasInstitutionStanding(Map<String, dynamic> user) {
    final candidates = [
      user['institutionId'],
      user['institutionRole'],
      user['institutionStatus'],
      user['institutionMemberId'],
      user['institutionMembershipId'],
      user['institutionSlug'],
      user['institutionHandle'],
      user['organizationId'],
      user['organizationRole'],
      user['verifiedInstitutionId'],
    ];

    for (final value in candidates) {
      if (_value(value).isNotEmpty) return true;
    }

    final flags = [
      user['isInstitutionMember'],
      user['hasInstitutionStanding'],
      user['hasInstitutionAccess'],
      user['institutionVerified'],
      user['isInstitutionVerified'],
    ];

    for (final value in flags) {
      if (value == true) return true;
    }

    return false;
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

  Widget _metaLinkChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: _metaChip(label: label),
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

  Future<Response<dynamic>> _getFirstSuccessful(
    Dio dio,
    List<String> paths, {
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastDioError;

    for (final path in paths) {
      try {
        return await dio.get(path, queryParameters: queryParameters);
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    if (lastDioError != null) throw lastDioError;
    throw DioException(
      requestOptions: RequestOptions(path: paths.isEmpty ? '' : paths.first),
      error: 'No endpoint available.',
    );
  }

  Future<Response<dynamic>> _postFirstSuccessful(
    Dio dio,
    List<String> paths, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastDioError;

    for (final path in paths) {
      try {
        return await dio.post(
          path,
          data: data,
          queryParameters: queryParameters,
        );
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    if (lastDioError != null) throw lastDioError;
    throw DioException(
      requestOptions: RequestOptions(path: paths.isEmpty ? '' : paths.first),
      error: 'No endpoint available.',
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

  Map<String, dynamic>? _unwrapLinkedInAccount(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;

    final root = Map<String, dynamic>.from(raw);
    final data = _asMap(root['data']);
    final nestedData = _asMap(data['data']);

    final candidates = <Map<String, dynamic>>[
      _asMap(nestedData['account']),
      _asMap(data['account']),
      _asMap(root['account']),
      nestedData,
      data,
      root,
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;

      if (candidate.containsKey('connected') ||
          candidate.containsKey('linkedinMemberId') ||
          candidate.containsKey('memberId') ||
          candidate.containsKey('name') ||
          candidate.containsKey('email')) {
        return candidate;
      }
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

class PresenceScreen extends MeScreen {
  const PresenceScreen({super.key});
}
