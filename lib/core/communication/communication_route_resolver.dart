import 'communication_contract.dart';

class CommunicationRouteResolver {
  const CommunicationRouteResolver();

  String resolve(CommunicationContract contract) {
    if ((contract.returnRoute ?? '').trim().isNotEmpty) {
      return contract.returnRoute!.trim();
    }

    switch (contract.ownerType) {
      // Phase 5 retired the `/me/correspondence` family. A legacy thread or
      // space owner names no surviving surface and there is no mapping to a
      // canonical one, so a live contract for either is addressed by the
      // session it is actually happening in — the same answer `room` already
      // gave. When there is no session there is nothing honest to point at,
      // and the fallback below applies.
      case CommunicationOwnerType.thread:
      case CommunicationOwnerType.space:
        if ((contract.sessionId ?? '').isNotEmpty) {
          return '/realtime/${contract.sessionId}?action=join';
        }
        break;
      case CommunicationOwnerType.room:
        if ((contract.sessionId ?? '').isNotEmpty) {
          return '/realtime/${contract.sessionId}?action=join';
        }
        return '/realtime';
      case CommunicationOwnerType.unknown:
        break;
    }

    return '/activity';
  }
}
