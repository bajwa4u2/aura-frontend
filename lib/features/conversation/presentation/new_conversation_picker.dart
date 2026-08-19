import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/navigation_authority.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../search/search_repository.dart';
import '../data/conversations_repository.dart';
import '../../../core/identity/person_identity_model.dart';

/// NEW CONVERSATION — the one canonical creation flow (canon §10/§13):
/// choose a PERSON → the conversation opens → talk immediately. People
/// only (institution conversations start context-first from the
/// institution's profile). No direct/group question, no name, no
/// description, no topology — ever.
class NewConversationPicker extends ConsumerStatefulWidget {
  const NewConversationPicker({super.key});

  @override
  ConsumerState<NewConversationPicker> createState() =>
      _NewConversationPickerState();
}

class _NewConversationPickerState extends ConsumerState<NewConversationPicker> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = const [];
  bool _searching = false;
  bool _opening = false;

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await SearchRepository(ref.read(dioProvider)).search(q);
      if (mounted) setState(() => _results = result.users);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _open(String userId) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final conversation = await ref
          .read(conversationsRepositoryProvider)
          .openWithPerson(userId);
      ref.invalidate(conversationsListProvider);
      if (mounted) {
        context.pushReplacement(
            NavigationAuthority.conversationRoute(conversation.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not start this conversation.')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'New conversation',
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: _search,
            decoration: const InputDecoration(
              hintText: 'Who do you want to talk to?',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          if (_searching)
            const AuraProductState(
                state: ProductState.loading, subject: ProductNoun.person)
          else if (_results.isEmpty && _query.text.trim().length >= 2)
            Text('No people found.',
                style: AuraText.small.copyWith(color: AuraSurface.muted))
          else
            // F053/F116 — the picker names a person exactly as the
            // conversation it starts will name them.
            for (final u in _results.take(20))
              if (AuraPersonIdentity.fromJson(u) case final person)
              ListTile(
                leading: AuraAvatar(
                    name: person.displayName,
                    imageUrl: person.avatarUrl,
                    size: 40),
                title: Text(person.label, style: AuraText.body),
                subtitle: Text('@${person.handle}', style: AuraText.micro),
                onTap: _opening
                    ? null
                    : () => _open((u['id'] ?? '').toString()),
              ),
        ],
      ),
    );
  }
}
