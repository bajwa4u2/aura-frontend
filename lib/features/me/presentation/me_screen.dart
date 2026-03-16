import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      ]);

      final followersRes = futures[0];
      final followingRes = futures[1];
      final inboxRes = futures[2];
      final outboxRes = futures[3];

      if (!mounted) return;

      setState(() {
        _user = user;
        _followersCount = _countItemsFromPayload(followersRes?.data);
        _followingCount = _countItemsFromPayload(followingRes?.data);
        _incomingRequestsCount = _countItemsFromPayload(inboxRes?.data);
        _outgoingRequestsCount = _countItemsFromPayload(outboxRes?.data);
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _readApiError(e, fallback: 'Could not load profile.');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load profile.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Profile',
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
      ]),
    );

    final locationText = _locationText(user);
    final websiteUrl = _websiteText(user);
    final websiteLabel = _websiteLabel(websiteUrl);

    final trailingMeta = <Widget>[
      _metaChip('Followers', _followersCount),
      _metaChip('Following', _followingCount),
      _metaChip('Requests', _incomingRequestsCount),
      if (_outgoingRequestsCount > 0) _metaChip('Sent', _outgoingRequestsCount),
      if (locationText.isNotEmpty) _textMetaChip(locationText),
      if (websiteLabel.isNotEmpty) _textMetaChip(websiteLabel),
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
        PresenceHeader(
          displayName: displayName.isNotEmpty ? displayName : 'Profile',
          handle: handle,
          bio: bio,
          avatarUrl: avatarUrl,
          coverUrl: coverUrl,
          trailingMeta: trailingMeta,
          actions: [
            PresenceHeaderAction(
              label: 'Edit profile',
              primary: true,
              icon: Icons.edit_outlined,
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
        const SizedBox(height: AuraSpace.xl),
        _section(
          title: 'Profile',
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
            if (websiteUrl.isNotEmpty)
              _item(
                label: 'Website',
                icon: Icons.language_outlined,
                subtitle: websiteUrl,
              ),
            if (locationText.isNotEmpty)
              _item(
                label: 'Location',
                icon: Icons.place_outlined,
                subtitle: locationText,
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
              onTap: () => context.push('/me/correspondence/create/conversation'),
            ),
            _item(
              label: 'Create space',
              icon: Icons.groups_outlined,
              onTap: () => context.push('/me/correspondence/create/space'),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.lg),
        _section(
          title: 'Connections',
          children: [
            _item(
              label: 'Followers',
              icon: Icons.people_outline,
              value: _followersCount > 0 ? '$_followersCount' : null,
              onTap: handle.isEmpty ? null : () => context.push('/u/$handle/followers'),
            ),
            _item(
              label: 'Following',
              icon: Icons.person_add_alt_1_outlined,
              value: _followingCount > 0 ? '$_followingCount' : null,
              onTap: handle.isEmpty ? null : () => context.push('/u/$handle/following'),
            ),
            _item(
              label: 'Follow requests',
              icon: Icons.mark_email_unread_outlined,
              value: _incomingRequestsCount > 0 ? '$_incomingRequestsCount' : null,
              onTap: () => context.push('/me/follow-requests'),
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
              onTap: () => context.push('/institution/request-verification'),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.lg),
        _section(
          title: 'App administration',
          children: [
            _item(
              label: 'Create announcement',
              icon: Icons.add_alert_outlined,
              onTap: () => context.push('/announcements/create'),
            ),
            _item(
              label: 'Announcements',
              icon: Icons.campaign_outlined,
              onTap: () => context.push('/announcements'),
            ),
            _item(
              label: 'Updates',
              icon: Icons.notifications_none_outlined,
              onTap: () => context.push('/updates'),
            ),
          ],
        ),
      ],
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
            ..._withDividers(children),
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
    String? value,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: enabled ? 1 : 0.82,
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
              if (value != null && value.trim().isNotEmpty) ...[
                Text(
                  value.trim(),
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AuraSurface.muted,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
              ],
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

  Widget _metaChip(String label, int count) {
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
        '$label $count',
        style: AuraText.small.copyWith(
          fontWeight: FontWeight.w700,
          color: AuraSurface.muted,
        ),
      ),
    );
  }

  Widget _textMetaChip(String label) {
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

  Future<Response<dynamic>?> _safeGet(Dio dio, String path) async {
    try {
      return await dio.get(path);
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