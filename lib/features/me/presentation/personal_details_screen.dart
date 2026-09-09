import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/eligibility/jurisdiction_confirm_sheet.dart';
import '../../../core/eligibility/jurisdictions.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// PERSONAL DETAILS — who a person IS, not what they show.
///
///     PERSONAL DETAILS  !=  PUBLIC PROFILE
///
/// The profile editor owns display name, photo, bio, links and publications:
/// the things a person chooses to present. This owns the canonical facts
/// underneath — legal name, date of birth, declared jurisdiction, and the
/// address the account signs in with. None of it appears on a profile.
///
/// WHY THIS SCREEN HAD TO EXIST. `firstName` and `lastName` were collected at
/// registration and then had no writer at all, so a person could not correct
/// their own name — the fact here they are most likely to need to fix. And
/// members admitted before Aura asked for a date of birth are no longer
/// redirected to a completion wall, which is right, but it means the way to
/// supply those facts has to be somewhere a person can actually find. This is
/// that place: reachable, never forced.
///
/// The email is shown and not editable. Changing it is a verification flow,
/// not a profile edit, and rendering it as a text field would promise
/// something this screen does not do.
class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  ConsumerState<PersonalDetailsScreen> createState() =>
      _PersonalDetailsScreenState();
}

/// What the server holds about this person, privately.
class _PersonalDetails {
  const _PersonalDetails({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.jurisdiction,
    required this.missingFields,
  });

  final String email;
  final String? firstName;
  final String? lastName;

  /// `YYYY-MM-DD`, exactly as stored. Never parsed to a local instant for
  /// display: a birthday rendered through a timezone moves by a day.
  final String? dateOfBirth;
  final String? jurisdiction;
  final List<String> missingFields;

  static _PersonalDetails fromJson(Map<String, dynamic> json) {
    String? text(Object? v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return _PersonalDetails(
      email: (json['email'] ?? '').toString(),
      firstName: text(json['firstName']),
      lastName: text(json['lastName']),
      dateOfBirth: text(json['dateOfBirth']),
      jurisdiction: text(json['jurisdiction']),
      missingFields: [
        for (final f in (json['identityMissingFields'] as List? ?? const []))
          f.toString(),
      ],
    );
  }
}

final _personalDetailsProvider =
    FutureProvider.autoDispose<_PersonalDetails>((ref) async {
  final res = await ref.watch(dioProvider).get('/users/me/personal-details');
  final data = res.data;
  final inner = data is Map && data['data'] is Map ? data['data'] : data;
  return _PersonalDetails.fromJson(Map<String, dynamic>.from(inner as Map));
});

class _PersonalDetailsScreenState
    extends ConsumerState<PersonalDetailsScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  DateTime? _dateOfBirth;
  String? _jurisdiction;

  /// Set once from the server, so an in-progress edit is not overwritten by a
  /// provider refresh mid-typing.
  bool _seeded = false;
  bool _saving = false;
  String? _error;
  String? _saved;

