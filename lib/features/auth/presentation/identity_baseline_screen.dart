import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/eligibility/jurisdiction_confirm_sheet.dart';
import '../../../core/eligibility/jurisdictions.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// Identity Foundation — the identity baseline completion path.
///
/// Reached TWO ways, and the difference matters to what this screen says:
///
///   REQUIRED    A prospective account missing baseline facts. The router
///               sends it here, and "before continuing" is literally true.
///   INVITED     A member admitted before Aura asked. They are never sent
///               here; they arrive because they chose to. Telling that person
///               they cannot continue would be false, and implying their
///               account is deficient would be worse — they joined under the
///               rules that existed, and those rules still hold for them.
///
/// Founder direction: provide a respectful completion path, without false
/// urgency and without suggesting an account is invalid. Mirrors
/// VerifyPendingScreen's shape: a full-screen interstitial, not a modal,
/// carrying `redirectTo` so the original destination resumes after
/// completion. The router itself handles navigating away once the backend
/// confirms completion — this screen only submits and invalidates.
class IdentityBaselineScreen extends ConsumerStatefulWidget {
  const IdentityBaselineScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<IdentityBaselineScreen> createState() =>
      _IdentityBaselineScreenState();
}

class _IdentityBaselineScreenState
    extends ConsumerState<IdentityBaselineScreen> {
  DateTime? _selected;
  /// ISO-3166 alpha-2, self-declared.
  ///
  /// CAPTURED HERE, AT CREATION, ON PURPOSE. Founder decision, 2026-08-30:
  /// no new account is to be left with a null jurisdiction where the governed
  /// signup path can capture one. Every legacy account has a null because the
  /// column did not exist; that is a debt to work off, not a pattern to keep
  /// reproducing on every new sign-up.
  String? _jurisdiction;
  bool _busy = false;
  String? _error;

  static final DateTime _earliestPlausible = DateTime.utc(1900, 1, 1);

  Future<void> _pickJurisdiction() async {
    final picked = await showJurisdictionPicker(
      context,
      ref,
      title: 'Where are you?',
      explanation:
          'Age rules differ by country. This is only used to apply the right ones — it is never shown on your profile.',
      initial:
          _jurisdiction ??
          WidgetsBinding.instance.platformDispatcher.locale.countryCode,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _jurisdiction = picked;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: _earliestPlausible,
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selected = picked;
      _error = null;
    });
  }

  String _humanizeError(DioException? e) {
    final code = e?.response?.statusCode;
    final msg = (e?.message ?? '').toLowerCase();

    if (code != null && code >= 400 && code < 500) {
      // Rendered verbatim, and that now includes an eligibility refusal: a
      // 403 here means the account threshold was not met, and the backend's
      // own sentence ("You must be 16 or older to use Aura.") is both the
      // honest answer and the only one allowed to be shown — Policy §5
      // forbids echoing the date or the computed age back.
      final raw = e?.response?.data;
      if (raw is Map && raw['message'] is String) {
        return raw['message'] as String;
      }
      return 'That date could not be saved. Please check it and try again.';
    }

    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('network') ||
        e?.type == DioExceptionType.connectionError ||
        e?.type == DioExceptionType.connectionTimeout ||
        e?.type == DioExceptionType.sendTimeout ||
        e?.type == DioExceptionType.receiveTimeout) {
      return 'We could not reach the server. Check your connection and try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  Future<void> _submit() async {
    if (_busy) return;
    final selected = _selected;
    if (selected == null) {
      setState(() => _error = 'Please select your date of birth.');
      return;
    }

    if (!isKnownJurisdiction(_jurisdiction)) {
      setState(() => _error = 'Please select where you are.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final dio = ref.read(dioProvider);
    final iso = DateFormat('yyyy-MM-dd').format(selected);

    try {
      await dio.patch(
        '/users/me/identity-baseline',
        // Both facts in ONE request. Sending them separately would leave a
        // window in which the account has a country but no date of birth, and
        // the account gate runs on the arrival of the date of birth.
        data: {'dateOfBirth': iso, 'jurisdiction': _jurisdiction},
      );

      if (!mounted) return;
      // The router's own listener on identityBaselineCompleteProvider
      // handles navigating away once this settles — no manual context.go.
      ref.invalidate(authMeDataProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeError(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final label = selected == null
        ? 'Select date of birth'
        : DateFormat('MMMM d, yyyy').format(selected);

    // Unknown state reads as INVITED, not REQUIRED. If Aura cannot currently
    // tell whether this person is obliged to be here, it does not assert that
    // they are.
    final identity = ref.watch(identityStateProvider).valueOrNull;
    final required = identity?.mustCompleteBeforeUse ?? false;

    return AuraScaffold(
      showHeader: false,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kFormWidth),
              child: AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AuraSurface.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cake_outlined,
                        size: 22,
                        color: AuraSurface.accentText,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    Text(
                      required
                          ? 'Complete your profile'
                          : 'Add your date of birth',
                      style: AuraText.title,
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      required
                          ? 'Before continuing, please confirm your date of birth and where you are. Both are part of Aura\'s identity baseline for every member, and neither is shown on your profile.'
                          // No deadline, no warning, and no suggestion that
                          // the account is lacking. An invitation that reads
                          // as a threat is not a respectful completion path.
                          : 'Aura did not ask for these when you joined. Adding them keeps your account details complete, and neither is shown on your profile.',
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s20),
                    if (_error != null) ...[
                      _ErrorBanner(message: _error!),
                      const SizedBox(height: AuraSpace.s14),
                    ],
                    InkWell(
                      onTap: _busy ? null : _pickDate,
                      borderRadius: BorderRadius.circular(AuraRadius.r12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of birth',
                        ),
                        child: Text(
                          label,
                          style: AuraText.body.copyWith(
                            color: selected == null
                                ? AuraSurface.muted
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    InkWell(
                      onTap: _busy ? null : _pickJurisdiction,
                      borderRadius: BorderRadius.circular(AuraRadius.r12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Where you are',
                        ),
                        child: Text(
                          _jurisdiction == null
                              ? 'Select country'
                              : jurisdictionName(_jurisdiction),
                          style: AuraText.body.copyWith(
                            color: _jurisdiction == null
                                ? AuraSurface.muted
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s20),
                    if (_busy)
                      const AuraPrimaryButton(
                        label: 'Saving…',
                        onPressed: null,
                        icon: Icons.hourglass_top_rounded,
                      )
                    else
                      AuraPrimaryButton(
                        label: required ? 'Continue' : 'Save',
                        onPressed: _submit,
                        icon: Icons.arrow_forward_rounded,
                      ),
                    // A way out exists ONLY for the invited. Offering it to a
                    // prospective account would quietly reopen the door the
                    // registration floor exists to hold.
                    if (!required && !_busy) ...[
                      const SizedBox(height: AuraSpace.s10),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            final router = GoRouter.of(context);
                            if (router.canPop()) {
                              router.pop();
                            } else {
                              router.go(widget.redirectTo ?? '/home');
                            }
                          },
                          child: Text(
                            'Not now',
                            style: AuraText.body.copyWith(
                              color: AuraSurface.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.coRose.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        border: Border.all(color: AuraSurface.coRose.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AuraSurface.coRose,
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              message,
              style: AuraText.body.copyWith(color: AuraSurface.coRose),
            ),
          ),
        ],
      ),
    );
  }
}
