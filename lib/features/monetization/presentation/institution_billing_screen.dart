import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../institutions/ui/institution_ds.dart';
import '../data/monetization_repository.dart';
import '../domain/monetization_models.dart';
import '../providers/monetization_providers.dart';

/// Institution plan and billing (monetization WP7, 2026-10-07).
///
/// The public is free; institutions pay for staff seats, a monthly allowance
/// for AI checks and publish-time translation, and their official voice.
/// Every number on this screen (tiers, prices, seats, allowances, packs) comes
/// from the backend's monetization config and the institution's entitlements.
/// Nothing is hardcoded.
///
/// Store binaries show what the institution has (plan, seats, allowance, the
/// grant) and nothing it could buy: no prices, no buttons, no destination.
class InstitutionBillingScreen extends ConsumerWidget {
  const InstitutionBillingScreen({super.key, required this.institutionId});

  final String institutionId;

  bool get _purchaseAllowed => billingPurchaseAllowed(
    isWeb: kIsWeb,
    platform: kIsWeb ? null : defaultTargetPlatform,
  );

  bool get _mayInviteExternalPurchase => billingMayInviteExternalPurchase(
    isWeb: kIsWeb,
    platform: kIsWeb ? null : defaultTargetPlatform,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(monetizationConfigProvider);
    final entitlementsAsync = ref.watch(
      institutionEntitlementProvider(institutionId),
    );
    final grantAsync = ref.watch(institutionGrantProvider(institutionId));

    return AuraScaffold(
      showHeader: false,
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _frame(const [_ErrorState()]),
        data: (config) {
          if (config.mode == MonetizationMode.disabled) {
            return _frame(const [_DisabledState()]);
          }

          return entitlementsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _frame(const [_ErrorState()]),
            data: (ent) {
              final tier = config.tierByCode(ent.planTier);
              final grant = grantAsync.valueOrNull;
              return _frame([
                _PlanCard(entitlements: ent, tier: tier),
                const SizedBox(height: AuraSpace.s14),
                _UsageCard(entitlements: ent),
                const SizedBox(height: AuraSpace.s20),
                if (!ent.isPro || ent.grantRunning) ...[
                  _GrantSection(
                    institutionId: institutionId,
                    config: config,
                    entitlements: ent,
                    grant: grant,
                    loading: grantAsync.isLoading,
                  ),
                  const SizedBox(height: AuraSpace.s20),
                ],
                if (_purchaseAllowed) ...[
                  _PlansSection(
                    config: config,
                    entitlements: ent,
                    // A paying institution changes tier on its existing
                    // subscription (the billing page); a new checkout would
                    // start a second subscription beside the first.
                    onChoose: ent.isPro && !ent.grantRunning
                        ? (_) => _openPortal(context: context, ref: ref)
                        : (productCode) => _runPlanCheckout(
                            context: context,
                            ref: ref,
                            productCode: productCode,
                          ),
                  ),
                  const SizedBox(height: AuraSpace.s20),
                  _TopUpsSection(
                    config: config,
                    onBuy: (productCode) => _runCreditsCheckout(
                      context: context,
                      ref: ref,
                      productCode: productCode,
                    ),
                  ),
                  if (ent.isPro && !ent.grantRunning) ...[
                    const SizedBox(height: AuraSpace.s20),
                    _ManageBillingCard(
                      onOpen: () => _openPortal(context: context, ref: ref),
                    ),
                  ],
                ] else ...[
                  if (_mayInviteExternalPurchase)
                    const _MobilePurchaseNotice()
                  else
                    const _BillingNotInThisAppNotice(),
                ],
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _frame(List<Widget> body) => InsScreen(
    children: [
      const InsModeHeader(title: 'Plan & Billing'),
      const InsModeHeaderGap(),
      ...body,
    ],
  );

  Future<void> _runPlanCheckout({
    required BuildContext context,
    required WidgetRef ref,
    required String productCode,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(monetizationRepositoryProvider);
      final session = await repo.startInstitutionPlanCheckout(
        institutionId: institutionId,
        productCode: productCode,
      );
      await _openUrl(messenger, session.url);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _runCreditsCheckout({
    required BuildContext context,
    required WidgetRef ref,
    required String productCode,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(monetizationRepositoryProvider);
      final session = await repo.startInstitutionCreditsCheckout(
        institutionId: institutionId,
        productCode: productCode,
      );
      await _openUrl(messenger, session.url);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _openPortal({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref
          .read(monetizationRepositoryProvider)
          .openBillingPortal(institutionId);
      await _openUrl(messenger, url);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _openUrl(ScaffoldMessengerState messenger, String? url) async {
    final uri = url == null || url.isEmpty ? null : Uri.tryParse(url);
    if (uri == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The payment page could not be opened. Try again.'),
        ),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WHAT THE INSTITUTION HAS
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.entitlements, required this.tier});
  final InstitutionEntitlements entitlements;
  final PlanTier? tier;

  @override
  Widget build(BuildContext context) {
    final ent = entitlements;
    final name = ent.isPro && tier != null ? 'Pro · ${tier!.label}' : 'Free';
    final String detail;
    if (ent.grantRunning) {
      detail =
          'On the 30-day grant until ${_date(ent.grantEndsAt!)}. '
          'Nothing is charged when it ends.';
    } else if (ent.isPro && tier != null) {
      detail = tier!.audience;
    } else {
      detail =
          'Your community is free on Aura. Pro adds staff seats, '
          'an official voice and a monthly allowance for checks and '
          'translation.';
    }
    return _FullWidthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current plan', style: AuraText.muted),
          const SizedBox(height: AuraSpace.s6),
          Text(name, style: AuraText.title),
          const SizedBox(height: AuraSpace.s6),
          Text(detail, style: AuraText.body.copyWith(height: 1.45)),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              // C2 — verification is deliberately NOT presented here:
              // this card summarizes what the institution PAYS FOR, and
              // verification is a governed fact, not an entitlement.
              // Plans and verification must not visually bleed together.
              _Chip(
                label: ent.canSpeakOfficially
                    ? 'Official voice on'
                    : 'Official voice off',
              ),
              if (ent.grantRunning) const _Chip(label: '30-day grant'),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.entitlements});
  final InstitutionEntitlements entitlements;

  @override
  Widget build(BuildContext context) {
    final ent = entitlements;
    final seatsLine = ent.seatLimit == null
        ? (ent.seatsUsed == null
              ? 'No staff seat limit'
              : '${_n(ent.seatsUsed!)} in use · no limit')
        : '${_n(ent.seatsUsed ?? 0)} of ${_n(ent.seatLimit!)} in use';

    return _FullWidthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UsageRow(
            label: 'Staff seats',
            value: seatsLine,
            helper:
                'Owners and administrators. Members and followers are '
                'never counted.',
            fraction: ent.seatLimit == null || ent.seatLimit == 0
                ? null
                : (ent.seatsUsed ?? 0) / ent.seatLimit!,
          ),
          if (ent.allowanceMonthly > 0) ...[
            const SizedBox(height: AuraSpace.s16),
            _UsageRow(
              label: ent.grantRunning ? 'Grant credits' : 'This month',
              value:
                  '${_n(ent.allowanceBalance)} of '
                  '${_n(ent.allowanceMonthly)} credits left',
              helper: ent.allowanceResetsAt == null
                  ? 'For AI checks and translation of what the institution '
                        'publishes.'
                  : ent.grantRunning
                  ? 'For AI checks and translation. They end with the '
                        'grant on ${_date(ent.allowanceResetsAt!)}.'
                  : 'For AI checks and translation. Renews on '
                        '${_date(ent.allowanceResetsAt!)}; what is left '
                        'does not roll over.',
              fraction: ent.allowanceBalance / ent.allowanceMonthly,
              remaining: true,
            ),
          ],
          if (ent.creditBalance > 0) ...[
            const SizedBox(height: AuraSpace.s16),
            _UsageRow(
              label: 'Top-up credits',
              value: '${_n(ent.creditBalance)} credits',
              helper: 'Used after the monthly allowance. They do not expire.',
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.value,
    required this.helper,
    this.fraction,
    this.remaining = false,
  });

  final String label;
  final String value;
  final String helper;

  /// 0..1; null hides the bar.
  final double? fraction;

  /// True when the bar shows what is LEFT (allowance) rather than used.
  final bool remaining;

  @override
  Widget build(BuildContext context) {
    final f = fraction?.clamp(0.0, 1.0);
    final low = f != null && (remaining ? f <= 0.2 : f >= 1.0);
    final tone = InsToneStyle.of(low ? InsTone.warn : InsTone.ok);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AuraText.muted)),
            Text(
              value,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (f != null) ...[
          const SizedBox(height: AuraSpace.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: f,
              minHeight: 6,
              backgroundColor: AuraSurface.divider,
              valueColor: AlwaysStoppedAnimation(tone.fg),
            ),
          ),
        ],
        const SizedBox(height: AuraSpace.s6),
        Text(helper, style: AuraText.small.copyWith(color: AuraSurface.muted)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THE 30-DAY INSTITUTIONAL GRANT
// ─────────────────────────────────────────────────────────────────────────────

class _GrantSection extends ConsumerStatefulWidget {
  const _GrantSection({
    required this.institutionId,
    required this.config,
    required this.entitlements,
    required this.grant,
    required this.loading,
  });

  final String institutionId;
  final MonetizationConfig config;
  final InstitutionEntitlements entitlements;
  final InstitutionGrant? grant;
  final bool loading;

  @override
  ConsumerState<_GrantSection> createState() => _GrantSectionState();
}

class _GrantSectionState extends ConsumerState<_GrantSection> {
  String? _tier;
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grant = widget.grant;
    final ent = widget.entitlements;
    final tiers = widget.config.tiers;

    if (widget.loading) return const SizedBox.shrink();

    final Widget body;
    if (ent.grantRunning || (grant?.running ?? false)) {
      final ends = ent.grantEndsAt ?? grant?.endsAt;
      body = InsCard(
        tone: InsTone.ok,
        child: Text(
          ends == null
              ? 'Your grant is running.'
              : 'Your grant runs until ${_date(ends)}. Seven days before '
                    'it ends, the owners are reminded. Afterwards the '
                    'institution returns to Free unless an owner chooses a plan; '
                    'nothing is charged and nothing is lost.',
          style: AuraText.body.copyWith(height: 1.45),
        ),
      );
    } else if (grant?.status == InstitutionGrantStatus.pending) {
      body = InsCard(
        tone: InsTone.info,
        child: Text(
          'Your request to try ${_tierName(tiers, grant!.requestedTier)} '
          'is with the Aura team. The owners will be told when it is '
          'decided.',
          style: AuraText.body.copyWith(height: 1.45),
        ),
      );
    } else if (grant != null) {
      // Declined, or approved and already used. Once per institution.
      final declined = grant.status == InstitutionGrantStatus.declined;
      body = InsCard(
        child: Text(
          declined
              ? 'The grant request was not approved'
                    '${grant.declineReason == null || grant.declineReason!.isEmpty ? '.' : ': ${grant.declineReason}'}'
              : 'This institution has had its 30-day grant.',
          style: AuraText.body.copyWith(height: 1.45),
        ),
      );
    } else {
      body = _requestForm(tiers);
    }

    final running = ent.grantRunning || (grant?.running ?? false);
    return InsSection(
      eyebrow: running ? null : 'Try Pro',
      title: running ? 'Your 30-day grant' : '30-day grant',
      helper: running
          ? null
          : 'Set up your institution and use Pro for 30 days, with 500 '
                'credits. It is free, reviewed by the Aura team, and given once.',
      child: body,
    );
  }

  Widget _requestForm(List<PlanTier> tiers) {
    final options = <PlanTier>[];
    for (final t in tiers) {
      // The three Public body sizes are one choice when trying Pro.
      if (options.any((o) => o.label == t.label)) continue;
      options.add(t);
    }
    final selected = _tier ?? (options.isEmpty ? null : options.first.tier);

    // Chips and the text field need a Material ancestor; the form carries its
    // own so it does not depend on which shell hosts the screen.
    return InsCard(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Which plan would you like to try?',
              style: AuraText.muted,
            ),
            const SizedBox(height: AuraSpace.s8),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                for (final t in options)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: selected == t.tier,
                    onSelected: _sending
                        ? null
                        : (_) => setState(() => _tier = t.tier),
                  ),
              ],
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _note,
              enabled: !_sending,
              maxLength: 2000,
              minLines: 2,
              // Grows with the note: a bounded multi-line field would claim
              // the scroll wheel from the page behind it.
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'What would you like to use Aura for? (optional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AuraSpace.s6),
              Text(
                _error!,
                style: AuraText.small.copyWith(
                  color: InsToneStyle.of(InsTone.danger).fg,
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.s8),
            AuraPrimaryButton(
              label: _sending ? 'Sending…' : 'Request the grant',
              onPressed: _sending || selected == null
                  ? null
                  : () => _send(selected),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(String tier) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(monetizationRepositoryProvider)
          .requestInstitutionGrant(
            institutionId: widget.institutionId,
            requestedTier: tier,
            message: _note.text,
          );
      ref.invalidate(institutionGrantProvider(widget.institutionId));
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANS, TOP-UPS AND MANAGING THE PLAN — only where this build may take money
// ─────────────────────────────────────────────────────────────────────────────

class _PlansSection extends StatefulWidget {
  const _PlansSection({
    required this.config,
    required this.entitlements,
    required this.onChoose,
  });

  final MonetizationConfig config;
  final InstitutionEntitlements entitlements;
  final ValueChanged<String> onChoose;

  @override
  State<_PlansSection> createState() => _PlansSectionState();
}

class _PlansSectionState extends State<_PlansSection> {
  bool _yearly = false;

  @override
  Widget build(BuildContext context) {
    final tiers = widget.config.tiers;
    if (tiers.isEmpty) return const SizedBox.shrink();
    final discount = widget.config.nonprofitDiscountPercent;
    final ent = widget.entitlements;

    return InsSection(
      eyebrow: 'Pro',
      title: 'Plans',
      helper: discount > 0
          ? 'Nonprofits, schools and faith institutions pay $discount% less '
                'once the institution\'s category is confirmed. The discount '
                'is applied at checkout.'
          : null,
      trailing: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Monthly')),
          ButtonSegment(value: true, label: Text('Yearly')),
        ],
        selected: {_yearly},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _yearly = s.first),
      ),
      child: Column(
        children: [
          for (final t in tiers) ...[
            _TierRow(
              tier: t,
              yearly: _yearly,
              isCurrent:
                  ent.isPro && !ent.grantRunning && ent.planTier == t.tier,
              chooseLabel: ent.isPro && !ent.grantRunning ? 'Change' : 'Choose',
              onChoose: () => widget.onChoose(
                _yearly ? t.yearlyProductCode : t.monthlyProductCode,
              ),
            ),
            const SizedBox(height: AuraSpace.s10),
          ],
          Text(
            'Yearly is ten months\' price for twelve. Calls and meetings are '
            'included on every plan.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.yearly,
    required this.isCurrent,
    required this.onChoose,
    this.chooseLabel = 'Choose',
  });

  final String chooseLabel;
  final PlanTier tier;
  final bool yearly;
  final bool isCurrent;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final price = yearly
        ? '${_usd(tier.yearlyCents)} / year'
        : '${_usd(tier.monthlyCents)} / month';
    final seats = tier.seatLimit == null
        ? 'No staff seat limit'
        : '${tier.seatLimit} staff seats';
    return InsCard(
      tone: isCurrent ? InsTone.ok : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  tier.audience,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  '$seats · ${_n(tier.monthlyAllowance)} credits a month',
                  style: AuraText.small,
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AuraSpace.s8),
              if (isCurrent)
                const _Chip(label: 'Current')
              else
                AuraSecondaryButton(label: chooseLabel, onPressed: onChoose),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopUpsSection extends StatelessWidget {
  const _TopUpsSection({required this.config, required this.onBuy});

  final MonetizationConfig config;
  final ValueChanged<String> onBuy;

  @override
  Widget build(BuildContext context) {
    final packs = config.creditPacks
        .where((p) => p.credits > 0)
        .toList(growable: false);
    if (packs.isEmpty) return const SizedBox.shrink();

    return InsSection(
      title: 'Top-ups',
      helper:
          'Extra credits for a busy month. Used after the monthly '
          'allowance, and they do not expire.',
      child: InsCard(
        child: Column(
          children: [
            for (final pack in packs) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_n(pack.credits)} credits',
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (pack.displayPrice != null) ...[
                    Text(pack.displayPrice!, style: AuraText.body),
                    const SizedBox(width: AuraSpace.s12),
                  ],
                  AuraSecondaryButton(
                    label: 'Buy',
                    onPressed: () => onBuy(pack.code),
                  ),
                ],
              ),
              if (pack != packs.last) const SizedBox(height: AuraSpace.s10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManageBillingCard extends StatelessWidget {
  const _ManageBillingCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InsActionCard(
      icon: Icons.receipt_long_outlined,
      title: 'Manage billing',
      body:
          'Change or cancel the plan, update the card or bank account, '
          'and download invoices.',
      cta: 'Open',
      onTap: onOpen,
    );
  }
}

/// C-21 — WHAT A STORE BINARY MAY SAY ABOUT PAYING SOMEWHERE ELSE.
///
/// `_MobilePurchaseNotice` names `app.auraplatform.org` and tells the reader to
/// sign in there to pay. On iOS that is a call to action directing customers to
/// a purchasing mechanism other than in-app purchase — **App Store Review
/// Guideline 3.1.1**.
///
/// The dangerous part is not the text, it is WHEN it appears. The whole screen
/// is gated on `config.mode`, which is a SERVER flag. Nothing about it is
/// decided at build time, so on the day monetization is switched on, every
/// installed binary starts showing this — with no new submission, no review,
/// and no way to take it back except another release.
///
/// Stating the current plan, seats and allowance is not a purchase invitation
/// and stays. What comes off the store binaries is the invitation itself, and
/// (WP7) the price list with it: store builds no longer render tiers, prices
/// or packs at all.
///
/// Kept pure and separate from [billingPurchaseAllowed] because they are two
/// different questions: whether this build may take money, and whether it may
/// tell you to go and spend it elsewhere. Desktop may do both; a store binary
/// may do neither.
bool billingMayInviteExternalPurchase({
  required bool isWeb,
  required TargetPlatform? platform,
}) {
  if (isWeb) return true;
  switch (platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return false;
    default:
      // Windows, macOS and Linux are not distributed under store purchase
      // rules here, so directing to the web is ordinary.
      return true;
  }
}

/// Whether THIS build may run a checkout itself.
bool billingPurchaseAllowed({
  required bool isWeb,
  required TargetPlatform? platform,
}) {
  if (isWeb) return true;
  switch (platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return false;
    default:
      return true;
  }
}

/// Billing exists, and it is not done here. No price, no destination, no
/// invitation — the three things 3.1.1 is about.
class _BillingNotInThisAppNotice extends StatelessWidget {
  const _BillingNotInThisAppNotice();

  @override
  Widget build(BuildContext context) {
    return _FullWidthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan changes are not available in this app',
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Your current plan, seats and allowance are shown above. '
            'An owner of this institution can change the plan.',
            style: AuraText.body.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MobilePurchaseNotice extends StatelessWidget {
  const _MobilePurchaseNotice();

  @override
  Widget build(BuildContext context) {
    return _FullWidthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage your plan on the web', style: AuraText.title),
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Plans and top-ups are handled on app.auraplatform.org. Sign in '
            'there with the same account to manage billing for this '
            'institution.',
            style: AuraText.body.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DisabledState extends StatelessWidget {
  const _DisabledState();

  @override
  Widget build(BuildContext context) {
    return const _FullWidthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plans are not open yet', style: AuraText.title),
          SizedBox(height: AuraSpace.s6),
          Text(
            'Everything your institution uses today stays free until plans '
            'open. Nothing is charged.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const _FullWidthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Could not load billing', style: AuraText.title),
          SizedBox(height: AuraSpace.s6),
          Text(
            'Check your connection and open this page again.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}

/// Cards on this screen span the column, whatever their content's width.
class _FullWidthCard extends StatelessWidget {
  const _FullWidthCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: AuraCard(child: child),
  );
}

/// Billing-screen neutral chip — wraps canonical SubstrateChip.
class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return SubstrateChip(label: label, state: SubstrateChipState.mist);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

String _n(int v) => NumberFormat.decimalPattern('en_US').format(v);

String _usd(int cents) => cents % 100 == 0
    ? '\$${NumberFormat.decimalPattern('en_US').format(cents ~/ 100)}'
    : NumberFormat.simpleCurrency(locale: 'en_US').format(cents / 100);

/// Every date carries its time (founder rule, 2026-09-29), in the viewer's
/// zone, through the app's one temporal authority.
String _date(DateTime d) => AuraTemporal.fullShort(d);

String _tierName(List<PlanTier> tiers, String code) {
  for (final t in tiers) {
    if (t.tier == code) return t.label;
  }
  return 'Pro';
}

/// The server's own sentence when it sent one (grant refusals carry a
/// readable message); a plain sentence otherwise. Never a raw exception.
String _friendly(Object e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map) {
      final msg =
          data['message'] ??
          (data['error'] is Map ? data['error']['message'] : null);
      if (msg is String && msg.trim().isNotEmpty) return msg;
    }
  } catch (_) {}
  return 'That did not go through. Please try again.';
}
