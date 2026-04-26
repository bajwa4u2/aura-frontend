import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../feed/domain/post.dart';
import '../../feed/providers.dart';

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

const _navy = Color(0xFF050B24);
const _violet = Color(0xFFB65CFF);
const _cyan = Color(0xFF2CC7FF);
const _panel = Color(0xB3141A36);
const _line = Color(0x26FFFFFF);
const _muted = Color(0xFFB8BED6);

class PublicHomeScreen extends ConsumerWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: _navy,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.45, -0.25),
            radius: 1.3,
            colors: [Color(0xFF1B1464), _navy],
          ),
        ),
        child: SafeArea(
          child: worksAsync.when(
            data: (posts) => _FlagshipPublicHome(posts: posts),
            loading: () => const Center(
              child: CircularProgressIndicator(color: _violet),
            ),
            error: (e, _) => _FlagshipPublicHome(posts: const [], error: '$e'),
          ),
        ),
      ),
    );
  }
}

class _FlagshipPublicHome extends StatelessWidget {
  const _FlagshipPublicHome({required this.posts, this.error});

  final List<Post> posts;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1220),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 920;
            final hero = _HeroColumn(posts: posts, error: error);
            final phone = _PhonePreview(posts: posts, error: error);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 36 : 18,
                wide ? 30 : 18,
                wide ? 36 : 18,
                28,
              ),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 11, child: hero),
                        const SizedBox(width: 42),
                        Expanded(flex: 9, child: phone),
                      ],
                    )
                  : Column(
                      children: [
                        hero,
                        const SizedBox(height: 26),
                        phone,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroColumn extends StatelessWidget {
  const _HeroColumn({required this.posts, this.error});

  final List<Post> posts;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AuraBrand(size: 84),
        SizedBox(height: wide ? 46 : 28),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'One Platform.\nEvery Connection.\n'),
              TextSpan(
                text: 'Limitless Possibilities.',
                style: TextStyle(
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [_violet, _cyan, _violet],
                    ).createShader(const Rect.fromLTWH(0, 0, 520, 80)),
                ),
              ),
            ],
          ),
          style: TextStyle(
            color: Colors.white,
            height: 1.08,
            fontSize: wide ? 46 : 36,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 150,
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_violet, _cyan]),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Aura connects people, ideas, and institutions through seamless communication, trusted identity, and smart collaboration.',
          style: TextStyle(color: Color(0xFFE6E9F5), height: 1.48, fontSize: 20),
        ),
        const SizedBox(height: 18),
        _GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            error == null ? '${posts.length} real updates connected' : 'Live data unavailable — showing graceful product surface',
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 24),
        const _FeatureGrid(),
        const SizedBox(height: 34),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _PillButton(
              label: 'Join Aura',
              icon: Icons.arrow_forward_rounded,
              primary: true,
              onTap: () => context.go('/register'),
            ),
            _PillButton(
              label: 'Explore institutions',
              icon: Icons.apartment_rounded,
              onTap: () => context.go('/institutions'),
            ),
            _PillButton(
              label: 'Search platform',
              icon: Icons.search_rounded,
              onTap: () => context.go('/search'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _PromiseStrip(),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  static const items = [
    (Icons.chat_bubble_outline_rounded, 'Messaging'),
    (Icons.call_outlined, 'Calls'),
    (Icons.videocam_outlined, 'Live Sessions'),
    (Icons.notifications_none_rounded, 'Notifications'),
    (Icons.perm_media_outlined, 'Media Sharing'),
    (Icons.account_balance_outlined, 'Institutions'),
    (Icons.campaign_outlined, 'Announcements'),
    (Icons.shield_outlined, 'Trust & Safety'),
    (Icons.hub_outlined, 'AI-Powered'),
    (Icons.groups_2_outlined, 'Communities'),
    (Icons.verified_user_outlined, 'Identity'),
    (Icons.public_rounded, 'Global Reach'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth < 520 ? 2 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 2 ? 1.65 : 1.2,
          ),
          itemBuilder: (context, i) {
            final item = items[i];
            return _GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.$1, color: i.isEven ? _violet : _cyan, size: 34),
                  const SizedBox(height: 10),
                  Text(
                    item.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.posts, this.error});

  final List<Post> posts;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final topPosts = posts.take(4).toList();
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(44),
          gradient: const LinearGradient(colors: [_violet, _cyan, _violet]),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 38, offset: Offset(0, 24))],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF080D23),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('9:41', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(width: 96, height: 26, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20))),
                  const Spacer(),
                  const Icon(Icons.wifi, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  const Icon(Icons.battery_full, color: Colors.white, size: 19),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const _AuraMark(size: 46),
                  const SizedBox(width: 10),
                  const Text('AURA', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const Spacer(),
                  CircleAvatar(
                    backgroundColor: _panel,
                    child: IconButton(
                      icon: const Icon(Icons.person_outline, color: Colors.white),
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Text("What's on your mind?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _ActionTile(icon: Icons.photo_outlined, label: 'Photo', color: Colors.greenAccent.shade400)),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionTile(icon: Icons.videocam_rounded, label: 'Video', color: _cyan)),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionTile(icon: Icons.mic_none_rounded, label: 'Audio', color: _violet)),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionTile(icon: Icons.bar_chart_rounded, label: 'Poll', color: Colors.amber)),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Recent Conversations', action: 'See all', onTap: () => context.go('/search')),
              const SizedBox(height: 8),
              if (error != null)
                const _EmptyPanel(title: 'Public work is unavailable', body: 'Refresh or try again in a moment.')
              else if (topPosts.isEmpty)
                const _EmptyPanel(title: 'No public conversations yet', body: 'Real Aura activity will appear here when available.')
              else
                for (final p in topPosts) _ConversationRow(post: p),
              const SizedBox(height: 18),
              _SectionTitle(title: 'Announcements', action: 'Open', onTap: () => context.go('/announcements')),
              const SizedBox(height: 10),
              _GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const _IconBubble(icon: Icons.campaign_rounded),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Platform updates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('Official announcements and institutional signals appear here.', style: TextStyle(color: _muted, height: 1.3)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Live', style: TextStyle(color: _cyan, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _BottomNav(onHome: () => context.go('/'), onChats: () => context.go('/search'), onCreate: () => context.go('/register'), onCalls: () => context.go('/contact'), onProfile: () => context.go('/login')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    final m = _asMap(a);
    final name = ((m['displayName'] ?? a?.displayName ?? 'Aura member') as String).trim();
    final text = post.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return InkWell(
      onTap: () => context.push('/posts/${post.id}'),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const _IconBubble(icon: Icons.forum_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Aura member' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(text.isEmpty ? 'Shared a public update' : text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _AuraBrand extends StatelessWidget {
  const _AuraBrand({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AuraMark(size: size),
        const SizedBox(width: 22),
        Text('AURA', style: TextStyle(color: Colors.white, fontSize: size * .72, fontWeight: FontWeight.w900, letterSpacing: 5)),
      ],
    );
  }
}

class _AuraMark extends StatelessWidget {
  const _AuraMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(colors: [_violet, _cyan]).createShader(r),
      child: Icon(Icons.change_history_rounded, color: Colors.white, size: size),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 14))],
      ),
      child: child,
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.icon, required this.onTap, this.primary = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          gradient: primary ? const LinearGradient(colors: [_violet, _cyan]) : null,
          color: primary ? null : const Color(0x1612C9FF),
          border: Border.all(color: primary ? Colors.transparent : _line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, color: Colors.white, size: 19), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))],
        ),
      ),
    );
  }
}

