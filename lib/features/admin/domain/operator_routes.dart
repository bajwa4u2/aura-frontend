/// OPERATOR ROUTES, NAMED ONCE.
///
/// The C3 gate forbids navigating to a raw path literal, for a reason this
/// reconstruction has already met twice: a path typed at a call site is a path
/// nothing can check. The backend published `/join/:code` as a destination no
/// router declared, and the old console had five routes no navigation entry
/// pointed at. Both were literals nobody could compare against anything.
///
/// Area roots live on [OperatorArea] because navigation is derived from
/// capability. These are the deeper destinations inside an area.
library;

/// Subject detail.
const String kOperatorPersonRoot = '/admin/subjects/person';
const String kOperatorInstitutionRoot = '/admin/subjects/institution';

/// Integrity detail.
const String kOperatorModerationRoot = '/admin/integrity/moderation';
const String kOperatorAppealRoot = '/admin/integrity/appeals';
const String kOperatorFeedbackRoot = '/admin/integrity/feedback';
const String kOperatorSupportRoot = '/admin/integrity/support';

/// Ids are percent-encoded: a handle or slug can legitimately contain
/// characters that would otherwise change which route matches.
String operatorPersonRoute(String userId) =>
    '$kOperatorPersonRoot/${Uri.encodeComponent(userId)}';

String operatorInstitutionRoute(String institutionId) =>
    '$kOperatorInstitutionRoot/${Uri.encodeComponent(institutionId)}';

String operatorModerationRoute(String reportId) =>
    '$kOperatorModerationRoot/${Uri.encodeComponent(reportId)}';

String operatorAppealRoute(String appealId) =>
    '$kOperatorAppealRoot/${Uri.encodeComponent(appealId)}';

String operatorFeedbackRoute(String feedbackId) =>
    '$kOperatorFeedbackRoot/${Uri.encodeComponent(feedbackId)}';

String operatorSupportRoute(String caseId) =>
    '$kOperatorSupportRoot/${Uri.encodeComponent(caseId)}';
