import 'communication_contract.dart';
import 'communication_contract_parser.dart';
import 'communication_route_resolver.dart';

enum CommunicationOwner {
  thread,
  space,
  standaloneRealtime,
  unknown,
}

class CommunicationTarget {
  final CommunicationOwner owner;
  final String? threadId;
  final String? spaceId;
  final String? sessionId;
  final String? deeplink;
  final String? context;
  final String? mode;
  final String? attention;

  const CommunicationTarget({
    required this.owner,
    this.threadId,
    this.spaceId,
    this.sessionId,
    this.deeplink,
    this.context,
    this.mode,
    this.attention,
  });

  bool get hasOwner => owner != CommunicationOwner.unknown;
  bool get isInline => (attention ?? '').toUpperCase() == 'INLINE';
}

class CommunicationResolver {
  const CommunicationResolver();

  static const CommunicationContractParser _parser = CommunicationContractParser();
  static const CommunicationRouteResolver _routes = CommunicationRouteResolver();

  CommunicationTarget resolveFromPayload(Map<String, dynamic> payload) {
    final contract = _parser.parse(payload);
    final route = _routes.resolve(contract);

    final owner = switch (contract.ownerType) {
      CommunicationOwnerType.thread => CommunicationOwner.thread,
      CommunicationOwnerType.space => CommunicationOwner.space,
      CommunicationOwnerType.room => CommunicationOwner.standaloneRealtime,
      CommunicationOwnerType.unknown => CommunicationOwner.unknown,
    };

    return CommunicationTarget(
      owner: owner,
      threadId: contract.threadId,
      spaceId: contract.spaceId,
      sessionId: contract.sessionId,
      deeplink: route,
      context: contract.contextName,
      mode: contract.mediaMode,
      attention: contract.attention,
    );
  }

  String resolveRoute(CommunicationTarget target) {
    switch (target.owner) {
      // CO-RC-C7-005 Phase 5: correspondence thread and space routes are
      // retired, so resolving to them would send live traffic — an Activity
      // tap, an incoming-call overlay — into a runtime that no longer exists.
      // What still matters about these targets is the SESSION, and the
      // canonical realtime address serves it. Where there is no session there
      // is nothing left to open, so the honest destination is Activity rather
      // than a dead correspondence address.
      case CommunicationOwner.thread:
      case CommunicationOwner.space:
        if ((target.deeplink ?? '').trim().isNotEmpty) return target.deeplink!.trim();
        if ((target.sessionId ?? '').isNotEmpty) {
          return '/realtime/${target.sessionId!}?action=join';
        }
        return '/activity';
      case CommunicationOwner.standaloneRealtime:
        if ((target.deeplink ?? '').trim().isNotEmpty) return target.deeplink!.trim();
        if ((target.sessionId ?? '').isNotEmpty) {
          return '/realtime/${target.sessionId!}?action=join';
        }
        return '/realtime';
      case CommunicationOwner.unknown:
        return target.deeplink ?? '/activity';
    }
  }
}
