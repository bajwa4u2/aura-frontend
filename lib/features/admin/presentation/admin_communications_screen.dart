import 'package:flutter/material.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../communications/presentation/widgets/admin_communication_workspace.dart';

class AdminCommunicationsScreen extends StatelessWidget {
  const AdminCommunicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Communications',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s20,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: const AdminCommunicationWorkspace(),
            ),
          ),
        ],
      ),
    );
  }
}
