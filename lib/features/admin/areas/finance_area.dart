/// THE DOORWAY, AND NOTHING BEHIND IT.
///
/// This surface exists to send an authorised principal to
/// `finance.auraplatform.org`. It must never acquire a profit and loss
/// statement, a cash balance, a journal, transactions, reports, Finance role
/// logic or any ledger state.
///
/// Building any of those here would create a SECOND Finance frontend, and two
/// frontends over one ledger disagree eventually. One canonical Finance
/// application; Aura Admin owns the door.
///
/// Note what this screen does NOT display: no figures, no counts, no book
/// names, no last-updated. Everything on it is true of the Finance SYSTEM, not
/// of the company's finances.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/admin_providers.dart';
import '../domain/finance_entry.dart';

/// Where Finance lives, as Aura's configuration reports it.
///
/// NOT A CONSTANT IN THIS FILE, deliberately, and that is the point of the
/// provider. A hostname compiled into a mobile binary needs an app store
/// release to change; Finance must be able to move without Aura shipping a
/// client. This is presentation only — the destination a person is about to be
/// sent to, so they can see it before they go. The ROUTE comes from the server
/// on every press and never from here.
///
/// Absent on any failure. A doorway that cannot name its destination still
/// opens it; it simply does not claim to know the address.
final financeDestinationOriginProvider = FutureProvider<String?>((ref) async {
  try {
    return await ref.watch(adminRepositoryProvider).fetchFinanceDestination();
  } catch (_) {
    return null;
  }
});

/// How wide the doorway's content should be in a pane of [paneWidth].
///
/// A NAMED RULE RATHER THAN AN EXPRESSION BURIED IN A BUILDER, because it is
/// the part of the tablet story that can actually be asserted. Measuring a
/// laid-out paragraph proved almost nothing: a full-bleed layout and a
/// correctly-constrained one differed by thirty pixels once the rail and the
/// card padding had taken their share, so a widget test could not tell them
/// apart. This can be tested exactly, at every geometry, and it is the same
/// function the widget uses.
///
/// A tablet is not a big phone or a small desktop. At 834 or 1194 a phone-width
/// column sits adrift in the pane and a full-bleed one is unreadable prose, so
/// the measure grows with the pane and then stops.
/// THE GUTTER RAMPS IN; IT DOES NOT APPEAR ALL AT ONCE.
///
/// The first version stepped straight from "the whole pane" to "the pane minus
/// 96" at 700, so a pane of 690 gave a 690-wide measure and a pane of 700 gave
/// 604 — widening the window made the content jump NARROWER, which reads as a
/// layout glitch on any resizable surface and on every tablet rotation that
/// crosses the boundary. Found by asserting the function is monotonic rather
/// than by looking at it.
@visibleForTesting
double financeDoorwayMeasure(double paneWidth) {
  // Below this there is no room to give away, so the content takes the pane.
  const noGutterBelow = 700.0;
  const maxGutter = 96.0;
  const maxMeasure = 760.0;

  if (paneWidth <= noGutterBelow) return paneWidth;
  final gutter = math.min(maxGutter, paneWidth - noGutterBelow);
  return math.min(maxMeasure, paneWidth - gutter);
}

class FinanceArea extends ConsumerStatefulWidget {
  const FinanceArea({super.key});

  @override
  ConsumerState<FinanceArea> createState() => _FinanceAreaState();
}

