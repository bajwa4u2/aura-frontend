import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/admin_access_provider.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_profile_tab_bar.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/compact_profile_hero.dart';
import '../../../core/ui/profile_header.dart' show PresenceHeaderAction;
import 'me/me_widgets.dart';
import 'widgets/me_connected_accounts_panel.dart';

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  int _followersCount = 0;
  int _followingCount = 0;
  int _incomingRequestsCount = 0;
  int _outgoingRequestsCount = 0;
  int _incomingInvitesCount = 0;
  int _sentInvitesCount = 0;
  int _approvalInvitesCount = 0;

  Map<String, dynamic>? _tiktokAccount;
  bool _tiktokLoading = false;
  bool _tiktokActionBusy = false;

  Map<String, dynamic>? _linkedinAccount;
  bool _linkedinLoading = false;
  bool _linkedinActionBusy = false;
  bool _handledLinkedInRedirect = false;

  /// Top-level workspace tabs for the redesigned /me dashboard. Each entry is
  /// (label, icon); order defines the tab index consumed by [_tabContent].
  static const List<(String, IconData)> _tabs = [
    ('Identity', Icons.person_outline),
    ('Authority', Icons.account_balance_outlined),
    ('Participation', Icons.workspaces_outline),
    ('Network', Icons.hub_outlined),
    ('Account', Icons.settings_outlined),
  ];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleLinkedInRedirectIfNeeded());
      _kickAdminAuthorityProbe();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Trigger a single `GET /v1/admin/me` probe for this Me screen visit.
  ///
  /// Why this exists
  /// ---------------
  /// `appAdminAccessProvider` is gated by `appAdminProbeAllowedProvider`,
  /// which the router only flips on `/admin/*` navigation. The Me screen
  /// is a legitimate authority-discovery surface — eligible platform
  /// admins must be able to *find* the admin workspace entry from
  /// `/me`, not only after they've already opened `/admin`. Without
  /// this kick the Me screen reads `appAdminCachedDisplayProvider`
  /// which is `false` until the cache is populated, so the Admin
  /// Workspace tile never appears.
  ///
  /// The probe is bounded:
  ///   * Only fires when the user is authenticated.
  ///   * Only fires when the cache state is "unknown" (`null`). If a
  ///     previous probe already confirmed admin (`true`) or non-admin
  ///     (`false`) this session, we don't re-ask.
  ///   * Result populates `cachedAdminAuthorityProvider` exactly once
  ///     per session — subsequent /me visits become free.
  ///   * Non-admins (403 / 404) cache `false` and never re-probe.
  void _kickAdminAuthorityProbe() {
    if (!mounted) return;
    final authStatus = ref.read(authStatusProvider);
    if (authStatus != AuthStatus.authed) return;
    final cached = ref.read(cachedAdminAuthorityProvider);
    if (cached != null) return; // already known this session

    final allowedNotifier = ref.read(appAdminProbeAllowedProvider.notifier);
    if (!ref.read(appAdminProbeAllowedProvider)) {
      allowedNotifier.state = true;
    }
    // Fire-and-forget. The FutureProvider will populate the cache;
    // `_isAppAdmin` watches the cached display provider and will
    // rebuild when the cache flips.
    unawaited(ref.read(appAdminAccessProvider.future).then(
          (_) {},
          onError: (_) {},
        ));
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dio = ref.read(dioProvider);

      final meResponse = await dio.get('/users/me');
      final user = _unwrapUser(meResponse.data);

      final handle = _value(user['handle']);
      final futures = await Future.wait<dynamic>([
        if (handle.isNotEmpty)
          _safeGet(dio, '/users/$handle/followers')
        else
          Future.value(null),
        if (handle.isNotEmpty)
          _safeGet(dio, '/users/$handle/following')
        else
          Future.value(null),
        _safeGet(dio, '/users/me/follow/requests/inbox'),
        _safeGet(dio, '/users/me/follow/requests/outbox'),
        _safeGet(dio, '/integrations/tiktok/account'),
        _safeGet(dio, '/integrations/linkedin/account'),
        _safeGet(dio, '/invites'),
      ]);

      final followersRes = futures[0];
      final followingRes = futures[1];
      final inboxRes = futures[2];
      final outboxRes = futures[3];
      final tiktokRes = futures[4];
      final linkedinRes = futures[5];
      final inviteInboxRes = futures[6];

      if (!mounted) return;

      setState(() {
        _user = user;
        _followersCount = _countItemsFromPayload(followersRes?.data);
        _followingCount = _countItemsFromPayload(followingRes?.data);
        _incomingRequestsCount = _countItemsFromPayload(inboxRes?.data);
        _outgoingRequestsCount = _countItemsFromPayload(outboxRes?.data);
        _incomingInvitesCount = _countItemsFromPayload(inviteInboxRes?.data);
        _sentInvitesCount = 0;
        _approvalInvitesCount = 0;
        _tiktokAccount = _unwrapTikTokAccount(tiktokRes?.data);
        _linkedinAccount = _unwrapLinkedInAccount(linkedinRes?.data);
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _readApiError(e, fallback: 'Could not load your presence.');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your presence.';
        _loading = false;
      });
    }
  }

  Future<void> _handleLinkedInRedirectIfNeeded() async {
    if (_handledLinkedInRedirect || !mounted) return;
    _handledLinkedInRedirect = true;

    final query = Uri.base.queryParameters;
    if (!query.containsKey('linkedin')) return;

    final state = query['linkedin']?.trim() ?? '';
    final message = query['message']?.trim() ?? '';

    await _load();
    if (!mounted) return;

    final cleanPath = Uri.base.path.isEmpty ? '/me' : Uri.base.path;
    context.go(cleanPath);

    final snack = state.toLowerCase() == 'connected'
        ? 'LinkedIn connected.'
        : (message.isNotEmpty ? message : 'LinkedIn flow finished.');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(snack)));
  }

  Future<void> _reloadLinkedInOnly() async {
    if (mounted) setState(() => _linkedinLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final primary = await _safeGet(dio, '/integrations/linkedin/account');
      if (!mounted) return;
      setState(() => _linkedinAccount = _unwrapLinkedInAccount(primary?.data));
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _linkedinLoading = false);
    }
  }

  Future<void> _connectLinkedIn() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _linkedinActionBusy) return;

    setState(() => _linkedinActionBusy = true);

    try {
      final dio = ref.read(dioProvider);
      final res = await _getFirstSuccessful(dio, [
        '/integrations/linkedin/connect/start',
      ]);

      final root = _asMap(res.data);
      final nestedData = _asMap(root['data']);
      final nestedInnerData = _asMap(nestedData['data']);

      final authorizationUrl = _firstNonEmpty([
        _value(root['authorizationUrl']),
        _value(root['url']),
        _value(root['authUrl']),
        _value(root['authorization_url']),
        _value(nestedData['authorizationUrl']),
        _value(nestedData['url']),
        _value(nestedData['authUrl']),
        _value(nestedData['authorization_url']),
        _value(nestedInnerData['authorizationUrl']),
        _value(nestedInnerData['url']),
        _value(nestedInnerData['authUrl']),
        _value(nestedInnerData['authorization_url']),
      ]);

      if (authorizationUrl.isEmpty) {
        throw Exception('LinkedIn authorization URL was not returned.');
      }

      final uri = Uri.tryParse(authorizationUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw Exception('LinkedIn authorization URL is invalid.');
      }

      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) throw Exception('Could not open LinkedIn authorization.');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'LinkedIn authorization opened. Return here after approval.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start LinkedIn connection: $e')),
      );
    } finally {
      if (mounted) setState(() => _linkedinActionBusy = false);
    }
  }

  Future<void> _disconnectLinkedIn() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _linkedinActionBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect LinkedIn'),
        content: const Text(
          'This will remove your LinkedIn connection from Aura.',
        ),
        actions: [
          AuraGhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AuraPrimaryButton(
            label: 'Disconnect',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _linkedinActionBusy = true);

    try {
      final dio = ref.read(dioProvider);
      await _postFirstSuccessful(dio, ['/integrations/linkedin/disconnect']);
      if (!mounted) return;
      setState(() => _linkedinAccount = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('LinkedIn disconnected.')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _readApiError(e, fallback: 'Could not disconnect LinkedIn.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not disconnect LinkedIn: $e')),
      );
    } finally {
      if (mounted) setState(() => _linkedinActionBusy = false);
    }
  }

  Future<void> _reloadTikTokOnly() async {
    if (mounted) setState(() => _tiktokLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/integrations/tiktok/account');
      if (!mounted) return;
      setState(() => _tiktokAccount = _unwrapTikTokAccount(res.data));
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _tiktokLoading = false);
    }
  }

  Future<void> _connectTikTok() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _tiktokActionBusy) return;

    setState(() => _tiktokActionBusy = true);

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/integrations/tiktok/connect/start');

      final root = _asMap(res.data);
      final nestedData = _asMap(root['data']);
      final nestedInnerData = _asMap(nestedData['data']);

      final authorizationUrl = _firstNonEmpty([
        _value(root['authorizationUrl']),
        _value(root['url']),
        _value(root['authUrl']),
        _value(root['authorization_url']),
        _value(nestedData['authorizationUrl']),
        _value(nestedData['url']),
        _value(nestedData['authUrl']),
        _value(nestedData['authorization_url']),
        _value(nestedInnerData['authorizationUrl']),
        _value(nestedInnerData['url']),
        _value(nestedInnerData['authUrl']),
        _value(nestedInnerData['authorization_url']),
      ]);

      if (authorizationUrl.isEmpty) {
        throw Exception('TikTok authorization URL was not returned.');
      }

      final uri = Uri.tryParse(authorizationUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw Exception('TikTok authorization URL is invalid.');
      }

      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) throw Exception('Could not open TikTok authorization.');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'TikTok authorization opened. Return here after approval.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start TikTok connection: $e')),
      );
    } finally {
      if (mounted) setState(() => _tiktokActionBusy = false);
    }
  }

  Future<void> _refreshTikTokToken() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _tiktokActionBusy) return;

    setState(() => _tiktokActionBusy = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/integrations/tiktok/refresh');
      await _reloadTikTokOnly();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TikTok connection refreshed.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _readApiError(e, fallback: 'Could not refresh TikTok connection.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh TikTok connection: $e')),
      );
    } finally {
      if (mounted) setState(() => _tiktokActionBusy = false);
    }
  }

  Future<void> _disconnectTikTok() async {
    final userId = _currentUserId;
    if (userId.isEmpty || _tiktokActionBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect TikTok'),
        content: const Text(
          'This will remove your TikTok connection from Aura.',
        ),
        actions: [
          AuraGhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AuraPrimaryButton(
            label: 'Disconnect',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _tiktokActionBusy = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/integrations/tiktok/disconnect');
      if (!mounted) return;
      setState(() => _tiktokAccount = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('TikTok disconnected.')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _readApiError(e, fallback: 'Could not disconnect TikTok.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not disconnect TikTok: $e')),
      );
    } finally {
      if (mounted) setState(() => _tiktokActionBusy = false);
    }
  }

  String get _currentUserId =>
      _value((_user ?? const <String, dynamic>{})['id']);

  bool get _isLinkedInConnected {
    final account = _linkedinAccount;
    if (account == null) return false;

    final connected = account['connected'];
    if (connected is bool) return connected;

    return _firstNonEmpty([
      _value(account['linkedinMemberId']),
      _value(account['memberId']),
      _value(account['id']),
      _value(account['sub']),
      _value(account['name']),
      _value(account['email']),
    ]).isNotEmpty;
  }

  bool get _isTikTokConnected {
    final account = _tiktokAccount;
    if (account == null) return false;

    final connected = account['connected'];
    if (connected is bool) return connected;

    final userId = _value(account['platformUserId']);
    return userId.isNotEmpty || account.isNotEmpty;
  }

  String get _invitationCenterSubtitle {
    final parts = <String>[];
    if (_incomingInvitesCount > 0) {
      parts.add('$_incomingInvitesCount incoming');
    }
    if (_sentInvitesCount > 0) parts.add('$_sentInvitesCount sent');
    if (_approvalInvitesCount > 0) {
      parts.add('$_approvalInvitesCount pending approval');
    }
    if (parts.isEmpty) return 'Create, review, and manage invitation flow';
    return parts.join(' · ');
  }

  String get _followRequestsSubtitle {
    final parts = <String>[];
    if (_incomingRequestsCount > 0) {
      parts.add('$_incomingRequestsCount incoming');
    }
    if (_outgoingRequestsCount > 0) {
      parts.add('$_outgoingRequestsCount sent');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Presence',
      body: _loading
          ? const Center(
              child: AuraLoadingState(message: 'Loading your presence…'),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AuraSpace.s16),
                child: AuraErrorState(
                  title: 'Could not load your presence',
                  body: _error!,
                  action: AuraSecondaryButton(
                    label: 'Try again',
                    onPressed: _load,
                    icon: Icons.refresh_rounded,
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              color: AuraSurface.accent,
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _buildContent(context, constraints.maxWidth >= 900),
              ),
            ),
    );
  }

  // ─── SHARED DATA DERIVATION ────────────────────────────────────────────────

  Map<String, dynamic> get _resolvedUser => _user ?? <String, dynamic>{};

  String get _displayName => _firstNonEmpty([
        _value(_resolvedUser['displayName']),
        _value(_resolvedUser['name']),
      ]);

  String get _handle => _value(_resolvedUser['handle']);

  String get _titleText => _value(_resolvedUser['title']);

  String get _bio => _firstNonEmpty([
        _value(_resolvedUser['bio']),
        _value(_resolvedUser['headline']),
        _value(_resolvedUser['summary']),
      ]);

  String get _avatarUrl => _resolveMediaUrl(
        _firstNonEmpty([
          _value(_resolvedUser['avatarUrl']),
          _value(_resolvedUser['avatar']),
          _value(_resolvedUser['photoUrl']),
        ]),
      );

  String get _coverUrl => _resolveMediaUrl(
        _firstNonEmpty([
          _value(_resolvedUser['coverUrl']),
          _value(_resolvedUser['bannerUrl']),
          _value(_resolvedUser['coverImageUrl']),
          _value(_resolvedUser['headerImageUrl']),
        ]),
      );

  bool get _isAppAdmin {
    // Display-only: never trigger an admin probe from /me. The Admin
    // Workspace entry only appears for users who have already been
    // confirmed as platform admins this session (i.e. they navigated to
    // /admin/* at least once and the backend confirmed authority).
    return ref.watch(appAdminCachedDisplayProvider);
  }

  InstitutionAccess get _institutionAccess {
    final institutionAsync = ref.watch(institutionAccessProvider);
    return institutionAsync.maybeWhen(
      data: (v) => v,
      orElse: () => const InstitutionAccess(state: InstitutionAccessState.none),
    );
  }

  // ─── IDENTITY HERO META — identity signals only, no authority roles ────────

  List<Widget> _buildHeroMeta(String locationText, String websiteUrl) {
    final websiteLabel = _websiteLabel(websiteUrl);
    final joined = _joinedText;
    return [
      if (locationText.isNotEmpty) MeMetaChip(label: locationText),
      if (websiteLabel.isNotEmpty)
        MeMetaLinkChip(
          label: websiteLabel,
          onTap: () => _openExternalUrl(websiteUrl),
        ),
      if (joined.isNotEmpty) MeMetaChip(label: joined),
      // Authority roles intentionally excluded from the identity hero — they
      // live in the Authority tab. Followers / Following live in Network.
    ];
  }

  /// "Joined <Month> <Year>" derived from the account creation timestamp.
  /// Empty when no parseable timestamp is present — we never fabricate a date.
  String get _joinedText {
    final raw = _firstNonEmpty([
      _value(_resolvedUser['createdAt']),
      _value(_resolvedUser['created_at']),
      _value(_resolvedUser['joinedAt']),
      _value(_resolvedUser['joined_at']),
    ]);
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return 'Joined ${months[dt.month - 1]} ${dt.year}';
  }

  /// Identity-hero role chip: only shown when the member is an authorized
  /// speaker for an institution. Mirrors the shell's "Speaks for …" copy.
  String get _roleChipLabel {
    final access = _institutionAccess;
    if (access.state != InstitutionAccessState.authorizedSpeaker) return '';
    final institution = access.institution ?? const <String, dynamic>{};
    final request = access.request ?? const <String, dynamic>{};
    final name = _firstNonEmpty([
      _value(institution['name']),
      _value(request['organizationName']),
    ]);
    return name.isNotEmpty ? 'Speaks for $name' : 'Speaks for an institution';
  }

  // ─── ACCOUNT HEALTH PANEL ─────────────────────────────────────────────────

  Widget _buildAccountHealthPanel() {
    final user = _resolvedUser;
    final checks = <(String, bool)>[
      ('Display name', _displayName.isNotEmpty),
      ('Handle', _handle.isNotEmpty),
      ('Bio', _bio.isNotEmpty),
      ('Avatar', _avatarUrl.isNotEmpty),
      ('Location', _locationText(user).isNotEmpty),
      ('Website', _websiteText(user).isNotEmpty),
    ];

    final completed = checks.where((c) => c.$2).length;
    final total = checks.length;
    final fraction = completed / total;

    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: AuraSurface.accent,
              ),
              SizedBox(width: AuraSpace.s8),
              Text('Profile health', style: AuraText.title),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: AuraSurface.elevated,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      fraction >= 1.0
                          ? AuraSurface.coVerdant
                          : AuraSurface.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Text(
                '$completed / $total',
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s14),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s6,
            children: checks.map((c) {
              final done = c.$2;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: done ? AuraSurface.coVerdant.withValues(alpha: 0.16) : AuraSurface.elevated,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(
                    color: done
                        ? AuraSurface.coVerdant.withValues(alpha: 0.25)
                        : AuraSurface.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle_outline_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 12,
                      color: done ? AuraSurface.coVerdant : AuraSurface.faint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      c.$1,
                      style: AuraText.micro.copyWith(
                        color: done ? AuraSurface.coVerdant : AuraSurface.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (completed < total) ...[
            const SizedBox(height: AuraSpace.s16),
            GestureDetector(
              onTap: () async {
                await context.push('/me/edit');
                if (!mounted) return;
                await _load();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Complete your profile',
                    style: AuraText.small.copyWith(
                      color: AuraSurface.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AuraSurface.accent,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── SHARED SECTION WIDGETS ───────────────────────────────────────────────

  Widget _buildPersonalRecordSection() {
    return MeSection(
      title: 'Personal Record',
      children: [
        MeSettingsItem(
          label: 'Saved posts',
          icon: Icons.bookmark_outline,
          subtitle: 'Things you chose to keep close',
          onTap: () => context.push('/saved?kind=saved'),
        ),
        MeSettingsItem(
          label: 'Held for later',
          icon: Icons.schedule_outlined,
          subtitle: 'Work not released yet',
          onTap: () => context.push('/saved?kind=held'),
        ),
        MeSettingsItem(
          label: 'Private posts',
          icon: Icons.lock_outline,
          subtitle: 'Visible only to you',
          onTap: () => context.push('/saved?kind=private'),
        ),
      ],
    );
  }

  Widget _buildConnectionsSection() {
    final hasConnections = _incomingRequestsCount > 0 ||
        _outgoingRequestsCount > 0 ||
        _incomingInvitesCount > 0;

    return MeSection(
      title: 'Connections',
      children: [
        MeSettingsItem(
          label: 'Invitation center',
          icon: Icons.outbound_outlined,
          subtitle: _invitationCenterSubtitle,
          onTap: () => context.push('/me/invitations'),
        ),
        MeSettingsItem(
          label: 'New invite',
          icon: Icons.add_link_outlined,
          subtitle: 'Create an invitation into Aura, a space, or thread',
          onTap: () => context.push('/invite'),
        ),
        if (hasConnections)
          MeSettingsItem(
            label: 'Follow requests',
            icon: Icons.person_add_alt_outlined,
            subtitle: _followRequestsSubtitle,
            onTap: () => context.push('/me/follow-requests'),
          ),
      ],
    );
  }

  Widget _buildConnectedAccountsPanel() {
    return MeConnectedAccountsPanel(
      linkedinAccount: _linkedinAccount,
      linkedinLoading: _linkedinLoading,
      linkedinActionBusy: _linkedinActionBusy,
      isLinkedInConnected: _isLinkedInConnected,
      tiktokAccount: _tiktokAccount,
      tiktokLoading: _tiktokLoading,
      tiktokActionBusy: _tiktokActionBusy,
      isTikTokConnected: _isTikTokConnected,
      onConnectLinkedIn: _connectLinkedIn,
      onDisconnectLinkedIn: _disconnectLinkedIn,
      onCheckLinkedIn: _reloadLinkedInOnly,
      onConnectTikTok: _connectTikTok,
      onRefreshTikTok: _refreshTikTokToken,
      onDisconnectTikTok: _disconnectTikTok,
      onCheckTikTok: _reloadTikTokOnly,
    );
  }

  Widget _buildSettingsHub() {
    final emailVerifiedAsync = ref.watch(emailVerifiedProvider);
    final bool isVerified = emailVerifiedAsync.maybeWhen(
      data: (v) => v ?? true,
      orElse: () => true,
    );
    final verifying = emailVerifiedAsync is AsyncLoading;

    Widget? securityTrailing;
    if (!verifying) {
      securityTrailing = MeStatusBadge(
        label: isVerified ? 'Verified' : 'Verify email',
        style: isVerified ? MeStatusStyle.good : MeStatusStyle.warn,
      );
    }

    return MeSection(
      title: 'Settings',
      children: [
        MeSettingsItem(
          label: 'Security',
          icon: Icons.shield_outlined,
          subtitle: 'Password, email verification, and sessions',
          trailing: securityTrailing,
          onTap: () => context.push('/security'),
        ),
      ],
    );
  }

  Widget _buildWorkspacesSection(
    bool hasInstitutionWorkspace,
    bool isAppAdmin,
    String institutionLabel,
  ) {
    return MeSection(
      title: 'Authority & Workspaces',
      children: [
        if (hasInstitutionWorkspace)
          MeSettingsItem(
            label: institutionLabel.isNotEmpty
                ? institutionLabel
                : 'Institution workspace',
            icon: Icons.apartment_outlined,
            subtitle: 'Switch to institution workspace',
            onTap: () => context.push('/institution/dashboard'),
          ),
        if (isAppAdmin)
          MeSettingsItem(
            label: 'Aura Platform Admin',
            icon: Icons.admin_panel_settings_outlined,
            subtitle: 'Platform-wide controls, moderation, and audit',
            onTap: () => context.push('/admin'),
          ),
      ],
    );
  }

  // ─── UNIFIED CONTENT: COMPACT HERO + TABBED WORKSPACE ──────────────────────

  Widget _buildContent(BuildContext context, bool wide) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        wide ? AuraSpace.s24 : AuraSpace.s16,
        wide ? AuraSpace.s24 : AuraSpace.s16,
        wide ? AuraSpace.s24 : AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kWorkspaceWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(),
                const SizedBox(height: AuraSpace.s20),
                AuraProfileTabBar(controller: _tabController, tabs: _tabs),
                const SizedBox(height: AuraSpace.s20),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) =>
                      _tabContent(_tabController.index, wide),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── HERO + TAB CONTENT (hero & tab bar are shared core/ui widgets) ────────

  Widget _buildHero() {
    final user = _resolvedUser;
    final locationText = _locationText(user);
    final websiteUrl = _websiteText(user);
    return CompactProfileHero(
      displayName: _displayName.isNotEmpty ? _displayName : 'Presence',
      handle: _handle,
      title: _titleText,
      avatarUrl: _avatarUrl,
      coverUrl: _coverUrl,
      roleLabel: _roleChipLabel,
      metaChips: _buildHeroMeta(locationText, websiteUrl),
      actions: [
        PresenceHeaderAction(
          label: 'Edit profile',
          icon: Icons.edit_outlined,
          primary: true,
          onTap: () async {
            await context.push('/me/edit');
            if (!mounted) return;
            await _load();
          },
        ),
        if (_handle.isNotEmpty)
          PresenceHeaderAction(
            label: 'Public profile',
            icon: Icons.open_in_new,
            onTap: () => context.push('/u/$_handle'),
          ),
      ],
    );
  }

  Widget _tabContent(int index, bool wide) {
    switch (index) {
      case 1:
        return _authorityTab(wide);
      case 2:
        return _participationTab(wide);
      case 3:
        return _networkTab(wide);
      case 4:
        return _accountTab(wide);
      case 0:
      default:
        return _identityTab(wide);
    }
  }

  Widget _identityTab(bool wide) {
    final links = _linksFromUser(_resolvedUser);
    final left = <Widget>[
      _buildProfileSummaryCard(),
      if (links.isNotEmpty) ...[
        const SizedBox(height: AuraSpace.lg),
        MeSection(title: 'Elsewhere', children: _buildLinkItems(links)),
      ],
    ];
    final right = <Widget>[
      _buildAccountHealthPanel(),
      const SizedBox(height: AuraSpace.lg),
      _buildConnectedAccountsPanel(),
    ];
    return _twoColumn(wide, left, right);
  }

  Widget _authorityTab(bool wide) {
    final access = _institutionAccess;
    final hasWorkspace = access.hasAccess;
    final isAdmin = _isAppAdmin;
    final label = _institutionWorkspaceLabel(access);
    if (!hasWorkspace && !isAdmin) {
      return _emptyStateCard(
        icon: Icons.account_balance_outlined,
        title: 'No workspaces yet',
        body: 'Institution and platform workspaces you can act in '
            'will appear here.',
      );
    }
    return _constrainLeft(
      wide,
      _buildWorkspacesSection(hasWorkspace, isAdmin, label),
    );
  }

  Widget _participationTab(bool wide) {
    final publications = _publicationsFromUser(_resolvedUser);
    final left = <Widget>[_buildPersonalRecordSection()];
    final right = <Widget>[
      if (publications.isNotEmpty)
        MeSection(
          title: 'Public record',
          children: _buildPublicationItems(publications),
        )
      else
        _emptyStateCard(
          icon: Icons.menu_book_outlined,
          title: 'No public record yet',
          body: 'Publications and released work will be listed here.',
        ),
    ];
    return _twoColumn(wide, left, right);
  }

  Widget _networkTab(bool wide) {
    final left = <Widget>[_buildConnectionsSection()];
    final right = <Widget>[_buildAudienceCard()];
    return _twoColumn(wide, left, right);
  }

  Widget _accountTab(bool wide) {
    return _constrainLeft(wide, _buildSettingsHub());
  }

  // ─── TAB LAYOUT HELPERS ────────────────────────────────────────────────────

  Widget _twoColumn(bool wide, List<Widget> left, List<Widget> right) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...left,
          const SizedBox(height: AuraSpace.lg),
          ...right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: left,
          ),
        ),
        const SizedBox(width: AuraSpace.s20),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: right,
          ),
        ),
      ],
    );
  }

  Widget _constrainLeft(bool wide, Widget child) {
    if (!wide) return child;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }

  Widget _emptyStateCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AuraSurface.muted),
          const SizedBox(height: AuraSpace.s12),
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s6),
          Text(
            body,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceCard() {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Audience', style: AuraText.title),
          const SizedBox(height: AuraSpace.s14),
          Row(
            children: [
              Expanded(
                child: _audienceStat(
                  count: _followersCount,
                  label: 'Followers',
                  onTap: _handle.isNotEmpty
                      ? () => context.push('/u/$_handle/followers')
                      : null,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: _audienceStat(
                  count: _followingCount,
                  label: 'Following',
                  onTap: _handle.isNotEmpty
                      ? () => context.push('/u/$_handle/following')
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _audienceStat({
    required int count,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s16),
        decoration: BoxDecoration(
          color: AuraSurface.elevated,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: AuraText.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PROFILE SUMMARY (inline-editable identity fields) ─────────────────────

  Widget _buildProfileSummaryCard() {
    final user = _resolvedUser;
    final location = _locationText(user);
    final website = _websiteText(user);

    final rows = <Widget>[
      _summaryRow(label: 'Display name', value: _displayName),
      _summaryRow(label: 'Title', value: _titleText),
      _summaryRow(
        label: 'Handle',
        value: _handle.isNotEmpty ? '@$_handle' : '',
        editable: false,
      ),
      _summaryRow(label: 'Bio', value: _bio, maxLines: 4),
      _summaryRow(label: 'Location', value: location),
      _summaryRow(
        label: 'Website',
        value: website,
        onOpen: website.isNotEmpty ? () => _openExternalUrl(website) : null,
      ),
      _summaryRow(label: 'Joined', value: _joinedText, editable: false),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 16,
                color: AuraSurface.accent,
              ),
              SizedBox(width: AuraSpace.s8),
              Text('Profile summary', style: AuraText.title),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          for (var i = 0; i < rows.length; i++) ...[
            if (i != 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AuraSurface.divider,
              ),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    bool editable = true,
    int maxLines = 2,
    VoidCallback? onOpen,
  }) {
    final hasValue = value.trim().isNotEmpty;
    final valueWidget = Text(
      hasValue ? value : 'Not set',
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: AuraText.body.copyWith(
        color: hasValue ? AuraSurface.ink : AuraSurface.faint,
        fontWeight: FontWeight.w600,
        fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
        height: 1.4,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: onOpen != null && hasValue
                ? InkWell(onTap: onOpen, child: valueWidget)
                : valueWidget,
          ),
          if (editable) ...[
            const SizedBox(width: AuraSpace.s8),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(AuraSpace.s4),
              iconSize: 16,
              color: AuraSurface.muted,
              tooltip: 'Edit $label',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push('/me/edit');
                if (!mounted) return;
                await _load();
              },
            ),
          ],
        ],
      ),
    );
  }

  // Narrow vs. wide is now unified in [_buildContent]; each tab builder takes
  // a `wide` flag and collapses its two columns into one stack below 900px.

  // ─────────────────────────────────────────────────────────────────────────
  // DATA HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _institutionWorkspaceLabel(InstitutionAccess access) {
    if (!access.hasAccess) return '';

    final institution = access.institution ?? const <String, dynamic>{};
    final request = access.request ?? const <String, dynamic>{};

    final name = _firstNonEmpty([
      _value(institution['name']),
      _value(request['organizationName']),
    ]);

    switch (access.state) {
      case InstitutionAccessState.pending:
        return name.isNotEmpty ? '$name · pending' : 'Institution · pending';
      case InstitutionAccessState.verifiedMember:
        return name.isNotEmpty ? '$name · member' : 'Institution · member';
      case InstitutionAccessState.authorizedSpeaker:
        return name.isNotEmpty ? '$name · speaker' : 'Institution · speaker';
      case InstitutionAccessState.none:
        return '';
    }
  }

  List<_PresencePublication> _publicationsFromUser(
    Map<String, dynamic> user,
  ) {
    final raw = _firstNonNull([
      user['publications'],
      user['publicationRecords'],
      user['publicationItems'],
    ]);

    final list = _coerceListOfMaps(raw);
    final out = <_PresencePublication>[];

    for (final item in list) {
      final title = _firstNonEmpty([
        _value(item['title']),
        _value(item['name']),
        _value(item['label']),
      ]);
      final url = _firstNonEmpty([
        _value(item['url']),
        _value(item['link']),
        _value(item['href']),
      ]);
      final description = _firstNonEmpty([
        _value(item['description']),
        _value(item['summary']),
        _value(item['note']),
      ]);

      if (title.isEmpty && url.isEmpty && description.isEmpty) continue;

      out.add(
        _PresencePublication(
          title: title.isNotEmpty ? title : _websiteLabel(url),
          url: url,
          description: description,
        ),
      );
    }

    return out;
  }

  List<_PresenceLink> _linksFromUser(Map<String, dynamic> user) {
    final raw = _firstNonNull([
      user['links'],
      user['linkItems'],
      user['presenceLinks'],
    ]);

    final list = _coerceListOfMaps(raw);
    final out = <_PresenceLink>[];

    for (final item in list) {
      final label = _firstNonEmpty([
        _value(item['label']),
        _value(item['title']),
        _value(item['name']),
      ]);
      final url = _firstNonEmpty([
        _value(item['url']),
        _value(item['link']),
        _value(item['href']),
      ]);

      if (label.isEmpty && url.isEmpty) continue;

      out.add(
        _PresenceLink(
          label: label.isNotEmpty ? label : _websiteLabel(url),
          url: url,
        ),
      );
    }

    return out;
  }

  List<Widget> _buildPublicationItems(
    List<_PresencePublication> publications,
  ) {
    return publications
        .map(
          (publication) => MeRecordItemCard(
            icon: Icons.menu_book_outlined,
            title: publication.title.isNotEmpty
                ? publication.title
                : 'Publication',
            subtitle: publication.description,
            trailingLabel: publication.url.isNotEmpty
                ? _websiteLabel(publication.url)
                : null,
            onTap: publication.url.isNotEmpty
                ? () => _openExternalUrl(publication.url)
                : null,
          ),
        )
        .toList();
  }

  List<Widget> _buildLinkItems(List<_PresenceLink> links) {
    return links
        .map(
          (link) => MeRecordItemCard(
            icon: Icons.link_outlined,
            title: link.label.isNotEmpty ? link.label : 'Link',
            trailingLabel:
                link.url.isNotEmpty ? _websiteLabel(link.url) : null,
            onTap:
                link.url.isNotEmpty ? () => _openExternalUrl(link.url) : null,
          ),
        )
        .toList();
  }

  Future<void> _openExternalUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return;

    final normalized =
        value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value';

    final uri = Uri.tryParse(normalized);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  List<Map<String, dynamic>> _coerceListOfMaps(dynamic raw) {
    final decoded = _decodeJsonLike(raw);
    if (decoded is List) {
      return decoded
          .whereType<dynamic>()
          .map(_asMap)
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  dynamic _decodeJsonLike(dynamic raw) {
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) return null;
      try {
        return jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    return raw;
  }

  Future<Response<dynamic>> _getFirstSuccessful(
    Dio dio,
    List<String> paths, {
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastDioError;

    for (final path in paths) {
      try {
        return await dio.get(path, queryParameters: queryParameters);
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    if (lastDioError != null) throw lastDioError;
    throw DioException(
      requestOptions: RequestOptions(path: paths.isEmpty ? '' : paths.first),
      error: 'No endpoint available.',
    );
  }

  Future<Response<dynamic>> _postFirstSuccessful(
    Dio dio,
    List<String> paths, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastDioError;

    for (final path in paths) {
      try {
        return await dio.post(
          path,
          data: data,
          queryParameters: queryParameters,
        );
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    if (lastDioError != null) throw lastDioError;
    throw DioException(
      requestOptions: RequestOptions(path: paths.isEmpty ? '' : paths.first),
      error: 'No endpoint available.',
    );
  }

  Future<Response<dynamic>?> _safeGet(
    Dio dio,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.get(path, queryParameters: queryParameters);
    } catch (_) {
      return null;
    }
  }

  int _countItemsFromPayload(dynamic raw) {
    if (raw is List) return raw.length;

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      final items = map['items'];
      if (items is List) return items.length;

      final data = map['data'];
      if (data is List) return data.length;
      if (data is Map) {
        final nestedItems = data['items'];
        if (nestedItems is List) return nestedItems.length;

        final nestedData = data['data'];
        if (nestedData is List) return nestedData.length;
      }
    }

    return 0;
  }

  String _readApiError(DioException e, {required String fallback}) {
    final data = e.response?.data;

    if (data is Map) {
      final direct = data['message'];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }

      final error = data['error'];
      if (error is Map) {
        final nested = error['message'];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
    }

    final msg = e.message?.trim() ?? '';
    return msg.isNotEmpty ? msg : fallback;
  }

  Map<String, dynamic> _unwrapUser(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      final user = map['user'];
      if (user is Map) return Map<String, dynamic>.from(user);

      final data = map['data'];
      if (data is Map) {
        final nestedData = Map<String, dynamic>.from(data);
        final nestedUser = nestedData['user'];
        if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
        return nestedData;
      }

      return map;
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic>? _unwrapTikTokAccount(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);

    final account = map['account'];
    if (account is Map) {
      final out = Map<String, dynamic>.from(account);
      out['connected'] = true;
      return out;
    }

    final data = map['data'];
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);

      final nestedAccount = nested['account'];
      if (nestedAccount is Map) {
        final out = Map<String, dynamic>.from(nestedAccount);
        out['connected'] = true;
        return out;
      }

      if (nested.containsKey('connected') ||
          nested.containsKey('platformUserId')) {
        return nested;
      }
    }

    if (map.containsKey('connected') || map.containsKey('platformUserId')) {
      return map;
    }

    return null;
  }

  Map<String, dynamic>? _unwrapLinkedInAccount(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;

    final root = Map<String, dynamic>.from(raw);
    final data = _asMap(root['data']);
    final nestedData = _asMap(data['data']);

    final candidates = <Map<String, dynamic>>[
      _asMap(nestedData['account']),
      _asMap(data['account']),
      _asMap(root['account']),
      nestedData,
      data,
      root,
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;

      if (candidate.containsKey('connected') ||
          candidate.containsKey('linkedinMemberId') ||
          candidate.containsKey('memberId') ||
          candidate.containsKey('name') ||
          candidate.containsKey('email')) {
        return candidate;
      }
    }

    return null;
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String _value(dynamic v) => (v ?? '').toString().trim();

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  dynamic _firstNonNull(List<dynamic> values) {
    for (final value in values) {
      if (value != null) return value;
    }
    return null;
  }

  String _locationText(Map<String, dynamic> user) {
    final location = _firstNonEmpty([
      _value(user['location']),
      _value(user['place']),
    ]);
    if (location.isNotEmpty) return location;

    final city = _value(user['city']);
    final country = _value(user['country']);
    return [city, country].where((e) => e.isNotEmpty).join(', ');
  }

  String _websiteText(Map<String, dynamic> user) {
    return _firstNonEmpty([
      _value(user['websiteUrl']),
      _value(user['website']),
      _value(user['site']),
      _value(user['url']),
    ]);
  }

  String _websiteLabel(String website) {
    final value = website.trim();
    if (value.isEmpty) return '';

    final withScheme =
        value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value';

    final uri = Uri.tryParse(withScheme);
    final host = uri?.host.trim() ?? '';
    if (host.isEmpty) return value;

    return host.startsWith('www.') ? host.substring(4) : host;
  }

  String _resolveMediaUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;

    final baseOrigin = Uri.base.origin;
    if (value.startsWith('/')) return '$baseOrigin$value';

    return '$baseOrigin/$value';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class _PresencePublication {
  const _PresencePublication({
    required this.title,
    required this.url,
    required this.description,
  });

  final String title;
  final String url;
  final String description;
}

class _PresenceLink {
  const _PresenceLink({required this.label, required this.url});

  final String label;
  final String url;
}

class PresenceScreen extends MeScreen {
  const PresenceScreen({super.key});
}
