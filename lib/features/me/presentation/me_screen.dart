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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/v1/users/me');
      final data = _unwrapUser(res.data);

      if (!mounted) return;

      setState(() {
        _user = data;
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
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final user = _user ?? <String, dynamic>{};

    final displayName = _value(user['displayName']);
    final handle = _value(user['handle']);
    final bio = _value(user['bio']);
    final avatarUrl = _value(user['avatarUrl']);
    final coverUrl = _value(user['coverUrl']);

    return ListView(
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
          actions: [
            PresenceHeaderAction(
              label: 'Edit profile',
              primary: true,
              icon: Icons.edit_outlined,
              onTap: () => context.push('/edit-profile'),
            ),
            PresenceHeaderAction(
              label: 'Settings',
              icon: Icons.settings_outlined,
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.xl),
        _section(
          title: 'Creations',
          children: [
            _item(
              label: 'Posts',
              icon: Icons.article_outlined,
              onTap: () => context.push('/me/posts'),
            ),
            _item(
              label: 'Media',
              icon: Icons.perm_media_outlined,
              onTap: () => context.push('/me/media'),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.lg),
        _section(
          title: 'Correspondence',
          children: [
            _item(
              label: 'Threads',
              icon: Icons.forum_outlined,
              onTap: () => context.push('/correspondence'),
            ),
            _item(
              label: 'Spaces',
              icon: Icons.groups_outlined,
              onTap: () => context.push('/spaces'),
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
              onTap: () => context.push('/me/followers'),
            ),
            _item(
              label: 'Following',
              icon: Icons.person_add_alt_1_outlined,
              onTap: () => context.push('/me/following'),
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
            Text(
              title,
              style: AuraText.title,
            ),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
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
              child: Text(
                label,
                style: AuraText.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
}