import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/continuation/acquisition_contract.dart';

/// A quiet, non-blocking continuation affordance for eligible public pages.
///
/// THREE RULES, ALL FROM THE CONTRACT
/// ----------------------------------
/// 1. Never a forced interstitial. This is a dismissible strip; the page below
///    it is complete and usable whether or not anyone ever touches it.
/// 2. Never a fake Open state. "Open in Aura" appears only where a RELEASED
///    client can actually route the destination. Association being configured
///    in this source tree is not the same thing, and offering Open against a
///    client that cannot route it opens the old app at home — losing exactly
///    the thing the person tapped.
/// 3. Never advertise distribution that does not exist. Android is in closed
///    testing, so a general visitor cannot install from the Play link; on
///    Android nothing is offered rather than a door that does not open.
///
/// Installation is deliberately NOT detected. The OS association layer owns
/// that decision, and every "is the app installed" trick on the web is either
/// a fingerprinting probe or a guess that fails silently.
class PublicAppAcquisition extends StatefulWidget {
  const PublicAppAcquisition({super.key, this.productName = 'Aura'});

  final String productName;

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
      _dismissed =
          preferences.getBool(PublicAppAcquisition._dismissedKey) ?? false;
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

  /// The canonical URL of the page being read.
  ///
  /// The canonical public URL IS the continuation identity — there is no
  /// second app link to construct. Handing the OS the same URL the person is
  /// already on is what lets the association layer decide.
  Uri _canonicalDestination(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Uri(scheme: 'https', host: 'auraplatform.org', path: path);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_loaded || _dismissed) return const SizedBox.shrink();

    final action = acquisitionActionFor(defaultTargetPlatform);
    if (action == AcquisitionAction.none) return const SizedBox.shrink();

    final Uri destination;
    final String label;
    if (action == AcquisitionAction.open) {
      destination = _canonicalDestination(context);
      label = 'Open in ${widget.productName}';
    } else {
      final store = storeUrlFor(defaultTargetPlatform);
      if (store == null) return const SizedBox.shrink();
      destination = Uri.parse(store);
      label = 'Get ${widget.productName}';
    }

    return Semantics(
      container: true,
      label: '${widget.productName} app options',
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
                  Expanded(
                    child: Text(
                      action == AcquisitionAction.open
                          ? 'This page can continue in the app.'
                          : '${widget.productName} is available as an app.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _opening ? null : () => _open(destination),
                    child: Text(label),
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

/// Eligibility is the ASSOCIATION SCOPE, from the canonical contract.
///
/// It used to be a hand-kept set of exact static paths. That set named
/// marketing pages and no dynamic object family at all, so the pages people
/// actually share — an article, a profile, an institution — offered nothing
/// while `/mission` offered the app. Precisely backwards, and invisible
/// because nothing compared that list to anything else.
bool shouldShowAuraPublicAppAcquisition(String path) =>
    isContinuationEligiblePath(path);
