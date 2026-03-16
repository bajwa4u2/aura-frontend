import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

import '../../profile/presentation/widgets/profile_header.dart';

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  Map<String, dynamic>? user;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/v1/users/me');

      setState(() {
        user = res.data['user'];
        loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Profile',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: AuraText(error!))
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final u = user!;

    return ListView(
      children: [
        /// HEADER
        ProfileHeader(
          displayName: u['displayName'] ?? '',
          handle: u['handle'] ?? '',
          bio: u['bio'],
          avatarUrl: u['avatarUrl'],
          coverUrl: u['coverUrl'],
          isMe: true,
        ),

        AuraSpace.xl,

        /// ACTIONS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _actionButton(
                context,
                label: 'Edit profile',
                icon: Icons.edit_outlined,
                onTap: () => context.push('/edit-profile'),
              ),
              _actionButton(
                context,
                label: 'Settings',
                icon: Icons.settings_outlined,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),

        AuraSpace.xl,

        /// WORK
        _section(
          title: 'Creations',
          children: [
            _item(
              context,
              'Posts',
              Icons.article_outlined,
              () => context.push('/me/posts'),
            ),
            _item(
              context,
              'Media',
              Icons.perm_media_outlined,
              () => context.push('/me/media'),
            ),
          ],
        ),

        AuraSpace.l,

        /// CORRESPONDENCE
        _section(
          title: 'Correspondence',
          children: [
            _item(
              context,
              'Threads',
              Icons.forum_outlined,
              () => context.push('/correspondence'),
            ),
            _item(
              context,
              'Spaces',
              Icons.groups_outlined,
              () => context.push('/spaces'),
            ),
          ],
        ),

        AuraSpace.l,

        /// CONNECTIONS
        _section(
          title: 'Connections',
          children: [
            _item(
              context,
              'Followers',
              Icons.people_outline,
              () => context.push('/me/followers'),
            ),
            _item(
              context,
              'Following',
              Icons.person_add_alt_1_outlined,
              () => context.push('/me/following'),
            ),
          ],
        ),

        AuraSpace.xxl,
      ],
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AuraSurface(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuraText.title(title),
            AuraSpace.m,
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: AuraText(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}