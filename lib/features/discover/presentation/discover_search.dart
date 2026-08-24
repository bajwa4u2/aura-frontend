import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../search/providers.dart';
import '../../search/search_repository.dart';

/// SEARCH IS PART OF DISCOVER, NOT A PLACE DISCOVER SENDS YOU.
///
/// The landing used to show a search-shaped box that pushed a legacy screen.
/// Two surfaces, two states, and returning from a result meant arriving back
/// at a dashboard that had forgotten the query.
///
/// This is the state that makes one surface behave as one product:
///
///   NO QUERY         the curated dashboard
///   TYPING           grouped live results across the four domains
///   DOMAIN NARROWED  the same query, one domain, deeper
///   CLEARED          the dashboard again
///
/// DELIBERATELY NOT autoDispose. Opening a result and coming back must restore
/// the query and the narrowing — that is the founder's explicit requirement,
/// and it is a property of where the state lives, not of any widget.

final discoverQueryProvider = StateProvider<String>((ref) => '');

/// Null means "all domains". Narrowing keeps the query and deepens one domain.
final discoverNarrowedDomainProvider =
    StateProvider<SearchDomain?>((ref) => null);

/// A query shorter than this is treated as no query: single letters match
/// almost everything and produce noise rather than results.
const int kMinQueryLength = 2;

final discoverSearchResultProvider = FutureProvider<SearchResult>((ref) async {
  final q = ref.watch(discoverQueryProvider).trim();
  if (q.length < kMinQueryLength) return const SearchResult.empty();
  return ref.read(searchRepositoryProvider).search(q, limit: 12);
});

/// Whether the surface is currently answering a query.
final discoverIsSearchingProvider = Provider<bool>((ref) {
  return ref.watch(discoverQueryProvider).trim().length >= kMinQueryLength;
});

/// The field itself. Owns its controller and debounce; the query it publishes
/// is what every other part of the surface reads.
class DiscoverSearchField extends ConsumerStatefulWidget {
  const DiscoverSearchField({super.key, this.autofocus = false});

  final bool autofocus;

  @override
  ConsumerState<DiscoverSearchField> createState() =>
      _DiscoverSearchFieldState();
}

class _DiscoverSearchFieldState extends ConsumerState<DiscoverSearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Seeded from the provider, so a restored query reappears in the field
    // when the person comes back to Discover.
    _controller = TextEditingController(text: ref.read(discoverQueryProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(discoverQueryProvider.notifier).state = value;
      // A new query starts wide again: narrowing belongs to the query it was
      // chosen for, and silently keeping it would hide most of the results.
      ref.read(discoverNarrowedDomainProvider.notifier).state = null;
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(discoverQueryProvider.notifier).state = '';
    ref.read(discoverNarrowedDomainProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AuraSurface.muted),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              onChanged: (v) {
                setState(() {}); // reflect the clear affordance
                _onChanged(v);
              },
              onSubmitted: (v) {
                _debounce?.cancel();
                ref.read(discoverQueryProvider.notifier).state = v;
              },
              style: AuraText.body.copyWith(color: AuraSurface.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AuraSpace.s14),
                hintText: 'Search people, spaces, institutions, articles',
                hintStyle: AuraText.body.copyWith(color: AuraSurface.muted),
              ),
            ),
          ),
          if (hasText)
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AuraSurface.muted),
              tooltip: 'Clear search',
              splashRadius: 18,
            ),
        ],
      ),
    );
  }
}

/// Domain narrowing. Only domains that actually answered are offered — a chip
/// that leads to "no results" is a worse answer than no chip.
class DiscoverDomainChips extends ConsumerWidget {
  const DiscoverDomainChips({super.key, required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answering = result.answeringDomains;
    if (answering.length < 2) return const SizedBox.shrink();

    final narrowed = ref.watch(discoverNarrowedDomainProvider);

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s8,
          ),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.accentSoft : AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: selected
                  ? AuraSurface.accent.withValues(alpha: 0.4)
                  : AuraSurface.divider,
            ),
          ),
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: selected ? AuraSurface.ink : AuraSurface.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        chip(
          label: 'All',
          selected: narrowed == null,
          onTap: () =>
              ref.read(discoverNarrowedDomainProvider.notifier).state = null,
        ),
        for (final domain in answering)
          chip(
            label: '${domain.label} ${result.forDomain(domain).length}',
            selected: narrowed == domain,
            onTap: () => ref
                .read(discoverNarrowedDomainProvider.notifier)
                .state = narrowed == domain ? null : domain,
          ),
      ],
    );
  }
}
