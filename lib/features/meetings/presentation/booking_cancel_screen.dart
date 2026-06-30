import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';
import '../application/meetings_provider.dart';

class BookingCancelScreen extends ConsumerStatefulWidget {
  final String token;
  const BookingCancelScreen({super.key, required this.token});

  @override
  ConsumerState<BookingCancelScreen> createState() =>
      _BookingCancelScreenState();
}

class _BookingCancelScreenState extends ConsumerState<BookingCancelScreen> {
  bool _loading = true;
  bool _cancelled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cancel();
  }

  Future<void> _cancel() async {
    try {
      await ref
          .read(availabilityRepositoryProvider)
          .cancelBookingByToken(widget.token);
      setState(() {
        _cancelled = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'This link may have already been used or has expired.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GuestShell(
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s24),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(AuraSpace.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: AuraSpace.s16),
                      const Text('Cancelling your booking…'),
                    ] else if (_cancelled) ...[
                      const Icon(
                        Icons.cancel_rounded,
                        size: 60,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      Text(
                        'Booking cancelled',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        'Your booking has been cancelled.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s24),
                      OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Back to home'),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 60,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      Text(
                        'Could not cancel',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        _error ?? 'This link may have already been used.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s24),
                      OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Back to home'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s32),
        ],
      ),
    );
  }
}
