import '../core/auth/session_bootstrap.dart';
import '../core/client_identity/client_identity_provider.dart';
import '../core/media/media_url_resolver.dart';
import '../core/net/data_changes.dart';
import '../features/conversation/presentation/conversation_screen.dart';
import '../features/feed/data/unified_feed_providers.dart';
import '../features/institutions/data/institutions_repository.dart';
import '../features/institutions/kind/kind_composition.dart';
import '../features/monetization/data/store_country.dart';
import '../features/monetization/providers/monetization_providers.dart';

/// The one [EditRefreshObserver] for the app (see data_changes.dart).
final editRefreshObserver = EditRefreshObserver(
  exclude: {
    // Run once per launch; running again would restart sign-in.
    sessionBootstrapProvider,
    clientIdentityProvider,
    // These PERFORM an action; reading them again would repeat it.
    approveInstitutionRequestProvider,
    rejectInstitutionRequestProvider,
    // Asks again on its own timer while a call is shown.
    conversationActiveLiveProvider,
    // Signed media links and fixed configuration: no edit changes them.
    mediaUrlProvider,
    mediaPosterUrlProvider,
    kindCatalogueProvider,
    appStoreCountryProvider,
    monetizationConfigProvider,
  },
  include: {
    globalPublicFeedPagedProvider,
    memberHomeFeedPagedProvider,
    institutionExploreFeedPagedProvider,
    institutionProfileFeedPagedProvider,
  },
);
