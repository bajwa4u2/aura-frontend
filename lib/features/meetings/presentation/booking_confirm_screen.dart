import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';

class BookingConfirmScreen extends ConsumerStatefulWidget {
  final AvailabilityProfile profile;
  final TimeSlot slot;
  final int durationMinutes;

  const BookingConfirmScreen({
    super.key,
    required this.profile,
    required this.slot,
    required this.durationMinutes,
  });

  @override
  ConsumerState<BookingConfirmScreen> createState() =>
      _BookingConfirmScreenState();
}

class _BookingConfirmScreenState
    extends ConsumerState<BookingConfirmScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _booking = false;
  BookingConfirmation? _confirmation;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _booking = true);

    try {
      final repo = ref.read(availabilityRepositoryProvider);
      final BookingConfirmation conf;
      final profile = widget.profile;

      // Institution-owned profiles book via institution endpoint
      if (profile.isInstitutionOwned && profile.institution != null) {
        conf = await repo.createInstitutionBooking(
          profile.institution!.slug,
          profile.slug,
          bookerName: _nameCtrl.text.trim(),
          bookerEmail: _emailCtrl.text.trim(),
          bookerNotes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          scheduledAt: widget.slot.startAt,
          durationMinutes: widget.durationMinutes,
          timezone: DateTime.now().timeZoneName,
        );
      } else {
        conf = await repo.createBooking(
          profile.slug,
          bookerName: _nameCtrl.text.trim(),
          bookerEmail: _emailCtrl.text.trim(),
          bookerNotes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          scheduledAt: widget.slot.startAt,
          durationMinutes: widget.durationMinutes,
          timezone: DateTime.now().timeZoneName,
        );
      }
      setState(() => _confirmation = conf);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Booking failed: $e')));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmation != null) {
      return _ConfirmationView(
          confirmation: _confirmation!, profile: widget.profile);
    }

    final theme = Theme.of(context);
    final localTime = widget.slot.startAt.toLocal();
    final timeLabel =
        DateFormat('EEEE, MMMM d · h:mm a').format(localTime);

    return AuraScaffold(
      title: 'Confirm booking',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            // Back navigation (AuraScaffold drops leading/actions)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                onPressed: () => context.pop(),
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
                const SizedBox(height: AuraSpace.s12),
                Text(widget.profile.meetingTitle,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AuraSpace.s6),

            // Time and duration
            _InfoRow(icon: Icons.schedule_rounded, text: timeLabel),
            _InfoRow(
                icon: Icons.timer_outlined,
                text: _durationLabel(widget.durationMinutes)),

            const SizedBox(height: AuraSpace.s20),
            const Divider(),
            const SizedBox(height: AuraSpace.s16),

            // Booker info
            Text('Your information',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AuraSpace.s12),

            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Name is required'
                  : null,
            ),
            const SizedBox(height: AuraSpace.s12),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: AuraSpace.s12),

            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                hintText: 'Anything the host should know',
              ),
            ),

            const SizedBox(height: AuraSpace.s24),

            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _booking ? null : _confirm,
                child: _booking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : const Text('Confirm booking'),
              ),
            ),
            const SizedBox(height: AuraSpace.s32),
          ],
        ),
      ),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h hour${h != 1 ? 's' : ''}';
    return '$h hour${h != 1 ? 's' : ''} $m min';
  }
}

class _ConfirmationView extends ConsumerWidget {
  final BookingConfirmation confirmation;
  final AvailabilityProfile profile;

  const _ConfirmationView({
    required this.confirmation,
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAuthed = ref.watch(isAuthedProvider);
    final institution = confirmation.institution ?? profile.institution;
    final host = confirmation.host ?? profile.effectiveHost;
    final joinPath = '/meetings/join/${confirmation.meetingCode}';
    final loginPath = '/login?redirect=${Uri.encodeComponent(joinPath)}';
    final localTime = confirmation.scheduledAt.toLocal();
    final timeLabel =
        DateFormat('EEEE, MMMM d · h:mm a').format(localTime);

    return AuraScaffold(
      title: '',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success indicator
                const Icon(Icons.check_circle_rounded,
                    size: 60, color: Color(0xFF10B981)),
                const SizedBox(height: AuraSpace.s16),
                Text('Booking confirmed',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AuraSpace.s6),
                Text('A confirmation has been sent to your email.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280))),

                const SizedBox(height: AuraSpace.s24),
                const Divider(),
                const SizedBox(height: AuraSpace.s16),

                if (institution != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IdentityAvatar(
                        label: institution.name,
                        icon: Icons.business_rounded,
                        logoUrl: institution.logoUrl,
                        size: 48,
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              institution.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if ((institution.description ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  institution.description!.trim(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF9CA3AF),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            if ((institution.tagline ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                institution.tagline!.trim(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF9CA3AF),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (institution.isVerified)
                                  const _PillChip(
                                    icon: Icons.verified_rounded,
                                    label: 'Verified institution',
                                  ),
                                _PillChip(
                                  icon: Icons.public_rounded,
                                  label: institution.slug,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s16),
                ],

                if (host != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF6C63FF),
                        backgroundImage: host.avatarUrl != null
                            ? NetworkImage(host.avatarUrl!)
                            : null,
                        child: host.avatarUrl == null
                            ? Text(
                                host.name.isNotEmpty
                                    ? host.name[0].toUpperCase()
                                    : 'H',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              host.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (host.title?.trim().isNotEmpty == true)
                                  host.title!.trim(),
                                'Host for ${institution?.name ?? profile.name}',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s16),
                ],

                // Meeting details
                Text(confirmation.meetingTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AuraSpace.s8),
                _InfoRow(
                    icon: Icons.schedule_rounded,
                    text: timeLabel),
                _InfoRow(
                    icon: Icons.timer_outlined,
                    text: '${confirmation.durationMinutes} minutes'),
                _InfoRow(
                    icon: Icons.person_outline_rounded,
                    text: 'With ${confirmation.hostName}'),

                const SizedBox(height: AuraSpace.s16),

                // Meeting link
                Container(
                  padding: const EdgeInsets.all(AuraSpace.s14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          confirmation.meetingCode,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: const Color(0xFF6C63FF)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        color: const Color(0xFF6C63FF),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: confirmation.joinUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Meeting link copied')));
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s24),

                FilledButton.icon(
                  icon: const Icon(Icons.video_call_rounded),
                  label: Text(isAuthed ? 'Continue with Aura' : 'Join as guest'),
                  onPressed: () => context.push(joinPath),
                ),
                const SizedBox(height: AuraSpace.s12),

                OutlinedButton.icon(
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Continue with Aura'),
                  onPressed: isAuthed
                      ? () => context.push(joinPath)
                      : () => context.go(loginPath),
                ),
                const SizedBox(height: AuraSpace.s12),

                OutlinedButton(
                  onPressed: () => context.go(profile.publicUrl),
                  child: const Text('Done'),
                ),

                const SizedBox(height: AuraSpace.s24),

                // Platform attribution
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Meeting powered by ',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 12)),
                    Text('Aura',
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityAvatar extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? logoUrl;
  final double size;

  const _IdentityAvatar({
    required this.label,
    required this.icon,
    this.logoUrl,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? 'A' : label.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (logoUrl != null && logoUrl!.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                logoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  icon,
                  color: const Color(0xFF8B85FF),
                  size: size * 0.46,
                ),
              ),
            )
          else
            Icon(icon, color: const Color(0xFF8B85FF), size: size * 0.46),
          Positioned(
            right: size * 0.1,
            bottom: size * 0.08,
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFFE6E9EF),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PillChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
