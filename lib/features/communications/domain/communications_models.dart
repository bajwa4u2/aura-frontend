enum CommunicationChannelOption {
  inApp,
  email,
  both,
  none,
}

extension CommunicationChannelOptionX on CommunicationChannelOption {
  String get value {
    switch (this) {
      case CommunicationChannelOption.inApp:
        return 'IN_APP';
      case CommunicationChannelOption.email:
        return 'EMAIL';
      case CommunicationChannelOption.both:
        return 'BOTH';
      case CommunicationChannelOption.none:
        return 'NONE';
    }
  }

  String get label {
    switch (this) {
      case CommunicationChannelOption.inApp:
        return 'In app';
      case CommunicationChannelOption.email:
        return 'Email';
      case CommunicationChannelOption.both:
        return 'Both';
      case CommunicationChannelOption.none:
        return 'None';
    }
  }

}

CommunicationChannelOption communicationChannelOptionFromRaw(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'IN_APP':
      return CommunicationChannelOption.inApp;
    case 'EMAIL':
      return CommunicationChannelOption.email;
    case 'NONE':
      return CommunicationChannelOption.none;
    case 'BOTH':
    default:
      return CommunicationChannelOption.both;
  }
}

enum CommunicationFrequencyOption {
  instant,
  dailyDigest,
  weeklyDigest,
  never,
}

extension CommunicationFrequencyOptionX on CommunicationFrequencyOption {
  String get value {
    switch (this) {
      case CommunicationFrequencyOption.instant:
        return 'INSTANT';
      case CommunicationFrequencyOption.dailyDigest:
        return 'DAILY_DIGEST';
      case CommunicationFrequencyOption.weeklyDigest:
        return 'WEEKLY_DIGEST';
      case CommunicationFrequencyOption.never:
        return 'NEVER';
    }
  }

  String get label {
    switch (this) {
      case CommunicationFrequencyOption.instant:
        return 'Instant';
      case CommunicationFrequencyOption.dailyDigest:
        return 'Daily digest';
      case CommunicationFrequencyOption.weeklyDigest:
        return 'Weekly digest';
      case CommunicationFrequencyOption.never:
        return 'Never';
    }
  }

}

CommunicationFrequencyOption communicationFrequencyOptionFromRaw(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'DAILY_DIGEST':
      return CommunicationFrequencyOption.dailyDigest;
    case 'WEEKLY_DIGEST':
      return CommunicationFrequencyOption.weeklyDigest;
    case 'NEVER':
      return CommunicationFrequencyOption.never;
    case 'INSTANT':
    default:
      return CommunicationFrequencyOption.instant;
  }
}

class CommunicationPreferenceGroup {
  const CommunicationPreferenceGroup({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.channel,
    required this.frequency,
    required this.raw,
    this.protected = false,
  });

  final String key;
  final String title;
  final String subtitle;
  final CommunicationChannelOption channel;
  final CommunicationFrequencyOption frequency;
  final Map<String, dynamic> raw;
  final bool protected;

  CommunicationPreferenceGroup copyWith({
    CommunicationChannelOption? channel,
    CommunicationFrequencyOption? frequency,
  }) {
    return CommunicationPreferenceGroup(
      key: key,
      title: title,
      subtitle: subtitle,
      channel: channel ?? this.channel,
      frequency: frequency ?? this.frequency,
      raw: raw,
      protected: protected,
    );
  }
}

class CommunicationPreferences {
  const CommunicationPreferences({
    required this.raw,
    required this.inAppEnabled,
    required this.emailEnabled,
    required this.legacyFlags,
    required this.groups,
  });

  final Map<String, dynamic> raw;
  final bool inAppEnabled;
  final bool emailEnabled;
  final Map<String, bool> legacyFlags;
  final Map<String, CommunicationPreferenceGroup> groups;

  CommunicationPreferenceGroup? group(String key) => groups[key];

  bool legacy(String key, {bool fallback = true}) {
    return legacyFlags[key] ?? fallback;
  }
}

class CommunicationRenderPreview {
  const CommunicationRenderPreview({
    required this.subject,
    required this.previewText,
    required this.text,
    required this.html,
    required this.raw,
  });

  final String subject;
  final String previewText;
  final String text;
  final String html;
  final Map<String, dynamic> raw;
}

class DigestPreviewResult {
  const DigestPreviewResult({
    required this.frequency,
    required this.itemCount,
    required this.subject,
    required this.previewText,
    required this.items,
    required this.raw,
  });

  final String frequency;
  final int itemCount;
  final String subject;
  final String previewText;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> raw;
}

class DigestActionResult {
  const DigestActionResult({
    required this.frequency,
    required this.raw,
  });

  final String frequency;
  final Map<String, dynamic> raw;
}

class NewsletterTestResult {
  const NewsletterTestResult({
    required this.ok,
    required this.queued,
    required this.skipped,
    required this.reason,
    required this.outboxId,
    required this.raw,
  });

  final bool ok;
  final bool queued;
  final bool skipped;
  final String reason;
  final String outboxId;
  final Map<String, dynamic> raw;
}

class CommunicationDraftResult {
  const CommunicationDraftResult({
    required this.id,
    required this.status,
    required this.source,
    required this.subject,
    required this.bodyText,
    required this.sendStatus,
    required this.raw,
  });

  final String id;
  final String status;
  final String source;
  final String subject;
  final String bodyText;
  final String sendStatus;
  final Map<String, dynamic> raw;
}

class CampaignCreationResult {
  const CampaignCreationResult({
    required this.campaignId,
    required this.campaignStatus,
    required this.draftId,
    required this.draftStatus,
    required this.raw,
  });

  final String campaignId;
  final String campaignStatus;
  final String draftId;
  final String draftStatus;
  final Map<String, dynamic> raw;
}

class CampaignActionResult {
  const CampaignActionResult({
    required this.status,
    required this.raw,
  });

  final String status;
  final Map<String, dynamic> raw;
}

class CampaignQueueResult {
  const CampaignQueueResult({
    required this.ok,
    required this.queued,
    required this.skipped,
    required this.reason,
    required this.outboxId,
    required this.raw,
  });

  final bool ok;
  final bool queued;
  final bool skipped;
  final String reason;
  final String outboxId;
  final Map<String, dynamic> raw;
}
