import 'communication_contract.dart';

class CommunicationContractParser {
  const CommunicationContractParser();

  CommunicationContract parse(Map<String, dynamic> payload) {
    final session = _mapOf(payload['session']);
    final metadata = _mapOf(session['metadata']);
    final metadataJson = _mapOf(session['metadataJson']);
    final meta = _mapOf(payload['metadata']);

    final threadId = _firstNonEmpty([
      _stringOf(payload['threadId']),
      _stringOf(meta['threadId']),
      _stringOf(metadata['threadId']),
      _stringOf(metadataJson['threadId']),
    ]);

    final spaceId = _firstNonEmpty([
      _stringOf(payload['spaceId']),
      _stringOf(meta['spaceId']),
      _stringOf(metadata['spaceId']),
      _stringOf(metadataJson['spaceId']),
    ]);

    final sessionId = _firstNonEmpty([
      _stringOf(payload['sessionId']),
      _stringOf(session['id']),
      _stringOf(payload['id']),
    ]);

    final interactionFamilyRaw = _firstNonEmpty([
      _stringOf(payload['interactionFamily']),
      _stringOf(meta['interactionFamily']),
      _stringOf(metadata['interactionFamily']),
      _stringOf(metadataJson['interactionFamily']),
      threadId.isNotEmpty ? 'DIRECT_CALL' : '',
      spaceId.isNotEmpty ? 'SPACE_CALL' : '',
      _stringOf(payload['ownerType']).toUpperCase() == 'ROOM' ? 'LIVE_ROOM' : '',
    ]).toUpperCase();

    final ownerTypeRaw = _firstNonEmpty([
      _stringOf(payload['ownerType']),
      _stringOf(meta['ownerType']),
      _stringOf(metadata['ownerType']),
      _stringOf(metadataJson['ownerType']),
      threadId.isNotEmpty ? 'THREAD' : '',
      spaceId.isNotEmpty ? 'SPACE' : '',
    ]).toUpperCase();

    return CommunicationContract(
      interactionFamily: _readFamily(interactionFamilyRaw),
      ownerType: _readOwner(ownerTypeRaw),
      ownerId: _firstNonEmpty([
        _stringOf(payload['ownerId']),
        _stringOf(meta['ownerId']),
        _stringOf(metadata['ownerId']),
        _stringOf(metadataJson['ownerId']),
        threadId,
        spaceId,
      ]).isEmpty ? null : _firstNonEmpty([
        _stringOf(payload['ownerId']),
        _stringOf(meta['ownerId']),
        _stringOf(metadata['ownerId']),
        _stringOf(metadataJson['ownerId']),
        threadId,
        spaceId,
      ]),
      threadId: threadId.isEmpty ? null : threadId,
      spaceId: spaceId.isEmpty ? null : spaceId,
      sessionId: sessionId.isEmpty ? null : sessionId,
      mediaMode: _firstNonEmpty([
        _stringOf(payload['mediaMode']),
        _stringOf(payload['mode']),
        _stringOf(meta['mediaMode']),
        _stringOf(metadata['mediaMode']),
        _stringOf(metadataJson['mediaMode']),
      ]).isEmpty ? null : _firstNonEmpty([
        _stringOf(payload['mediaMode']),
        _stringOf(payload['mode']),
        _stringOf(meta['mediaMode']),
        _stringOf(metadata['mediaMode']),
        _stringOf(metadataJson['mediaMode']),
      ]),
      returnRoute: _firstNonEmpty([
        _stringOf(payload['returnRoute']),
        _stringOf(payload['deeplink']),
        _stringOf(payload['link']),
        _stringOf(payload['url']),
        _stringOf(meta['returnRoute']),
        _stringOf(metadata['returnRoute']),
        _stringOf(metadataJson['returnRoute']),
      ]).isEmpty ? null : _firstNonEmpty([
        _stringOf(payload['returnRoute']),
        _stringOf(payload['deeplink']),
        _stringOf(payload['link']),
        _stringOf(payload['url']),
        _stringOf(meta['returnRoute']),
        _stringOf(metadata['returnRoute']),
        _stringOf(metadataJson['returnRoute']),
      ]),
      contextName: _firstNonEmpty([
        _stringOf(payload['contextName']),
        _stringOf(payload['threadTitle']),
        _stringOf(payload['spaceName']),
        _stringOf(payload['roomTitle']),
        _stringOf(meta['contextName']),
        _stringOf(metadata['contextName']),
        _stringOf(metadataJson['contextName']),
      ]).isEmpty ? null : _firstNonEmpty([
        _stringOf(payload['contextName']),
        _stringOf(payload['threadTitle']),
        _stringOf(payload['spaceName']),
        _stringOf(payload['roomTitle']),
        _stringOf(meta['contextName']),
        _stringOf(metadata['contextName']),
        _stringOf(metadataJson['contextName']),
      ]),
      attention: _firstNonEmpty([
        _stringOf(payload['attention']),
        _stringOf(meta['attention']),
        _stringOf(metadata['attention']),
        _stringOf(metadataJson['attention']),
      ]).isEmpty ? null : _firstNonEmpty([
        _stringOf(payload['attention']),
        _stringOf(meta['attention']),
        _stringOf(metadata['attention']),
        _stringOf(metadataJson['attention']),
      ]),
    );
  }

  CommunicationInteractionFamily _readFamily(String value) {
    switch (value) {
      case 'DIRECT_CALL':
        return CommunicationInteractionFamily.directCall;
      case 'SPACE_CALL':
        return CommunicationInteractionFamily.spaceCall;
      case 'LIVE_ROOM':
        return CommunicationInteractionFamily.liveRoom;
      default:
        return CommunicationInteractionFamily.unknown;
    }
  }

  CommunicationOwnerType _readOwner(String value) {
    switch (value) {
      case 'THREAD':
        return CommunicationOwnerType.thread;
      case 'SPACE':
        return CommunicationOwnerType.space;
      case 'ROOM':
      case 'REALTIME':
        return CommunicationOwnerType.room;
      default:
        return CommunicationOwnerType.unknown;
    }
  }
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, val) => MapEntry(key.toString(), val));
  return const {};
}

String _stringOf(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
