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
      case CommunicationOwner.thread:
        if ((target.deeplink ?? '').trim().isNotEmpty) return target.deeplink!.trim();
        if ((target.spaceId ?? '').isNotEmpty && (target.threadId ?? '').isNotEmpty) {
          return (target.sessionId ?? '').isNotEmpty
              ? '/me/correspondence/${target.spaceId!}/thread/${target.threadId!}/live/${target.sessionId!}'
              : '/me/correspondence/${target.spaceId!}/thread/${target.threadId!}/live';
        }
        return '/me/correspondence';
      case CommunicationOwner.space:
        if ((target.deeplink ?? '').trim().isNotEmpty) return target.deeplink!.trim();
        if ((target.spaceId ?? '').isNotEmpty) {
          return (target.sessionId ?? '').isNotEmpty
              ? '/me/correspondence/${target.spaceId!}/live/${target.sessionId!}'
              : '/me/correspondence/${target.spaceId!}/live';
        }
        return '/me/correspondence';
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
