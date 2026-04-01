import 'communication_contract.dart';

class CommunicationRouteResolver {
  const CommunicationRouteResolver();

  String resolve(CommunicationContract contract) {
    if ((contract.returnRoute ?? '').trim().isNotEmpty) {
      return contract.returnRoute!.trim();
    }

    switch (contract.ownerType) {
      case CommunicationOwnerType.thread:
        if ((contract.spaceId ?? '').isNotEmpty && (contract.threadId ?? '').isNotEmpty) {
          return contract.sessionId == null || contract.sessionId!.isEmpty
              ? '/me/correspondence/${contract.spaceId}/thread/${contract.threadId}/live'
              : '/me/correspondence/${contract.spaceId}/thread/${contract.threadId}/live/${contract.sessionId}';
        }
        break;
      case CommunicationOwnerType.space:
        if ((contract.spaceId ?? '').isNotEmpty) {
          return contract.sessionId == null || contract.sessionId!.isEmpty
              ? '/me/correspondence/${contract.spaceId}/live'
              : '/me/correspondence/${contract.spaceId}/live/${contract.sessionId}';
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
