import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: 'Privacy Policy',
      child: _PrivacyBody(),
    );
  }
}

class _PrivacyBody extends StatelessWidget {
  const _PrivacyBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.title('Privacy Policy'),
        const SizedBox(height: 10),
        Doc.meta('Effective date: February 8, 2026'),
        const SizedBox(height: 4),
        Doc.meta('Version: v1.1'),
        const SizedBox(height: 16),

        Doc.p(
          'Aura is committed to protecting the privacy, dignity, and autonomy of its readers, contributors, and visitors. '
          'This Privacy Policy explains what information Aura collects, how it is used, and the principles governing data handling.',
        ),
        Doc.p('Aura treats privacy as an ethical obligation, not merely a legal requirement.'),

        Doc.h('1. Information We Collect'),
        Doc.p('Aura collects only the minimum information necessary to operate:'),
        Doc.bullets([
          'Account information provided voluntarily (such as name or email)',
          'Content submitted by users (essays, notes, correspondence)',
          'Technical data required for basic site functionality (such as cookies essential for login)',
        ]),
        Doc.p('Aura does not collect behavioral analytics for engagement optimization.'),

        Doc.h('2. Information We Do Not Collect'),
        Doc.p('Aura explicitly does not collect:'),
        Doc.bullets([
          'Behavioral tracking data',
          'Third-party advertising identifiers',
          'Location tracking beyond coarse operational needs',
          'Social graph data',
          'Biometric or sensitive personal data',
        ]),

        Doc.h('3. How Information Is Used'),
        Doc.p('Information is used only to:'),
        Doc.bullets([
          'Provide access to Aura’s services',
          'Preserve and display submitted content',
          'Communicate essential service-related information',
        ]),
        Doc.p('Aura does not use personal data to influence behavior, personalize feeds, or drive engagement.'),

        Doc.h('4. Sharing and Disclosure'),
        Doc.p(
          'Aura does not sell personal information. Aura shares data only when required to operate the service '
          '(for example, infrastructure providers) or when legally required.',
        ),

        Doc.h('5. Data Retention'),
        Doc.p(
          'Aura retains account and content data only as long as needed for the service to function. '
          'Users may request deletion of their account and associated data, subject to legitimate operational and legal constraints.',
        ),

        Doc.h('6. Security'),
        Doc.p(
          'Aura applies reasonable administrative, technical, and organizational safeguards. '
          'No system is perfect, but Aura is designed to minimize data exposure by collecting less in the first place.',
        ),

        Doc.h('7. Contact'),
        Doc.p('Questions or requests can be directed to: muhammadsakhawat@gmail.com'),
      ],
    );
  }
}