  static final DateTime _earliestPlausible = DateTime.utc(1900, 1, 1);

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _seed(_PersonalDetails details) {
    if (_seeded) return;
    _seeded = true;
    _firstName.text = details.firstName ?? '';
    _lastName.text = details.lastName ?? '';
    _jurisdiction = details.jurisdiction;
    final iso = details.dateOfBirth;
    if (iso != null) {
      final parts = iso.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          _dateOfBirth = DateTime.utc(y, m, d);
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: _earliestPlausible,
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = picked;
      _error = null;
      _saved = null;
    });
  }

  Future<void> _pickJurisdiction() async {
    final picked = await showJurisdictionPicker(
      context,
      ref,
      title: 'Where are you?',
      explanation:
          'Age rules differ by country. This is only used to apply the right ones — it is never shown on your profile.',
      initial: _jurisdiction,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _jurisdiction = picked;
      _error = null;
      _saved = null;
    });
  }

  String _humanize(DioException e) {
    final data = e.response?.data;
    final message = data is Map
        ? (data['message'] ?? (data['error'] is Map ? data['error']['message'] : null))
        : null;
    final text = (message ?? '').toString().trim();
    if (text.isNotEmpty && !text.startsWith('{')) return text;
    if (e.type == DioExceptionType.connectionError) {
      return 'We could not reach the server. Check your connection and try again.';
    }
    return 'That could not be saved. Please check the details and try again.';
  }

  Future<void> _save(_PersonalDetails current) async {
    if (_saving) return;

    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _error = 'Please enter both your first and last name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _saved = null;
    });

    // ONE REQUEST, EVERY CHANGED FACT. The server commits them together or
    // not at all, so sending them separately would manufacture exactly the
    // partial state it is built to avoid.
    final body = <String, dynamic>{'firstName': first, 'lastName': last};
    if (_dateOfBirth != null) {
      body['dateOfBirth'] = DateFormat('yyyy-MM-dd').format(_dateOfBirth!);
    }
    if (isKnownJurisdiction(_jurisdiction)) {
      body['jurisdiction'] = _jurisdiction;
    }

    try {
      await ref.read(dioProvider).patch('/users/me/personal-details', data: body);
      if (!mounted) return;
      // Identity state is read from /auth/me by the router and elsewhere, and
      // it has just changed.
      ref.invalidate(authMeDataProvider);
      ref.invalidate(_personalDetailsProvider);
      setState(() => _saved = 'Saved.');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanize(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_personalDetailsProvider);

    return AuraScaffold(
      title: 'Personal details',
      maxWidth: 640,
      body: async.when(
        // Through the state authority, so a whole surface waiting or failing
        // looks the way it does everywhere else in Aura.
        loading: () => const AuraProductState(state: ProductState.loading),
        error: (_, __) => AuraProductState(
          state: ProductState.retryableError,
          headline: 'Could not load your details',
          detail: 'We could not reach the server.',
          onRecover: () => ref.invalidate(_personalDetailsProvider),
        ),
        data: (details) {
          _seed(details);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: [
              Text(
                'These are the facts Aura keeps about who you are. None of '
                'them appear on your profile.',
                style: AuraText.body.copyWith(
                  color: AuraSurface.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AuraSpace.s16),
              if (details.missingFields.isNotEmpty) ...[
                // An invitation, with no deadline and no suggestion that the
                // account is deficient. Someone who joined before Aura asked
                // is not in a wrong state; Aura simply does not know yet.
                _Notice(
                  message: details.missingFields.length == 1
                      ? 'Aura does not have your ${_label(details.missingFields.single)} yet.'
                      : 'Aura does not have all of these yet. You can add them whenever you like.',
                ),
                const SizedBox(height: AuraSpace.s16),
              ],
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      // A form-level message, not a surface state: the form is
                      // still there and still usable, and replacing it with a
                      // whole-surface error would throw away what was typed.
                      _SaveError(message: _error!),
                      const SizedBox(height: AuraSpace.s14),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstName,
                            enabled: !_saving,
                            style: AuraText.body,
                            decoration: const InputDecoration(
                              labelText: 'First name',
                            ),
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s10),
                        Expanded(
                          child: TextField(
                            controller: _lastName,
                            enabled: !_saving,
                            style: AuraText.body,
                            decoration: const InputDecoration(
                              labelText: 'Last name',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    _PickerField(
                      label: 'Date of birth',
                      value: _dateOfBirth == null
                          ? null
                          : DateFormat('MMMM d, yyyy').format(_dateOfBirth!),
                      placeholder: 'Add your date of birth',
                      onTap: _saving ? null : _pickDate,
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    _PickerField(
                      label: 'Where you are',
                      value: isKnownJurisdiction(_jurisdiction)
                          ? jurisdictionName(_jurisdiction)
                          : null,
                      placeholder: 'Select country',
                      onTap: _saving ? null : _pickJurisdiction,
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    // READ-ONLY, AND SHAPED LIKE IT. Changing the sign-in
                    // address is a verification flow, not a profile edit, and
                    // a text field here would promise otherwise.
                    _ReadOnlyField(label: 'Email', value: details.email),
                    const SizedBox(height: AuraSpace.s20),
                    if (_saved != null) ...[
                      Text(
                        _saved!,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s10),
                    ],
                    _saving
                        ? const AuraPrimaryButton(
                            label: 'Saving…',
                            onPressed: null,
                            icon: Icons.hourglass_top_rounded,
                          )
                        : AuraPrimaryButton(
                            label: 'Save',
                            onPressed: () => _save(details),
                            icon: Icons.check_rounded,
                          ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _label(String field) {
    switch (field) {
      case 'firstName':
        return 'first name';
      case 'lastName':
        return 'last name';
      case 'dateOfBirth':
        return 'date of birth';
      case 'jurisdiction':
        return 'country';
      default:
        return field;
    }
  }
}

class _SaveError extends StatelessWidget {
  const _SaveError({required this.message});

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
            child: Text(message, style: AuraText.small.copyWith(height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.r12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value ?? placeholder,
          style: AuraText.body.copyWith(
            color: value == null ? AuraSurface.muted : null,
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.lock_outline, size: 16),
      ),
      child: Text(
        value,
        style: AuraText.body.copyWith(color: AuraSurface.muted),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.r12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AuraSurface.accentText,
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              message,
              style: AuraText.small.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