class _PromiseStrip extends StatelessWidget {
  const _PromiseStrip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _violet),
        color: const Color(0x1112C9FF),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.favorite_border_rounded, color: _cyan), SizedBox(width: 12), Flexible(child: Text('Built for today. Designed for tomorrow.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)))],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [Icon(icon, color: color), const SizedBox(height: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))]),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(width: 48, height: 48, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_violet, _cyan]), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action, required this.onTap});
  final String title;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))), TextButton(onPressed: onTap, child: Text(action, style: const TextStyle(color: _cyan)))]);
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    return _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(body, style: const TextStyle(color: _muted, height: 1.35))]));
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.onHome, required this.onChats, required this.onCreate, required this.onCalls, required this.onProfile});
  final VoidCallback onHome;
  final VoidCallback onChats;
  final VoidCallback onCreate;
  final VoidCallback onCalls;
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _NavIcon(icon: Icons.home_rounded, label: 'Home', selected: true, onTap: onHome),
        _NavIcon(icon: Icons.chat_bubble_outline_rounded, label: 'Chats', onTap: onChats),
        InkWell(onTap: onCreate, borderRadius: BorderRadius.circular(22), child: Container(width: 54, height: 54, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_violet, Color(0xFF7A3CFF)])), child: const Icon(Icons.add_rounded, color: Colors.white, size: 32))),
        _NavIcon(icon: Icons.call_outlined, label: 'Calls', onTap: onCalls),
        _NavIcon(icon: Icons.person_outline, label: 'Profile', onTap: onProfile),
      ],
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.label, required this.onTap, this.selected = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: Column(children: [Icon(icon, color: selected ? _violet : _muted), Text(label, style: TextStyle(color: selected ? _violet : _muted, fontSize: 11, fontWeight: FontWeight.w700))]));
  }
}
