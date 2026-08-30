import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../errors/app_error_mapper.dart';
import '../net/dio_provider.dart';
import '../ui/aura_platform_components.dart';
import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'jurisdictions.dart';

/// CONFIRM WHERE YOU ARE — IN PLACE, NOT SOMEWHERE ELSE.
///
/// This is deliberately a sheet and not a route. The refusal it answers
/// arrives while someone is holding unsent work: a composed post, a reply
/// half-written, an announcement waiting to publish. Navigating to a settings
/// screen to answer one question would take them off that surface and put the
/// draft at the mercy of whatever the composer does when it is popped. The
/// founder's requirement was explicit that drafts stay drafts, and the
/// cheapest way to guarantee that is never to leave the screen holding them.
///
/// Returns true when a jurisdiction was saved, so the caller can retry the
/// exact act that was refused. Returns false when the person dismissed it —
/// which is a legitimate answer, and must leave everything as it was.
Future<bool> showJurisdictionConfirmSheet(
  BuildContext context,
  WidgetRef ref, {
  String? title,
  String? explanation,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JurisdictionConfirmSheet(
      title: title,
      explanation: explanation,
      persist: true,
    ),
  );
  return saved == true;
}

/// The same selector, WITHOUT writing anything.
///
/// Used where the jurisdiction is one field of a larger submission that has
/// not happened yet — account creation, where it travels with the date of
/// birth in a single request. Saving it separately there would create exactly
/// the half-written identity record the baseline screen exists to prevent:
/// a country on file for an account that does not yet have a date of birth.
///
/// Returns the chosen ISO-3166 alpha-2 code, or null if dismissed.
Future<String?> showJurisdictionPicker(
  BuildContext context,
  WidgetRef ref, {
  String? title,
  String? explanation,
  String? initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JurisdictionConfirmSheet(
      title: title,
      explanation: explanation,
      initial: initial,
      persist: false,
    ),
  );
}

class _JurisdictionConfirmSheet extends ConsumerStatefulWidget {
  const _JurisdictionConfirmSheet({
    this.title,
    this.explanation,
    this.initial,
    required this.persist,
  });

  final String? title;
  final String? explanation;
  final String? initial;

  /// Whether confirming writes to the server (true, and pops `true`) or
  /// simply returns the chosen code to the caller (false, and pops the code).
  final bool persist;

  @override
  ConsumerState<_JurisdictionConfirmSheet> createState() =>
      _JurisdictionConfirmSheetState();
}

class _JurisdictionConfirmSheetState
    extends ConsumerState<_JurisdictionConfirmSheet> {
  final TextEditingController _search = TextEditingController();
  final List<String> _all = jurisdictionCodesByName();

  String? _selected;
  bool _busy = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preselect();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Preselect what is already on file, then the device's own locale.
  ///
  /// The locale is a GUESS and is presented as one — it lands as a highlighted
  /// row the person still has to confirm, never as a value saved on their
  /// behalf. Silently recording a guess as a self-declared fact is exactly the
  /// thing the "self-declared, not detected" rule exists to prevent.
  Future<void> _preselect() async {
    String? existing = widget.initial;

    // Only ask the server when the caller did not already say. In the
    // account-creation case there is nothing on file yet, and the request
    // would be a guaranteed null.
    if (!isKnownJurisdiction(existing) && widget.persist) {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('/users/me/identity-baseline');
        final data = res.data;
        if (data is Map && data['jurisdiction'] is String) {
          existing = data['jurisdiction'] as String;
        }
      } catch (_) {
        // A failed read is not worth surfacing: the sheet still works, it
        // just starts without a preselection.
      }
    }

    final localeGuess =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _selected = isKnownJurisdiction(existing)
          ? existing!.toUpperCase()
          : (isKnownJurisdiction(localeGuess)
                ? localeGuess!.toUpperCase()
                : null);
    });
  }

  List<String> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where(
          (code) =>
              kJurisdictions[code]!.toLowerCase().contains(q) ||
              code.toLowerCase() == q,
        )
        .toList();
  }

  Future<void> _save() async {
    final code = _selected;
    if (code == null || _busy) return;

    if (!widget.persist) {
      Navigator.of(context).pop(code);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/users/me/jurisdiction', data: {'jurisdiction': code});

      // The gate reads the canonical columns on every call, so the retry that
      // follows will see this immediately — but anything already holding a
      // cached identity view has to be told.
      ref.invalidate(authMeDataProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppErrorMapper.from(e).message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AuraRadius.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AuraSpace.s10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AuraSurface.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s16,
                  AuraSpace.s16,
                  AuraSpace.s16,
                  AuraSpace.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title ?? 'Confirm where you are',
                      style: AuraText.title,
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    Text(
                      widget.explanation ??
                          'Some countries allow this at a younger age. This is only used to apply the right rules — it is never shown on your profile.',
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        height: 1.4,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AuraSpace.s12),
                      Text(
                        _error!,
                        style: AuraText.body.copyWith(
                          color: AuraSurface.dangerInk,
                        ),
                      ),
                    ],
                    const SizedBox(height: AuraSpace.s12),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search countries',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AuraSpace.s24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _visible.length,
                    itemBuilder: (context, i) {
                      final code = _visible[i];
                      final selected = code == _selected;
                      return ListTile(
                        dense: true,
                        title: Text(
                          kJurisdictions[code]!,
                          style: AuraText.body.copyWith(
                            color: selected
                                ? AuraSurface.accentText
                                : AuraSurface.ink,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: AuraSurface.accentText,
                              )
                            : null,
                        onTap: _busy
                            ? null
                            : () => setState(() => _selected = code),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AuraSpace.s16),
                child: SizedBox(
                  width: double.infinity,
                  child: AuraPrimaryButton(
                    label: _busy ? 'Saving…' : 'Confirm',
                    icon: _busy
                        ? Icons.hourglass_top_rounded
                        : Icons.check_rounded,
                    // Disabled until something is chosen. A "Confirm" that
                    // saves nothing is how a null jurisdiction survives the
                    // very screen built to capture it.
                    onPressed: (_busy || _selected == null) ? null : _save,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
