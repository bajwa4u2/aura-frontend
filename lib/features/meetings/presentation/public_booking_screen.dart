import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';

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
      error: (e, _) => const _NotFoundBody(),
      data: (profile) => _BookingPageBody(profile: profile),
    );
  }
}

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
        title: '',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const _NotFoundBody(),
      data: (profile) => _BookingPageBody(profile: profile),
    );
  }
}

class _NotFoundBody extends StatelessWidget {
  const _NotFoundBody();

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: '',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: AuraSpace.s16),
              Text(
                'Booking page not found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AuraSpace.s8),
              const Text(
                'This booking link may be expired or invalid.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingPageBody extends StatelessWidget {
  final AvailabilityProfile profile;
  const _BookingPageBody({required this.profile});

  @override
  Widget build(BuildContext context) {
    final institution = profile.institution;
    final host = profile.effectiveHost;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return AuraScaffold(
      title: '',
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? AuraSpace.s32 : AuraSpace.s16,
          vertical: AuraSpace.s24,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PlatformIdentityBanner(),
                  const SizedBox(height: AuraSpace.s24),
                  isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _BookingIntro(
                                profile: profile,
                                institution: institution,
                                host: host,
                              ),
                            ),
                            const SizedBox(width: AuraSpace.s32),
                            SizedBox(
                              width: 360,
                              child: _BookingActionPanel(profile: profile),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _BookingIntro(
                              profile: profile,
                              institution: institution,
                              host: host,
                              compact: true,
                            ),
                            const SizedBox(height: AuraSpace.s20),
                            _BookingActionPanel(profile: profile),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingIntro extends StatelessWidget {
  final AvailabilityProfile profile;
  final InstitutionRef? institution;
  final ProfileOwner? host;
  final bool compact;

  const _BookingIntro({
    required this.profile,
    required this.institution,
    required this.host,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (institution != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LogoMark(
                label: institution!.name,
                icon: Icons.business_rounded,
                logoUrl: institution!.logoUrl,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      institution!.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((institution!.description ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          institution!.description!.trim(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF9CA3AF),
                            height: 1.35,
                          ),
                        ),
                      ),
                    if ((institution!.tagline ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        institution!.tagline!.trim(),
                        style: theme.textTheme.bodyMedium?.copyWith(
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
                        if (institution!.isVerified)
                          const _DetailChip(
                            icon: Icons.verified_rounded,
                            label: 'Verified institution',
                          ),
                        _DetailChip(
                          icon: Icons.public_rounded,
                          label: institution!.slug,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s28),
        ],
        if (host != null) ...[
          Row(
            children: [
              CircleAvatar(
                radius: compact ? 22 : 28,
                backgroundColor: const Color(0xFF6C63FF),
                backgroundImage: host!.avatarUrl != null
                    ? NetworkImage(host!.avatarUrl!)
                    : null,
                child: host!.avatarUrl == null
                    ? Text(
                        host!.name.isNotEmpty
                            ? host!.name[0].toUpperCase()
                            : 'H',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: compact ? 16 : 20,
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
                      host!.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        if (host!.title?.trim().isNotEmpty == true)
                          host!.title!.trim(),
                        if (host!.handle?.trim().isNotEmpty == true)
                          '@${host!.handle}',
                        'Host for ${institution?.name ?? 'this meeting'}',
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
          const SizedBox(height: AuraSpace.s24),
        ],
        Text(
          profile.meetingTitle,
          style:
              (compact
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if ((profile.meetingDescription ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          Text(
            profile.meetingDescription!.trim(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF9CA3AF),
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: AuraSpace.s20),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            _DetailChip(
              icon: Icons.schedule_rounded,
              label: _durationLabel(profile.defaultDuration),
            ),
            _DetailChip(
              icon: Icons.public_rounded,
              label: DateTime.now().timeZoneName,
            ),
            if (profile.allowGuests)
              const _DetailChip(
                icon: Icons.person_outline_rounded,
                label: 'Guests welcome',
              ),
          ],
        ),
      ],
    );
  }

  static String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '${hours}h' : '${hours}h ${rem}min';
  }
}

class _BookingActionPanel extends StatelessWidget {
  final AvailabilityProfile profile;
  const _BookingActionPanel({required this.profile});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aura',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8B85FF),
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Verified meeting infrastructure',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
            ),
            const SizedBox(height: AuraSpace.s12),
            Text(
              'Aura helps institutions host meetings with identity, context, and follow-up continuity.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFCBD5E1),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AuraSpace.s16),
            FilledButton.icon(
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Book a time'),
              onPressed: () =>
                  context.push('${profile.publicUrl}/book', extra: profile),
            ),
            const SizedBox(height: AuraSpace.s18),
            const _ReassuranceRow(
              icon: Icons.mark_email_read_outlined,
              text: 'Meeting link sent by email',
            ),
            const _ReassuranceRow(
              icon: Icons.video_call_rounded,
              text: 'Audio/video meeting',
            ),
            const _ReassuranceRow(
              icon: Icons.person_add_alt_1_rounded,
              text: 'No account required for guests',
            ),
            const _ReassuranceRow(
              icon: Icons.verified_outlined,
              text: 'Verified meeting infrastructure',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformIdentityBanner extends StatelessWidget {
  const _PlatformIdentityBanner();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.ring_volume_rounded,
            color: Color(0xFF8B85FF),
            size: 20,
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aura',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hosted meetings with identity, context, and continuity',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9CA3AF),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? logoUrl;
  final double size;

  const _LogoMark({
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
        color: const Color(0xFF6C63FF).withValues(alpha: 0.14),
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

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF8B85FF)),
      label: Text(label),
      backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.10),
      side: BorderSide(color: const Color(0xFF6C63FF).withValues(alpha: 0.30)),
      labelStyle: const TextStyle(color: Color(0xFFD9D7FF)),
    );
  }
}

class _ReassuranceRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReassuranceRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD1D5DB)),
            ),
          ),
        ],
      ),
    );
  }
}
