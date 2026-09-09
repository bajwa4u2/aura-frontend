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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/finance_entry.dart';

/// Where the Finance workspace lives. The one canonical application.
const String kFinanceOrigin = 'https://finance.auraplatform.org';

/// Begins the trusted handoff.
///
/// The destination establishes a FINANCE-SPECIFIC session through Aura
/// identity. No password is asked for twice, no token is copied by hand, and
/// no credential is placed in a URL or in browser history: Finance initiates
/// its own short-lived, single-use, audience-bound exchange on arrival.
const String kFinanceEntryUrl = '$kFinanceOrigin/api/auth/sign-in';

class FinanceArea extends ConsumerWidget {
  const FinanceArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _FinanceDoorway extends StatefulWidget {
  const _FinanceDoorway();

  @override
  State<_FinanceDoorway> createState() => _FinanceDoorwayState();
}

class _FinanceDoorwayState extends State<_FinanceDoorway> {
  bool _opening = false;
  String? _failure;

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _failure = null;
    });
    try {
      final launched = await launchUrl(
        Uri.parse(kFinanceEntryUrl),
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (!launched && mounted) {
        setState(() => _failure = 'Finance could not be opened. Try again.');
      }
    } catch (_) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
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
                      child: Text('Finance', style: theme.textTheme.headlineSmall),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'The financial record of Aura Platform LLC lives in its own system, with its '
                'own authority and its own session. Aura Admin is the way in; it does not hold '
                'the books.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
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
                        'No second password, and nothing to copy across.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),

              if (_failure != null) ...[
                const SizedBox(height: 20),
                Text(
                  _failure!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],

              const SizedBox(height: 28),
              Semantics(
                button: true,
                label: 'Open the Finance workspace at finance.auraplatform.org',
                child: FilledButton.icon(
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
              const SizedBox(height: 12),
              SelectableText(
                kFinanceOrigin,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
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
