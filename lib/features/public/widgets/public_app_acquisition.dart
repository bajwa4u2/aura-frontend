import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Product configuration for the shared public app-acquisition boundary.
///
/// The web URL remains the page, share, search, and future native-continuation
/// identity. A product supplies only its verified native capability here; it
/// does not get a second deep-link or SEO URL system.
class PublicAppAcquisitionConfig {
  const PublicAppAcquisitionConfig({
    required this.productName,
    required this.canonicalHost,
    required this.eligiblePaths,
    required this.androidOpenSupported,
    this.androidStoreUrl,
    this.iosOpenSupported = false,
    this.iosStoreUrl,
    this.windowsOpenSupported = false,
    this.windowsStoreUrl,
  });

  final String productName;
  final String canonicalHost;
  final Set<String> eligiblePaths;
  final bool androidOpenSupported;
  final Uri? androidStoreUrl;
  final bool iosOpenSupported;
  final Uri? iosStoreUrl;
  final bool windowsOpenSupported;
  final Uri? windowsStoreUrl;
}

/// A quiet, non-blocking continuation affordance for eligible public pages.
///
/// This widget deliberately does not detect whether an app is installed. The
/// operating system's App Links / Universal Links / native association layer
/// owns that decision. If no verified store destination exists, no fake
/// "Get" action is rendered and the web page remains fully usable.
class PublicAppAcquisition extends StatefulWidget {
  const PublicAppAcquisition({
    super.key,
    required this.config,
  });

  final PublicAppAcquisitionConfig config;

  static const _dismissedKey = 'public_app_acquisition.dismissed.v1';

  @override
  State<PublicAppAcquisition> createState() => _PublicAppAcquisitionState();
}

class _PublicAppAcquisitionState extends State<PublicAppAcquisition> {
  bool _loaded = false;
  bool _dismissed = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _loadDismissal();
  }

  Future<void> _loadDismissal() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = preferences.getBool(PublicAppAcquisition._dismissedKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(PublicAppAcquisition._dismissedKey, true);
  }

  Future<void> _open(Uri destination) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await launchUrl(destination, mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Uri _canonicalDestination(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Uri(scheme: 'https', host: widget.config.canonicalHost, path: path);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_loaded || _dismissed) return const SizedBox.shrink();

    final platform = defaultTargetPlatform;
    final canOpen = switch (platform) {
      TargetPlatform.android => widget.config.androidOpenSupported,
      TargetPlatform.iOS => widget.config.iosOpenSupported,
      TargetPlatform.windows => widget.config.windowsOpenSupported,
      _ => false,
    };
    final storeUrl = switch (platform) {
      TargetPlatform.android => widget.config.androidStoreUrl,
      TargetPlatform.iOS => widget.config.iosStoreUrl,
      TargetPlatform.windows => widget.config.windowsStoreUrl,
      _ => null,
    };

    if (!canOpen && storeUrl == null) return const SizedBox.shrink();

    final actionLabel = canOpen
        ? 'Open in ${widget.config.productName}'
        : 'Get ${widget.config.productName}';
    final destination = canOpen ? _canonicalDestination(context) : storeUrl!;

    return Semantics(
      container: true,
      label: '${widget.config.productName} app options',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Material(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.open_in_new_rounded, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'This page can continue in the app.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _opening ? null : () => _open(destination),
                    child: Text(actionLabel),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final auraPublicAppAcquisitionConfig = PublicAppAcquisitionConfig(
  productName: 'Aura',
  canonicalHost: 'auraplatform.org',
  eligiblePaths: {
    '/',
    '/public',
    '/mission',
    '/white-paper',
    '/founder',
    '/privacy',
    '/terms',
    '/child-safety',
    '/contact',
    '/account-deletion',
    '/investors',
    '/institutions',
    '/patrons',
    '/supporters',
    '/announcements',
    '/search',
    '/discover',
    '/spaces',
    '/aura/participation',
  },
  androidOpenSupported: true,
  androidStoreUrl: Uri.parse(
      'https://play.google.com/store/apps/details?id=org.auraplatform.app'),
  iosStoreUrl: Uri.parse(
      'https://apps.apple.com/us/app/aura-platform/id6772071135'),
  windowsStoreUrl: Uri.parse('https://apps.microsoft.com/detail/9N6CZR88F4NT'),
);

bool shouldShowAuraPublicAppAcquisition(String path) =>
    auraPublicAppAcquisitionConfig.eligiblePaths.contains(path);
