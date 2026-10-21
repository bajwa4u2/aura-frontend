import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/net/dio_provider.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import 'connect_return_watcher.dart';

Map<String, dynamic> _unwrap(dynamic data) {
  var m = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  if (m['data'] is Map) m = Map<String, dynamic>.from(m['data'] as Map);
  return m;
}

/// One Page the member manages, as the server lists it (never a token).
class FacebookPageOption {
  const FacebookPageOption({
    required this.id,
    required this.name,
    required this.canPost,
    this.pictureUrl,
  });

  final String id;
  final String name;
  final bool canPost;
  final String? pictureUrl;

  factory FacebookPageOption.fromJson(Map<String, dynamic> j) =>
      FacebookPageOption(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? 'Facebook Page'}',
        canPost: j['canPost'] == true,
        pictureUrl: (j['pictureUrl'] as String?)?.trim().isEmpty == true
            ? null
            : j['pictureUrl'] as String?,
      );
}

/// FACEBOOK PAGE, under Connected accounts (2026-10-20).
///
/// Facebook lets no app post to a personal profile, so a member connects
/// their Facebook and chooses ONE Page they manage; posts they choose to share
/// go to that Page. Self-contained: it reads and changes its own connection,
/// and opens the Page chooser when Facebook sends the member back with
/// `?facebook=choose-page`.
class FacebookPageConnection extends ConsumerStatefulWidget {
  const FacebookPageConnection({super.key});

  @override
  ConsumerState<FacebookPageConnection> createState() =>
      _FacebookPageConnectionState();
}

