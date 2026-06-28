import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/shell_shared.dart';
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
                            ),
                            const SizedBox(height: AuraSpace.s20),
                            _BookingActionPanel(profile: profile),
                          ],
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s32),
          const ShellFooter(),
        ],
      ),
    );
  }
}

class _BookingIntro extends StatelessWidget {
  final AvailabilityProfile profile;
  final InstitutionRef? institution;
  final ProfileOwner? host;

  const _BookingIntro({
    required this.profile,
    required this.institution,
    required this.host,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (institution != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CompactLogo(
                label: institution!.name,
                logoUrl: institution!.logoUrl,
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            institution!.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (institution!.isVerified) ...[
                          const SizedBox(width: 8),
                          const _MiniBadge(label: 'Verified'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s20),
        ],
        if (host != null) ...[
          Row(
            children: [
              _HostAvatar(name: host!.name, avatarUrl: host!.avatarUrl),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host!.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (host!.title?.trim().isNotEmpty == true)
                      Text(
                        host!.title!.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s18),
        ],
        Text(
          profile.meetingTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
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
        const SizedBox(height: AuraSpace.s18),
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
          ],
        ),
      ),
    );
  }
}

class _CompactLogo extends StatelessWidget {
  final String label;
  final String? logoUrl;

  const _CompactLogo({required this.label, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    final initial = label.trim().isEmpty ? 'A' : label.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.trim().isNotEmpty
          ? Image.network(
              logoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FallbackMark(initial: initial),
            )
          : _FallbackMark(initial: initial),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  final String initial;

  const _FallbackMark({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFFE6E9EF),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HostAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _HostAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF6C63FF),
      backgroundImage: avatarUrl != null && avatarUrl!.trim().isNotEmpty
          ? NetworkImage(avatarUrl!)
          : null,
      child: avatarUrl == null || avatarUrl!.trim().isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'H',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            )
          : null,
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD9D7FF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
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