class _FinanceAreaState extends ConsumerState<FinanceArea> {
  @override
  void initState() {
    super.initState();
    // BOUNDED, AND LIFECYCLE-AWARE. The eligibility answer is fetched once and
    // cached for the session, so the shell can watch it from four places
    // without four requests and without a poll. Re-asking on ENTRY is the one
    // moment it matters: a grant revoked mid-session would otherwise leave a
    // door drawn until the app restarted.
    //
    // Deliberately not a timer. A doorway that re-interrogates Finance on a
    // schedule is a flood with a polite name, and the door is not the security
    // boundary anyway — Finance refuses independently at its own callback.
    Future.microtask(() {
      if (mounted) ref.invalidate(financeEntryProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(financeDestinationVisibleProvider);

    // DEFENCE IN DEPTH, NOT DECORATION. The shell already hides this
    // destination, but hiding a navigation item is user experience, never a
    // security boundary. A principal who reaches this route directly must find
    // nothing, and Finance itself refuses independently at the door regardless
    // of what this screen renders.
    if (!visible) return const _FinanceNotAvailable();

    return const _FinanceDoorway();
  }
}

/// What an unauthorised principal sees at this route.
///
/// Says the ROUTE does not exist for them, and says nothing about Finance:
/// not that a Finance system exists, not that access could be requested, not
/// that books or figures are behind it. "You lack permission for Finance"
/// would itself disclose that there is a Finance to lack permission for.
class _FinanceNotAvailable extends StatelessWidget {
  const _FinanceNotAvailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Not available', style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              Text(
                'This area is not available for your account.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceDoorway extends ConsumerStatefulWidget {
  const _FinanceDoorway();

  @override
  ConsumerState<_FinanceDoorway> createState() => _FinanceDoorwayState();
}

class _FinanceDoorwayState extends ConsumerState<_FinanceDoorway> {
  bool _opening = false;
  String? _failure;

  /// Begin the handoff.
  ///
  /// ONE JOURNEY, on every platform. Aura mints a single-use, two-minute
  /// browser-entry ticket; the browser opens Aura's own start endpoint, which
  /// converts it into a narrow, path-scoped cookie and bounces to Finance's
  /// sign-in. Finance sets its state cookie, sends the browser back to Aura's
  /// authorize endpoint for a single-use code, and redeems that code server to
  /// server for an identity document.
  ///
  /// A web browser already carries Aura's session and could walk into Finance
  /// unaided; it goes the same way anyway, so there is one code path to certify
  /// and no client holds Finance's address.
  ///
  /// Native deliberately opens the EXTERNAL browser rather than an in-app web
  /// view: an in-app view has its own cookie jar, so Finance's session would
  /// vanish when the sheet closed, and the founder would sign in again every
  /// time. It also keeps the address bar visible, which is the only way a
  /// person can confirm which origin is asking them for anything.
  Future<void> _open() async {
    setState(() {
      _opening = true;
      _failure = null;
    });
    try {
      // ONE JOURNEY FOR EVERY PLATFORM. The web browser already carries Aura's
      // session and would not strictly need a ticket, but sending it through
      // the same start endpoint buys two things worth more than a saved round
      // trip: one code path to certify, and no Aura client anywhere with
      // Finance's address compiled into it.
      final target = Uri.parse(
        await ref.read(adminRepositoryProvider).beginFinanceBrowserEntry(),
      );

      final launched = await launchUrl(
        target,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      if (!launched && mounted) {
        setState(() => _failure = 'Finance could not be opened. Try again.');
      }
    } catch (_) {
      // One message for every failure. Whether Aura refused the ticket,
      // Finance is unreachable or the browser would not open is an operational
      // fact, and telling them apart HERE would report on a system the reader
      // may hold no authority over.
      if (mounted) {
        setState(() => _failure = 'Finance could not be opened. Try again.');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // COMPOSES AT TABLET GEOMETRY rather than inheriting a phone column or
        // a desktop expanse. An iPad in landscape is 1024–1366 wide: a single
        // 640-wide column centred in that leaves the content adrift, and a
        // full-bleed row makes the prose unreadable. The measure grows with
        // the pane and then stops.
        final width = constraints.maxWidth;
        final maxContent = financeDoorwayMeasure(width);
        final pad = width >= 700 ? 32.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(FinanceDestination.icon,
                          size: 28, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child:
                              Text('Finance', style: theme.textTheme.headlineSmall),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The financial record of Aura Platform LLC lives in its own system, with its '
                    'own authority and its own session. Aura Admin is the way in; it does not hold '
                    'the books.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 28),

                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What happens when you continue',
                              style: theme.textTheme.titleSmall),
                          const SizedBox(height: 12),
                          // Describes the MECHANISM, not any financial content.
                          const _Step(
                            'Aura confirms who you are through the account you are already signed in to.',
                          ),
                          const _Step(
                            'Finance establishes its own session, separate from this one, with a shorter '
                            'idle timeout.',
                          ),
                          const _Step(
                            'Finance resolves your grant and opens the book you are authorised for.',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            kIsWeb
                                ? 'No second password, and nothing to copy across.'
                                : 'Finance opens in your browser. No second password, and nothing '
                                    'to copy across.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_failure != null) ...[
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _failure!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  // A real 48-logical-pixel target on touch, and a focusable,
                  // Enter/Space-activatable control on desktop — which is what
                  // FilledButton already is, provided nothing steals its focus
                  // node. Autofocus is deliberate: this screen has exactly one
                  // action, so keyboard arrival should land on it.
                  Semantics(
                    button: true,
                    label: 'Open the Finance workspace at finance.auraplatform.org',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton.icon(
                        autofocus: true,
                        onPressed: _opening ? null : _open,
                        icon: _opening
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(_opening ? 'Opening Finance' : 'Open Finance'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // The destination, readable and copyable. A person should be
                  // able to see which origin they are about to be sent to —
                  // and when Aura cannot name it, the line is simply absent
                  // rather than guessed.
                  ref.watch(financeDestinationOriginProvider).maybeWhen(
                        data: (origin) => origin == null
                            ? const SizedBox.shrink()
                            : SelectableText(
                                origin,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 12),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
          ),
        ],
      ),
    );
  }
}
