import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';
import '../application/meetings_provider.dart';

/// CANCELLING IS A DECISION, NOT A LINK YOU LAND ON.
///
/// This screen used to cancel the booking in `initState`. Opening the link —
/// from an email, a preview, a mis-tap, a second tab — destroyed the meeting
/// before the person had said anything, and the only thing offered afterwards
/// was "Back to home". Someone who clicked to CHECK their booking lost it, and
/// someone who genuinely wanted a different time was left at a dead end with
/// no way back to the calendar they had just been removed from.
///
/// It now asks first, records why, and offers the obvious next step. Three
/// states, in the order a person actually moves through them: confirm, done,
/// or an honest failure.
class BookingCancelScreen extends ConsumerStatefulWidget {
  final String token;
  const BookingCancelScreen({super.key, required this.token});

  @override
  ConsumerState<BookingCancelScreen> createState() =>
      _BookingCancelScreenState();
}

class _BookingCancelScreenState extends ConsumerState<BookingCancelScreen> {
  final TextEditingController _reason = TextEditingController();

  bool _loading = true;
  bool _working = false;
  bool _cancelled = false;
  String? _error;

  DateTime? _scheduledAt;
  String _slug = '';
  String _institutionSlug = '';
  bool _alreadyCancelled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Read the booking this link refers to. Reading is not cancelling.
  Future<void> _load() async {
    try {
      final data = await ref
          .read(availabilityRepositoryProvider)
          .getBookingByRescheduleToken(widget.token);

      // The endpoint returns identity FLAT — profileSlug / institutionSlug —
      // not a nested profile object.
      final scheduled = data['scheduledAt'];

      setState(() {
        _scheduledAt = scheduled is String ? DateTime.tryParse(scheduled) : null;
        _slug = '${data['profileSlug'] ?? ''}'.trim();
        _institutionSlug = '${data['institutionSlug'] ?? ''}'.trim();
        _alreadyCancelled =
            '${data['status'] ?? ''}'.toUpperCase() == 'CANCELLED';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'This link may have expired, or the booking no longer exists.';
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    setState(() => _working = true);
    try {
      await ref
          .read(availabilityRepositoryProvider)
          .cancelBookingByToken(widget.token, reason: _reason.text);
      if (!mounted) return;
      setState(() {
        _cancelled = true;
        _working = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'We could not cancel this booking. It may already be cancelled.';
        _working = false;
      });
    }
  }

  /// The booking page this meeting came from.
  ///
  /// Someone who cancels because the time did not suit them wants the next
  /// time, not the home page. Built from the profile the booking already
  /// names, so it returns them to the same person's calendar rather than a
  /// generic entry point.
  String? get _bookAgainRoute {
    if (_slug.isEmpty) return null;
    if (_institutionSlug.isNotEmpty) {
      return '/i/$_institutionSlug/meet/$_slug/book';
    }
    return '/meet/$_slug/book';
  }

  String _whenLabel() {
    final at = _scheduledAt?.toLocal();
    if (at == null) return '';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    final meridiem = at.hour < 12 ? 'am' : 'pm';
    return '${months[at.month - 1]} ${at.day}, ${at.year} at '
        '$hour:$minute $meridiem';
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _body(theme),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(ThemeData theme) {
    if (_loading) {
      return const [
        Center(child: CircularProgressIndicator()),
        SizedBox(height: AuraSpace.s16),
        Center(child: Text('Finding your booking…')),
      ];
    }

    if (_error != null) {
      return [
        Text('We could not open this booking',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: AuraSpace.s12),
        Text(_error!, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AuraSpace.s24),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Back to home'),
        ),
      ];
    }

    if (_cancelled || _alreadyCancelled) {
      final route = _bookAgainRoute;
      return [
        Text(
          _cancelled ? 'Your booking is cancelled' : 'This booking is cancelled',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AuraSpace.s12),
        Text(
          _cancelled
              ? 'We have let them know. You can book another time whenever '
                  'you are ready.'
              : 'This booking was already cancelled. You can book another '
                  'time whenever you are ready.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AuraSpace.s24),
        // The obvious next step, offered only when we actually know which
        // calendar to return to. A dead button is worse than none.
        if (route != null)
          FilledButton(
            onPressed: () => context.go(route),
            child: const Text('Book another time'),
          ),
        if (route != null) const SizedBox(height: AuraSpace.s8),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Back to home'),
        ),
      ];
    }

    final when = _whenLabel();
    return [
      Text('Cancel this booking?', style: theme.textTheme.headlineSmall),
      const SizedBox(height: AuraSpace.s12),
      Text(
        when.isEmpty
            ? 'This will cancel your meeting and let them know.'
            : 'This will cancel your meeting on $when and let them know.',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: AuraSpace.s20),
      TextField(
        controller: _reason,
        maxLines: 3,
        maxLength: 300,
        enabled: !_working,
        decoration: const InputDecoration(
          labelText: 'Reason (optional)',
          hintText: 'Anything they should know?',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AuraSpace.s16),
      FilledButton(
        onPressed: _working ? null : _cancel,
        child: _working
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Cancel booking'),
      ),
      const SizedBox(height: AuraSpace.s8),
      TextButton(
        onPressed: _working ? null : () => context.go('/'),
        child: const Text('Keep my booking'),
      ),
    ];
  }
}
