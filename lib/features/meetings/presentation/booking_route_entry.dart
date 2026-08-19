/// RC8 — BOOKING AND RESCHEDULE DESTINATIONS THAT SURVIVE A REFRESH.
///
/// THE DEFECT. Four booking routes carried their subject in `state.extra` —
/// the in-memory object the previous screen happened to be holding. A refresh,
/// a bookmark, a shared link or an email click supplies no `extra`, so:
///
///   * `/meet/:slug/book` fell through to `PublicBookingScreen(slug: '')` — a
///     booking page for nobody, even though the slug was RIGHT THERE in the
///     path it was standing on;
///   * `/meet/reschedule/:token` fell through to `BookingCancelScreen(token:
///     '')` — the wrong screen, with the token discarded. Since that route is
///     only ever reached from a confirmation EMAIL, it never worked at all.
///
/// THE CORRECTION. The route carries IDENTITY; everything else is read back
/// from the authority that owns it.
///
///   * WHO the booking is with → the `:slug` (or `:institutionSlug` +
///     `:bookingSlug`) already in the path, resolved through the existing
///     public-profile providers.
///   * WHICH slot was chosen → `?start=` and `?duration=`, a selection the
///     person made, expressed as plain values. Not sensitive, not a
///     credential, and meaningless to anyone who did not choose it.
///   * WHICH booking a reschedule link means → the `:token` already in the
///     path, read through `rescheduleContextProvider`.
///
/// WHAT DELIBERATELY DID NOT GO INTO A URL. Nothing that decides authority.
/// Availability, minimum notice, maximum advance, capacity and whether a
/// booking may still be rescheduled are re-decided by the server on every
/// read and every write, exactly as before. A durable URL can carry identity;
/// it cannot carry permission.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/guest_shell.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';
import 'booking_confirm_screen.dart';
import 'booking_reschedule_screen.dart';
import 'slot_picker_screen.dart';

/// Parses `?start=` / `?duration=` back into the slot the person picked.
/// Returns null when the selection is absent or unusable — the person then
/// picks again rather than being shown a slot nobody chose.
TimeSlot? slotFromQuery(Map<String, String> query) {
  final rawStart = (query['start'] ?? '').trim();
  if (rawStart.isEmpty) return null;
  final start = DateTime.tryParse(rawStart);
  if (start == null) return null;

  final minutes = int.tryParse((query['duration'] ?? '').trim()) ?? 0;
  if (minutes <= 0) return null;

  // Parsed as it arrives, exactly like `TimeSlot.fromJson` — no local
  // conversion here. Presentation is where a time becomes local, through the
  // temporal authority that owns that decision (C0 ratchet).
  return TimeSlot(
    startAt: start,
    endAt: start.add(Duration(minutes: minutes)),
  );
}

/// The chosen-slot half of a booking URL. Built by the slot picker so the
/// address bar describes the destination it navigated to.
String bookingSelectionQuery({required TimeSlot slot, required int duration}) {
  final start = Uri.encodeQueryComponent(slot.startAt.toUtc().toIso8601String());
  return '?start=$start&duration=$duration';
}

/// `/meet/:slug/book` and `/i/:institutionSlug/meet/:bookingSlug/book`.
///
/// With a slot in the URL this is the confirmation step; without one it is the
/// slot picker — which is what a person who bookmarked "book with X" means.
class BookingRouteEntry extends ConsumerWidget {
  const BookingRouteEntry({
    super.key,
    required this.slug,
    this.institutionSlug,
    this.slot,
    this.durationMinutes,
  });

  final String slug;
  final String? institutionSlug;
  final TimeSlot? slot;
  final int? durationMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instSlug = (institutionSlug ?? '').trim();
    final profileAsync = instSlug.isEmpty
        ? ref.watch(publicProfileProvider(slug))
        : ref.watch(institutionPublicProfileProvider(
            InstitutionBookingKey(instSlug, slug),
          ));

    return profileAsync.when(
      loading: () => const GuestShell(
        body: AuraProductState(state: ProductState.loading),
      ),
      error: (e, _) => const GuestShell(
        body: AuraProductState(
          state: ProductState.unavailable,
          headline: 'This booking page is unavailable',
          detail: 'The link may be wrong, or the page may have been removed.',
        ),
      ),
      data: (profile) {
        final chosen = slot;
        if (chosen == null) {
          return SlotPickerScreen(profile: profile);
        }
        return BookingConfirmScreen(
          profile: profile,
          slot: chosen,
          durationMinutes: durationMinutes ?? profile.defaultDuration,
        );
      },
    );
  }
}

/// `/meet/reschedule/:token` and `/i/:institutionSlug/meet/reschedule/:token`.
///
/// Reached from a confirmation email, so the token is all there is — and all
/// there needs to be. The booking's current state decides whether a reschedule
/// is offered at all; the route only says which booking is meant.
class RescheduleRouteEntry extends ConsumerWidget {
  const RescheduleRouteEntry({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (token.trim().isEmpty) {
      return const GuestShell(
        body: AuraProductState(
          state: ProductState.unavailable,
          headline: 'This reschedule link is incomplete',
          detail: 'Open the link from your confirmation email again.',
        ),
      );
    }

    final contextAsync = ref.watch(rescheduleContextProvider(token));

    return contextAsync.when(
      loading: () => const GuestShell(
        body: AuraProductState(state: ProductState.loading),
      ),
      error: (e, _) => const GuestShell(
        body: AuraProductState(
          state: ProductState.unavailable,
          headline: 'This booking could not be found',
          detail: 'The link may have expired, or the booking may already have '
              'been cancelled.',
        ),
      ),
      data: (booking) {
        // Authority stays with the booking, not the link that carried it.
        if (booking['reschedulable'] != true) {
          return const GuestShell(
            body: AuraProductState(
              state: ProductState.unavailable,
              headline: 'This booking can no longer be rescheduled',
              detail: 'It may already have been cancelled.',
            ),
          );
        }

        final profileSlug = (booking['profileSlug'] ?? '').toString();
        final instSlug = (booking['institutionSlug'] ?? '').toString();
        final profileAsync = instSlug.isEmpty
            ? ref.watch(publicProfileProvider(profileSlug))
            : ref.watch(institutionPublicProfileProvider(
                InstitutionBookingKey(instSlug, profileSlug),
              ));

        return profileAsync.when(
          loading: () => const GuestShell(
            body: AuraProductState(state: ProductState.loading),
          ),
          error: (e, _) => const GuestShell(
            body: AuraProductState(
              state: ProductState.unavailable,
              headline: 'This booking page is unavailable',
              detail: 'Try the link from your confirmation email again.',
            ),
          ),
          data: (profile) =>
              BookingRescheduleScreen(token: token, profile: profile),
        );
      },
    );
  }
}
