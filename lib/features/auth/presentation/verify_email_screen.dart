import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_scaffold.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _loading = true;
  bool _verified = false;
  String? _email;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      // Prefer auth/me now that backend supports it.
      final res = await dio.get('/v1/auth/me');

      final data = res.data;
      DateTime? emailVerifiedAt;

      if (data is Map && data['user'] is Map) {
        _email = (data['user']['email'] ?? '').toString();
        final raw = data['user']['emailVerifiedAt'];
        if (raw != null) emailVerifiedAt = DateTime.tryParse(raw.toString());
      } else if (data is Map) {
        // fallback if backend returns user directly
        _email = (data['email'] ?? '').toString();
        final raw = data['emailVerifiedAt'];
        if (raw != null) emailVerifiedAt = DateTime.tryParse(raw.toString());
      }

      _verified = emailVerifiedAt != null;

      setState(() {
        _loading = false;
      });

      // If verified, you can route to home here if you want.
      // If your router has a named home route, switch to it.
      // For now, we just update UI state.
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not check status. $e';
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
    });

    try {
      final email = _email;
      if (email == null || email.trim().isEmpty) {
        setState(() {
          _error = 'Missing email in session. Please log in again.';
        });
        return;
      }

      final dio = ref.read(dioProvider);
      await dio.post('/v1/auth/resend-verification', data: {'email': email.trim()});

      setState(() {
        _error = 'Verification email sent.';
      });
    } catch (e) {
      setState(() {
        _error = 'Resend failed. $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Verify email',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'One more step',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _verified
                        ? 'Your email is verified.'
                        : 'Your account is created, but email is not verified yet. Please verify to continue.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_email != null && _email!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _email!,
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: _error == 'Verification email sent.' ? Colors.green : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: _loading ? null : _resend,
                        child: const Text('Resend verification email'),
                      ),
                      OutlinedButton(
                        onPressed: _loading ? null : _refreshStatus,
                        child: const Text("I've verified, continue"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}