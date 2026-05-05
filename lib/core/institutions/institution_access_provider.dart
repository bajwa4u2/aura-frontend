import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_bootstrap.dart';
import '../auth/session_providers.dart';
import '../net/dio_provider.dart';

enum InstitutionAccessState {
  none,
  pending,
  verifiedMember,
  authorizedSpeaker,
}

class InstitutionAccess {
  final InstitutionAccessState state;
  final Map<String, dynamic>? institution;
  final Map<String, dynamic>? membership;
  final Map<String, dynamic>? request;

  const InstitutionAccess({
    required this.state,
    this.institution,
    this.membership,
    this.request,
  });

  bool get hasAccess =>
      state == InstitutionAccessState.pending ||
      state == InstitutionAccessState.verifiedMember ||
      state == InstitutionAccessState.authorizedSpeaker;
}

/// Derived, synchronous view of the current institution's identity and the
/// acting member's admin status. Null until the institution access resolves
/// and the user has an institution with a known id.
class InstitutionIdentity {
  const InstitutionIdentity({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    required this.isAdmin,
    required this.isAuthorizedSpeaker,
    this.status,
    this.role,
  });

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final bool isAdmin;
  final bool isAuthorizedSpeaker;

  /// Institution verification/lifecycle status, e.g. 'VERIFIED', 'PENDING'.
  final String? status;

  /// Membership role in canonical wire format, e.g. 'OWNER', 'ADMIN',
  /// 'EDITOR', 'MEMBER'. Null for institution-account tokens.
  final String? role;

  bool get isVerified => (status ?? '').toUpperCase() == 'VERIFIED';

  bool get isOwner => (role ?? '').toUpperCase() == 'OWNER';

  /// True when the acting member is at least EDITOR (EDITOR/ADMIN/OWNER).
  bool get canCreatePosts {
    final r = (role ?? '').toUpperCase();
    return r == 'OWNER' ||
        r == 'ADMIN' ||
        r == 'EDITOR' ||
        isAdmin ||
        isAuthorizedSpeaker;
  }

  /// True when the acting member can publish/approve posts directly.
  bool get canPublishPosts {
    final r = (role ?? '').toUpperCase();
    return r == 'OWNER' || r == 'ADMIN' || isAdmin || isAuthorizedSpeaker;
  }
}

final institutionIdentityProvider = Provider<InstitutionIdentity?>((ref) {
  final access = ref.watch(institutionAccessProvider).valueOrNull;
  if (access == null || !access.hasAccess) return null;

  // Institution data may be at access.institution or inside access.membership['institution'].
  final inst = access.institution ??
      (access.membership?['institution'] is Map
          ? Map<String, dynamic>.from(
              access.membership!['institution'] as Map,
            )
          : null);

  if (inst == null) return null;

  String readStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  final id = readStr(inst, ['id']);
  if (id.isEmpty) return null;

  final membership = access.membership;
  final role = (membership?['role'] ?? '').toString().trim().toUpperCase();
  final canSpeak = membership?['canSpeakOfficially'] == true;
  final isAuthorizedSpeaker =
      access.state == InstitutionAccessState.authorizedSpeaker;
  final isAdmin =
      role == 'ADMIN' || role == 'OWNER' || canSpeak || isAuthorizedSpeaker;
  final status = readStr(inst, ['status', 'verificationStatus']);

  String? readOpt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  // Synthesize a status when the inst payload only carries an isVerified flag.
  String? finalStatus = status.isNotEmpty ? status.toUpperCase() : null;
  if (finalStatus == null) {
    final isVerifiedRaw = inst['isVerified'] ?? inst['verified'];
    if (isVerifiedRaw == true || isVerifiedRaw == 1 || isVerifiedRaw == 'true') {
      finalStatus = 'VERIFIED';
    }
  }

  return InstitutionIdentity(
    id: id,
    name: readStr(inst, ['name', 'displayName', 'title', 'organizationName']),
    slug: readStr(inst, ['slug', 'handle']),
    logoUrl: readOpt(inst, ['logoUrl', 'avatarUrl', 'logo']),
    isAdmin: isAdmin,
    isAuthorizedSpeaker: isAuthorizedSpeaker,
    status: finalStatus,
    role: role.isEmpty ? null : role,
  );
});

final institutionAccessProvider = FutureProvider<InstitutionAccess>((ref) async {
  await ref.watch(sessionBootstrapProvider.future);

  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) {
    return const InstitutionAccess(state: InstitutionAccessState.none);
  }

  final dio = ref.watch(dioProvider);

  // Probe accountType from /auth/me. INSTITUTION accounts represent the
  // institution itself; PUBLIC accounts may be members of an institution.
  // Both rely on /institutions/me for the actual institution + membership
  // payload — /auth/me itself does not return institution data.
  String accountType = 'PUBLIC';
  try {
    final meData = await ref.watch(authMeDataProvider.future);
    accountType = (meData['accountType'] ?? '').toString().toUpperCase();
  } catch (_) {
    // /auth/me may transiently fail; treat as PUBLIC and let the call below
    // surface the real error if institutional access is required.
  }

  try {
    final res = await dio.get('/institutions/me');
    final data = Map<String, dynamic>.from(res.data);
    final stateRaw = (data['state'] ?? '').toString().trim();

    InstitutionAccessState parsed;
    switch (stateRaw) {
      case 'PENDING_REQUEST':
        parsed = InstitutionAccessState.pending;
        break;
      case 'VERIFIED_MEMBER':
        parsed = InstitutionAccessState.verifiedMember;
        break;
      case 'AUTHORIZED_SPEAKER':
        parsed = InstitutionAccessState.authorizedSpeaker;
        break;
      default:
        parsed = InstitutionAccessState.none;
    }

    final institution = data['institution'] is Map
        ? Map<String, dynamic>.from(data['institution'])
        : null;
    final membership = data['membership'] is Map
        ? Map<String, dynamic>.from(data['membership'])
        : (institution != null
            // Institution-account users without an explicit membership row
            // still act as the institution itself; synthesise a minimal
            // membership envelope so downstream consumers see the institution.
            ? <String, dynamic>{'institution': institution}
            : null);

    // Institution-account tokens always grant full speaker rights, even if
    // the /institutions/me state field is missing or downgraded.
    if (accountType == 'INSTITUTION' && institution != null) {
      parsed = InstitutionAccessState.authorizedSpeaker;
    }

    return InstitutionAccess(
      state: parsed,
      institution: institution,
      membership: membership,
      request: data['request'] is Map
          ? Map<String, dynamic>.from(data['request'])
          : null,
    );
  } on DioException catch (e) {
    final code = e.response?.statusCode;

    if (code == 401 || code == 403) {
      return const InstitutionAccess(state: InstitutionAccessState.none);
    }

    rethrow;
  }
});