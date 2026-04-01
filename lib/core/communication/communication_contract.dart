enum CommunicationInteractionFamily {
  directCall,
  spaceCall,
  liveRoom,
  unknown,
}

enum CommunicationOwnerType {
  thread,
  space,
  room,
  unknown,
}

class CommunicationContract {
  const CommunicationContract({
    required this.interactionFamily,
    required this.ownerType,
    this.ownerId,
    this.threadId,
    this.spaceId,
    this.sessionId,
    this.mediaMode,
    this.returnRoute,
    this.contextName,
    this.attention,
  });

  final CommunicationInteractionFamily interactionFamily;
  final CommunicationOwnerType ownerType;
  final String? ownerId;
  final String? threadId;
  final String? spaceId;
  final String? sessionId;
  final String? mediaMode;
  final String? returnRoute;
  final String? contextName;
  final String? attention;

  bool get isInline => (attention ?? '').trim().toUpperCase() == 'INLINE';
  bool get isInterrupt => (attention ?? '').trim().toUpperCase() == 'INTERRUPT';
}
