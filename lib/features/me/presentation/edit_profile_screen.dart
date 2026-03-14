import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _avatarUrlController;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _handle = '';
  String _email = '';

  @override
  void initState() {
    super.initState();

    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _avatarUrlController = TextEditingController();

    Future.microtask(_load);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final dio = ref.read(dioProvider);

    try {
      final res = await dio.get('/v1/users/me');
      final data = res.data;

      if (!mounted) return;

      _displayNameController.text =
          (data['displayName'] ?? '').toString().trim();
      _bioController.text = (data['bio'] ?? '').toString();
      _avatarUrlController.text =
          (data['avatarUrl'] ?? '').toString().trim();

      _handle = (data['handle'] ?? '').toString();
      _email = (data['email'] ?? '').toString();

      setState(() {
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load profile';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final dio = ref.read(dioProvider);

    try {
      await dio.patch(
        '/v1/users/me',
        data: {
          "displayName": _displayNameController.text.trim(),
          "bio": _bioController.text.trim(),
          "avatarUrl": _avatarUrlController.text.trim(),
        },
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message'] ?? 'Failed to save profile';
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to save profile';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : AuraCard(
                    padding: const EdgeInsets.all(AuraSpace.s20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Profile',
                            style: AuraText.body.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AuraSpace.s16),

                          if (_handle.isNotEmpty)
                            Text('@$_handle', style: AuraText.small),

                          if (_email.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AuraSpace.s12),
                              child: Text(_email, style: AuraText.small),
                            ),

                          const SizedBox(height: AuraSpace.s12),

                          TextFormField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: 'Display name',
                            ),
                          ),

                          const SizedBox(height: AuraSpace.s12),

                          TextFormField(
                            controller: _bioController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                            ),
                          ),

                          const SizedBox(height: AuraSpace.s12),

                          TextFormField(
                            controller: _avatarUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Avatar URL',
                            ),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: AuraSpace.s12),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],

                          const SizedBox(height: AuraSpace.s20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: AuraSpace.s8),
                              ElevatedButton(
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save'),
                              ),
                            ],
                          )
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