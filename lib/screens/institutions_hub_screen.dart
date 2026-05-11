// Public institution directory entry point.
//
// `/institutions` is the public hub. Visitors — signed-in or not —
// see the same verified-first directory. The auth-aware affordance
// lives inside the directory header (sign-in / workspace pill); we
// no longer silent-redirect signed-in users to the workspace, because
// the brief is explicit: institutional discovery must not feel hidden
// behind auth.
//
// Operators reach their workspace via `/institution/dashboard` (or
// via the "Your workspace" pill on this page). The onboarding path
// for a brand-new institution remains `/institutions/get-started`.

import 'package:flutter/material.dart';

import '../features/public/presentation/public_institutions_directory_screen.dart';

class InstitutionsHubScreen extends StatelessWidget {
  const InstitutionsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PublicInstitutionsDirectoryScreen();
  }
}
