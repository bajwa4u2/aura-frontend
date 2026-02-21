import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class InstitutionSignInScreen extends StatelessWidget {
  const InstitutionSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution sign in',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution sign in'),
          const SizedBox(height: 10),
          Doc.meta('For verified institutional participants.'),
          Doc.lede(
            'Institutions participate under the same visibility rules as citizens, but with a formal correction obligation.',
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.go('/login?redirect=%2Fhome'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text('Sign in', style: AuraText.body.copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/institution/request-verification'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text('Request verification', style: AuraText.body),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Doc.p(
            'If your institution is not yet verified, request verification first. Once approved, you can publish and respond under your institutional identity.',
          ),
        ],
      ),
    );
  }
}
