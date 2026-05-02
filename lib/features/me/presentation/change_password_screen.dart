import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_repository.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.changePassword(
        currentPassword: _currentCtrl.text.trim(),
        newPassword: _newCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
      context.pop();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _currentCtrl,
                obscureText: !_showCurrent,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: IconButton(
                    icon: Icon(_showCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showCurrent = !_showCurrent),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newCtrl,
                obscureText: !_showNew,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a new password';
                  if (v.trim().length < 8) return 'Password must be at least 8 characters';
                  if (v.trim() == _currentCtrl.text.trim()) {
                    return 'New password must differ from current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: !_showConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please confirm your new password';
                  if (v.trim() != _newCtrl.text.trim()) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Change Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
