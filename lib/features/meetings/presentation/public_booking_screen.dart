import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';

// Public booking page — the Calendly replacement.
// Design principle: host and organization identity first.
// "Powered by Aura" is present but secondary.
class PublicBookingScreen extends ConsumerWidget {
  final String slug;
  const PublicBookingScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(slug));

    return profileAsync.when(
      loading: () => AuraScaffold(
        title: '',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: '',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: AuraSpace.s16),
              Text('Booking page not found',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AuraSpace.s8),
              const Text('This booking link may be expired or invalid.',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ),
      data: (profile) => _BookingPageBody(profile: profile),
    );
  }
}

class _BookingPageBody extends StatelessWidget {
  final AvailabilityProfile profile;
  const _BookingPageBody({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuraScaffold(
      title: '',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AuraSpace.s24),
            children: [
              // Host identity — shown first, before anything else
              if (profile.owner != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF6C63FF),
                      backgroundImage: profile.owner!.avatarUrl != null
                          ? NetworkImage(profile.owner!.avatarUrl!)
                          : null,
                      child: profile.owner!.avatarUrl == null
                          ? Text(
                              profile.owner!.name.isNotEmpty
                                  ? profile.owner!.name[0].toUpperCase()
                                  : 'H',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20),
                            )
                          : null,
                    ),
                    const SizedBox(width: AuraSpace.s14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.owner!.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700)),
                        if (profile.owner!.handle != null)
                          Text('@${profile.owner!.handle}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF9CA3AF))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s20),
                const Divider(),
                const SizedBox(height: AuraSpace.s16),
              ],

              // Meeting info
              Text(profile.meetingTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700)),
              if (profile.meetingDescription != null) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(profile.meetingDescription!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280))),
              ],

              const SizedBox(height: AuraSpace.s12),

              // Duration options + booking hint
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s4,
                children: profile.durationOptions.map((d) {
                  return Chip(
                    label: Text(_durationLabel(d)),
                    backgroundColor:
                        const Color(0xFF6C63FF).withOpacity(0.1),
                    side: BorderSide(
                        color: const Color(0xFF6C63FF).withOpacity(0.3)),
                    labelStyle:
                        const TextStyle(color: Color(0xFF6C63FF)),
                  );
                }).toList(),
              ),

              const SizedBox(height: AuraSpace.s24),

              // CTA — route to slot picker
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Book a time'),
                  onPressed: () => context.push(
                      '/meet/${profile.slug}/book',
                      extra: profile),
                ),
              ),

              const SizedBox(height: AuraSpace.s24),

              // Meeting capabilities
              _CapabilityRow(
                  icon: Icons.link_rounded,
                  text: 'Aura meeting link sent by email'),
              _CapabilityRow(
                  icon: Icons.video_call_rounded,
                  text: 'Video and audio meeting'),
              if (profile.waitingRoomEnabled)
                _CapabilityRow(
                    icon: Icons.meeting_room_outlined,
                    text: 'Waiting room enabled'),
              if (profile.allowGuests)
                _CapabilityRow(
                    icon: Icons.person_add_outlined,
                    text: 'No account required'),

              const SizedBox(height: AuraSpace.s32),

              // Platform attribution — truthful, not promotional
              const Divider(),
              const SizedBox(height: AuraSpace.s12),
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
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }
}

class _CapabilityRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CapabilityRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: AuraSpace.s10),
          Text(text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280))),
        ],
      ),
    );
  }
}
