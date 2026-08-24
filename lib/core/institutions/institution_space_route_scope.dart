import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../net/dio_provider.dart';
import '../product/product_state.dart';
import '../product/product_state_view.dart';

/// What a Space address in a workspace path names — AND the entry state that
/// naming it authoritatively produces.
///
/// It carries the Space and its conversation reference because opening a Space
/// is ONE question. Resolving the address, loading the Space and obtaining its
/// conversation used to be three round trips, each starting only once the
/// previous stage's widget had mounted; every call was under 0.3s and the
/// surface still took ~18 seconds to become usable.
class SpaceAddress {
  const SpaceAddress({
    required this.spaceId,
    required this.canonicalSlug,
    required this.isCanonical,
    this.space,
    this.conversationId,
  });

  final String spaceId;

  /// The Space as the authority projects it, already access-checked. Null only
  /// when this address was resolved by a caller that asked for nothing more.
  final Map<String, dynamic>? space;

  /// The Space's canonical Conversation. Produced by the authority only AFTER
  /// Space access was decided, which is why it can be carried here safely.
  final String? conversationId;

  /// The Space's CURRENT address, or null if it has none (a Space with no
  /// institution is never addressed this way).
  final String? canonicalSlug;

  /// True when the caller already used the current address.
  final bool isCanonical;
}

/// Resolve a Space address WITHIN one institution.
///
/// The institution is part of the key, not context: a Space address is scoped
/// to its parent institution, so `general` means nothing on its own and two
/// institutions may each hold one. Caching per (institution, address) is
/// therefore correct — the same address under a different institution is a
/// different question with a different answer.
final remoteSpaceAddressProvider =
    FutureProvider.family<SpaceAddress?, ({String institutionId, String address})>(
        (ref, key) async {
  final institutionId = key.institutionId.trim();
  final address = key.address.trim();
  if (institutionId.isEmpty || address.isEmpty) return null;

  try {
    // ONE ANSWER. The entry endpoint resolves the address, decides Space
    // access and produces the conversation reference in a single round trip,
    // in that order. The older `address/:address/resolve` endpoint is
    // deliberately unauthenticated and still exists for callers that only want
    // to canonicalise an address.
    final res = await ref.read(dioProvider).get(
          '/institutions/$institutionId/spaces/by-address/$address/entry',
        );
    final body =
        res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final data =
        body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;

    final spaceId = data['spaceId']?.toString().trim() ?? '';
    if (spaceId.isEmpty) return null;

    final canonical = data['canonicalSlug']?.toString().trim();
    return SpaceAddress(
      spaceId: spaceId,
      canonicalSlug: (canonical == null || canonical.isEmpty) ? null : canonical,
      // The server reports HOW it matched, so the client never has to infer
      // canonicality by comparing strings and getting the case rule wrong.
      isCanonical: data['matched']?.toString() == 'CANONICAL',
      space: data['space'] is Map
          ? Map<String, dynamic>.from(data['space'] as Map)
          : null,
      conversationId: (data['conversationId']?.toString().trim().isEmpty ?? true)
          ? null
          : data['conversationId'].toString().trim(),
    );
  } on DioException catch (e) {
    // A 404 is a real answer: the address names nothing in this institution.
    // Anything else is a failure to find out, and must not be reported as
    // "does not exist" (RC2 / F065).
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
});

/// THE BOUNDARY BETWEEN A SPACE'S PRODUCT ADDRESS AND ITS PERSISTENCE ID.
///
/// Founder ruling (2026-08-23) §9, and the same shape as the Institution
/// regression that proved it necessary:
///
///     product address
///       → resolve ONCE at the boundary
///       → persistence id
///       → screen / data / authority
///
/// Every Space API is keyed by the Space's id. If a screen took the raw path
/// segment and handed it to its data layer, the moment navigation started
/// minting slugs every Space request would ask for `spaceId = 'general'`,
/// match nothing, and the Space would become unreachable while its data sat
/// untouched. That is exactly what happened to Institutions, so the conversion
/// happens here and the screen is never handed the address at all.
///
/// RESOLUTION IS NOT ACCESS (ruling §5). This says WHICH Space is addressed.
/// Membership and visibility are decided afterwards by the Space's own
/// authority, on the server, unchanged.
///
/// UNKNOWN IS NOT UNAUTHORIZED. While resolution is in flight this renders a
/// bounded loading state rather than mounting a screen against an address it
/// cannot yet resolve — and an error resolves to a truthful empty state rather
/// than an eternal spinner (F068).
class InstitutionSpaceRouteScope extends ConsumerStatefulWidget {
  const InstitutionSpaceRouteScope({
    super.key,
    required this.institutionId,
    required this.address,
    required this.builder,
  });

  /// The CANONICAL institution id, already resolved by the institution route
  /// boundary above this one.
  final String institutionId;

  /// The raw path segment. May be the current address, a retired address, or
  /// a legacy persistence id.
  final String? address;

  /// Receives the RESOLVED ENTRY. Never the raw address — the boundary exists
  /// so a screen can never hand a path segment to a data layer as a key.
  final Widget Function(SpaceAddress entry) builder;

  @override
  ConsumerState<InstitutionSpaceRouteScope> createState() =>
      _InstitutionSpaceRouteScopeState();
}

class _InstitutionSpaceRouteScopeState
    extends ConsumerState<InstitutionSpaceRouteScope> {
  /// Canonicalization is attempted once per address, so a rebuild cannot turn
  /// it into a redirect loop.
  String? _canonicalizedFrom;

  /// A legacy id or a retired address still RESOLVES — old links must keep
  /// working (ruling §6) — but the URL converges on the current address rather
  /// than leaving two forms of it alive in front of the reader.
  void _canonicalize(SpaceAddress resolved, String raw) {
    final canonical = resolved.canonicalSlug;
    if (canonical == null || canonical == raw) return;
    if (resolved.isCanonical) return;
    if (_canonicalizedFrom == raw) return;
    _canonicalizedFrom = raw;

    // After the frame: replacing the route during build is not allowed, and
    // `replace` rather than `push` so the non-canonical form does not become
    // a back-stack entry the reader can land on again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uri = GoRouterState.of(context).uri;
      final path = uri.path;
      final marker = '/spaces/$raw';
      final at = path.lastIndexOf(marker);
      if (at < 0) return;

      final replaced = path.replaceRange(at, at + marker.length, '/spaces/$canonical');
      final query = uri.hasQuery ? '?${uri.query}' : '';
      context.replace('$replaced$query');
    });
  }

  @override
  Widget build(BuildContext context) {
    final raw = (widget.address ?? '').trim();
    if (raw.isEmpty) {
      return const AuraProductState(
        state: ProductState.empty,
        headline: 'That space could not be found',
      );
    }

    final resolved = ref.watch(
      remoteSpaceAddressProvider(
        (institutionId: widget.institutionId, address: raw),
      ),
    );

    return resolved.when(
      loading: () => const AuraProductState(state: ProductState.loading),
      error: (_, __) => const AuraProductState(
        state: ProductState.empty,
        headline: 'That space could not be found',
      ),
      data: (address) {
        if (address == null) {
          return const AuraProductState(
            state: ProductState.empty,
            headline: 'That space could not be found',
          );
        }
        _canonicalize(address, raw);
        return widget.builder(address);
      },
    );
  }
}