class _FacebookPageConnectionState
    extends ConsumerState<FacebookPageConnection> {
  bool _loading = true;
  bool _busy = false;
  bool _expanded = false;
  bool _connected = false;
  bool _needsPage = false;
  String? _pageName;
  String? _instagram;

  /// Why the chosen Page shows no Instagram: NOT_GRANTED or NOT_LINKED.
  String? _instagramMissing;
  bool _handledReturn = false;

  /// Whether this member may connect a Facebook Page yet (2026-10-21). Until
  /// Meta completes its review of Aura, Facebook refuses everyone without a
  /// role on Aura's Meta app, so the server says who may. An older server
  /// does not say; then the row behaves as it always has.
  bool _available = true;
  String? _unavailableReason;

  /// The installed app's return from Facebook's consent page: the member
  /// approves in the system browser, so the app re-reads the connection when
  /// it comes back to the front and, if a Page is still to be chosen, opens
  /// the chooser — once per Connect.
  final ConnectReturnWatcher _connectReturn = ConnectReturnWatcher();

  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _connectReturn.dispose();
    super.dispose();
  }

  Future<void> _afterConnectReturn() async {
    await _load();
    if (!mounted) return;
    if (_needsPage) {
      await _choosePage();
    } else if (_connected) {
      _say('Facebook Page connected.');
    } else {
      _say('Facebook is not connected. You can try again.');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledReturn) return;
    String? back;
    try {
      back = GoRouterState.of(context).uri.queryParameters['facebook'];
    } catch (_) {
      back = null;
    }
    if (back == null) return;
    _handledReturn = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (back == 'choose-page') {
        await _load();
        if (mounted) await _choosePage();
      } else if (back == 'error') {
        String? message;
        try {
          message = GoRouterState.of(context).uri.queryParameters['message'];
        } catch (_) {}
        _say(message?.trim().isNotEmpty == true
            ? message!
            : 'Facebook did not connect.');
      } else if (back == 'connected') {
        _say('Facebook Page connected.');
      }
    });
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = _unwrap((await _dio.get('/integrations/facebook/account')).data);
      final page = r['page'] is Map ? Map<String, dynamic>.from(r['page'] as Map) : null;
      if (!mounted) return;
      setState(() {
        _connected = r['connected'] == true;
        _needsPage = r['needsPage'] == true;
        _pageName = (page?['name'] as String?)?.trim();
        final ig = r['instagram'] is Map ? Map<String, dynamic>.from(r['instagram'] as Map) : null;
        _instagram = ig == null ? null : '${ig['username'] ?? ''}'.trim();
        _instagramMissing = r['instagramMissing'] as String?;
        _available = r['available'] != false;
        final reason = '${r['unavailableReason'] ?? ''}'.trim();
        _unavailableReason = reason.isEmpty ? null : reason;
      });
    } catch (_) {
      // Unknown, not "not connected": leave what was shown.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final r = _unwrap(
        (await _dio.get(
          connectStartPath('/integrations/facebook/connect/start'),
        ))
            .data,
      );
      final uri = Uri.tryParse('${r['authorizationUrl'] ?? ''}');
      if (uri == null || !uri.hasScheme) throw Exception('No address returned');
      final opened = await launchUrl(uri, mode: connectLaunchMode());
      if (!opened) throw Exception('Could not open Facebook');
      _connectReturn.arm(_afterConnectReturn);
      _say('Facebook opened. Approve there, then choose your Page.');
    } catch (_) {
      _say('Facebook could not be opened right now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choosePage() async {
    List<FacebookPageOption> pages;
    try {
      final r = _unwrap((await _dio.get('/integrations/facebook/pages')).data);
      pages = ((r['pages'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => FacebookPageOption.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      _say('Your Facebook Pages could not be loaded. Please try again.');
      return;
    }
    if (!mounted) return;
    final chosen = await showFacebookPagePicker(context, pages);
    if (chosen == null) return;
    setState(() => _busy = true);
    try {
      await _dio.post(
        '/integrations/facebook/pages/select',
        data: {'pageId': chosen.id},
      );
      _say('Posts you share will go to ${chosen.name}.');
      await _load();
    } catch (_) {
      _say('That Page could not be chosen. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await _dio.post('/integrations/facebook/disconnect');
      _say('Facebook disconnected.');
      await _load();
    } catch (_) {
      _say('Facebook could not be disconnected. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _connected && !_needsPage;
    final closed = !_loading && !_connected && !_available;
    final status = _loading
        ? 'Checking connection…'
        : closed
            ? (_unavailableReason ??
                'Sharing to a Facebook Page opens once Meta completes its review of Aura.')
        : !_connected
            ? 'Not connected'
            : _needsPage
                ? 'Choose a Page to share to'
                : [
                    _pageName?.isNotEmpty == true ? _pageName! : 'Connected',
                    if (_instagram != null)
                      _instagram!.isEmpty ? 'Instagram linked' : 'Instagram @$_instagram',
                  ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AuraRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AuraSpace.s12,
              horizontal: AuraSpace.s4,
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 18, color: AuraSurface.ink),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Facebook Page',
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                        maxLines: closed ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: ready ? AuraSurface.coVerdant : AuraSurface.muted,
                ),
              ],
            ),
          ),
        ),
        if (_expanded && ready && _instagramMissing != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s4,
              0,
              AuraSpace.s4,
              AuraSpace.s4,
            ),
            child: Text(
              _instagramMissing == 'NOT_GRANTED'
                  ? 'Instagram was not included when you connected. Choose Add Instagram, then tick your Instagram account on Facebook.'
                  : 'This Page has no Instagram professional account linked. Link one to the Page in Meta Business Suite, then open this again.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
        if (_expanded && !closed)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s4,
              AuraSpace.s4,
              AuraSpace.s4,
              AuraSpace.s12,
            ),
            child: Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                if (!_connected)
                  AuraSecondaryButton(
                    label: 'Connect',
                    icon: Icons.link_rounded,
                    onPressed: _busy ? null : _connect,
                  ),
                if (ready && _instagramMissing != null)
                  AuraSecondaryButton(
                    label: 'Add Instagram',
                    icon: Icons.photo_camera_outlined,
                    onPressed: _busy ? null : _connect,
                  ),
                if (_connected)
                  AuraSecondaryButton(
                    label: _needsPage ? 'Choose Page' : 'Change Page',
                    icon: Icons.swap_horiz_rounded,
                    onPressed: _busy ? null : _choosePage,
                  ),
                if (_connected)
                  AuraGhostButton(
                    label: 'Disconnect',
                    icon: Icons.link_off_rounded,
                    onPressed: _busy ? null : _disconnect,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The Page chooser. Pages the member cannot post to are shown, disabled,
/// so a missing Page is explained rather than mysterious.
Future<FacebookPageOption?> showFacebookPagePicker(
  BuildContext context,
  List<FacebookPageOption> pages,
) {
  return showModalBottomSheet<FacebookPageOption>(
    context: context,
    backgroundColor: AuraSurface.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.r14)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Share to which Facebook Page?', style: AuraText.subtitle),
            const SizedBox(height: AuraSpace.s4),
            const Text(
              'Posts you choose to share will appear on this Page, with a link back to Aura. If the Page has Instagram linked, you can share there too.',
              style: AuraText.small,
            ),
            const SizedBox(height: AuraSpace.s12),
            if (pages.isEmpty)
              const Text(
                'Facebook shows no Pages you manage. Create a Page on Facebook, or ask its admin to give you access, then try again.',
                style: AuraText.body,
              ),
            for (final p in pages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AuraAvatar(name: p.name, imageUrl: p.pictureUrl, size: 36),
                title: Text(p.name, style: AuraText.body),
                subtitle: p.canPost
                    ? null
                    : const Text('You cannot post to this Page', style: AuraText.small),
                enabled: p.canPost,
                onTap: p.canPost ? () => Navigator.of(ctx).pop(p) : null,
              ),
          ],
        ),
      ),
    ),
  );
}
