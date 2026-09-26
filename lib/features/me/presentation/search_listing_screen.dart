/// SEARCH ENGINES — whether this person's profile is listed in Aura's sitemap.
///
/// ## THE RULING THIS SURFACES
///
/// Founder, 2026-09-26: Aura's sitemap advertises articles, public
/// announcements and verified institutions, and a person's profile ONLY with
/// that person's opt-in. Advertising a profile pushes a real individual into
/// search results; that is theirs to choose, not Aura's to default. So the
/// switch starts OFF for everyone, and this screen is the only place it turns.
///
/// ## WHAT IT SAYS, AND WHAT IT DOES NOT CLAIM
///
/// It says exactly what the switch does: add or remove the profile address
/// from the sitemap that search engines are given. It does not claim to make a
/// profile private — a public profile can still be opened by anyone who has the
/// link — and it does not promise when, or whether, a search engine will act.
/// Overpromising on a privacy control is worse than a plainer sentence.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error_mapper.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/search_listing_repository.dart';
import 'widgets/me_section.dart';

class SearchListingScreen extends ConsumerStatefulWidget {
  const SearchListingScreen({super.key});

  @override
  ConsumerState<SearchListingScreen> createState() =>
      _SearchListingScreenState();
}

class _SearchListingScreenState extends ConsumerState<SearchListingScreen> {
  bool _saving = false;

  Future<void> _set(bool listed) async {
    setState(() => _saving = true);
    try {
      await ref.read(searchListingRepositoryProvider).set(listed: listed);
      ref.invalidate(searchListingProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            listed
                ? 'Your profile will be included in Aura\'s sitemap.'
                : 'Your profile is no longer included in Aura\'s sitemap.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.from(e, feature: 'change this setting').message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(searchListingProvider);

    return AuraScaffold(
      title: 'Search engines',
      maxWidth: 720,
      body: listing.when(
        // Its own words: the generic loading copy for `person` reads
        // "Getting people ready", which says nothing about this screen.
        loading: () => const AuraProductState(
          state: ProductState.loading,
          subject: ProductNoun.person,
          detail: 'Checking your search engine setting.',
        ),
        // A FAILED LOAD IS NOT "OFF". Showing the switch as off when the
        // request failed would tell a person something false about their own
        // privacy choice, so the error is shown as an error.
        error: (e, _) => AuraProductState(
          state: ProductState.error,
          subject: ProductNoun.person,
          detail: AppErrorMapper.from(e, feature: 'load this setting').message,
          onRecover: () => ref.invalidate(searchListingProvider),
        ),
        data: (state) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s16,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            Text(
              'Aura gives search engines a list of public pages they can '
              'find, called a sitemap. Your profile is only on that list if '
              'you choose it here. It is off unless you turn it on.',
              style: AuraText.small
                  .copyWith(color: AuraSurface.faint, height: 1.4),
            ),
            const SizedBox(height: AuraSpace.s20),
            MeSection(
              title: 'Your profile',
              children: [
                // MeSection paints a DecoratedBox, not a Material, so this
                // switch does not rely on the shell's Scaffold being the
                // nearest Material: it brings its own, and renders the same
                // wherever the screen is mounted.
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile.adaptive(
                    value: state.listed,
                    onChanged: _saving ? null : _set,
                    title: const Text('List my profile for search engines'),
                    subtitle: Text(
                      state.listed
                          ? 'Your profile address is in Aura\'s sitemap.'
                          : 'Your profile address is not in Aura\'s sitemap.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s20),
            Text(
              'This does not make your profile private. A public profile can '
              'still be opened by anyone with its link. Turning this off '
              'removes it from the sitemap at the next update; search engines '
              'decide for themselves when to drop pages they already know.',
              style: AuraText.small
                  .copyWith(color: AuraSurface.faint, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
