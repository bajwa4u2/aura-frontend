import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/session_bootstrap.dart';
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

final institutionAccessProvider = FutureProvider<InstitutionAccess>((ref) async {
  await ref.watch(sessionBootstrapProvider.future);

  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) {
    return const InstitutionAccess(
      state: InstitutionAccessState.none,
    );
  }

  final dio = ref.watch(dioProvider);

  try {
    final res = await dio.get('/institutions/me');

    final data = Map<String, dynamic>.from(res.data);
    final state = (data['state'] ?? '').toString().trim();

    InstitutionAccessState parsed;
    switch (state) {
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

    return InstitutionAccess(
      state: parsed,
      institution: data['institution'] is Map
          ? Map<String, dynamic>.from(data['institution'])
          : null,
      membership: data['membership'] is Map
          ? Map<String, dynamic>.from(data['membership'])
          : null,
      request: data['request'] is Map
          ? Map<String, dynamic>.from(data['request'])
          : null,
    );
  } on DioException catch (e) {
    final code = e.response?.statusCode;

    if (code == 401 || code == 403) {
      return const InstitutionAccess(
        state: InstitutionAccessState.none,
      );
    }

    rethrow;
  }
});