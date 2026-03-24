import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: 'Terms',
      child: _TermsBody(),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.title('Terms'),
        Doc.meta('Working terms for access to Aura Platform.'),
        Doc.lede(
          'Aura is a structured publishing and correspondence environment. These terms exist to keep access clear, use responsible, and the system stable for members, institutions, and visitors.',
        ),
        Doc.h('Use of the platform'),
        Doc.p(
          'You may browse public pages, create an account where available, and use Aura for lawful participation, publishing, correspondence, and institutional workflows.',
        ),
        Doc.p(
          'You may not use Aura to interfere with service operation, misrepresent identity, automate abusive activity, or publish material that violates applicable law or the platform rules that govern access.',
        ),
        Doc.h('Accounts and responsibility'),
        Doc.p(
          'You are responsible for activity carried out through your account and for maintaining the security of your access credentials. Access may be limited, suspended, or removed where necessary to protect the integrity of the system.',
        ),
        Doc.h('Content and availability'),
        Doc.p(
          'Users remain responsible for the content they publish or transmit through Aura. Public availability, account features, and institutional tools may evolve over time as the platform develops.',
        ),
        Doc.h('Contact'),
        Doc.p(
          'For questions related to platform access, privacy, or account issues, use the Contact route provided in the shell footer.',
        ),
      ],
    );
  }
}
