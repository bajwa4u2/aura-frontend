import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';

// Personal booking page — /meet/:slug
class PublicBookingScreen extends ConsumerWidget {
  final String slug;
  const PublicBookingScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(slug));
    return profileAsync.when(
      loading: () => AuraScaffold(
          title: '', body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => _NotFoundBody(),
      data: (profile) => _BookingPageBody(profile: profile),
    );
  }
}

// Institution-owned booking page — /i/:institutionSlug/meet/:bookingSlug
// Shows institution identity before anything else.
class InstitutionPublicBookingScreen extends ConsumerWidget {
  final String institutionSlug;
  final String bookingSlug;
  const InstitutionPublicBookingScreen({
    super.key,
    required this.institutionSlug,
    required this.bookingSlug,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = InstitutionBookingKey(institutionSlug, bookingSlug);
    final profileAsync = ref.watch(institutionPublicProfileProvider(key));
    return profileAsync.when(
      loading: () => AuraScaffold(
          title: '', body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => _NotFoundBody(),
      data: (profile) => _BookingPageBody(profile: profile),
    );
  }
}

class _NotFoundBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
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
    );
  }
}

// Shared body — renders both personal and institution booking pages.
// Institution-owned profiles show institution badge + assigned host first.
class _BookingPageBody extends StatelessWidget {
  final AvailabilityProfile profile;
  const _BookingPageBody({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = profile.effectiveHost;
    final institution = profile.institution;

    return AuraScaffold(
      title: '',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AuraSpace.s24),
            children: [
              // Institution badge — shown first when institution-owned
              if (institution != null) ...[
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.business_rounded,
                            color: Color(0xFF6C63FF), size: 22),
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(institution.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700)),
                        if (institution.description != null)
                          Text(institution.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF9CA3AF))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s16),
                const Divider(),
                const SizedBox(height: AuraSpace.s16),
              ],

              // Host identity — shown before meeting info
              if (host != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20),
                            )
                          : null,
                    ),
                    const SizedBox(width: AuraSpace.s14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(host.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700)),
                        if (host.handle != null)
                          Text('@${host.handle}',
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

              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Book a time'),
                  // publicUrl already contains the right path prefix
                  onPressed: () => context.push(
                      '${profile.publicUrl}/book',
                      extra: profile),
                ),
              ),

              const SizedBox(height: AuraSpace.s24),

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
