import 'package:flutter/material.dart';

import '../../invitations/presentation/invite_create_screen.dart';

class InviteMemberScreen extends StatelessWidget {
  const InviteMemberScreen({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  @override
  Widget build(BuildContext context) {
    return InviteCreateScreen(
      destinationType: 'JOIN_SPACE',
      spaceId: spaceId,
    );
  }
}
