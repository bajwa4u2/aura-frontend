import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/admin_access_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../communications_repository.dart';
import '../domain/communications_models.dart';
import '../providers.dart';

class CommunicationsCenterScreen extends ConsumerStatefulWidget {
  const CommunicationsCenterScreen({super.key});

  @override
  ConsumerState<CommunicationsCenterScreen> createState() =>
      _CommunicationsCenterScreenState();
}

class _CommunicationsCenterScreenState
    extends ConsumerState<CommunicationsCenterScreen> {
  CommunicationPreferences? _preferences;
  bool _loading = true;
  String? _error;

  final Set<String> _savingKeys = <String>{};
  CommunicationFrequencyOption _digestFrequency =
      CommunicationFrequencyOption.dailyDigest;
  DigestPreviewResult? _digestPreview;
  bool _digestBusy = false;
  String? _digestError;

  final _newsletterSubjectCtrl = TextEditingController(
    text: 'Aura update',
  );
  final _newsletterHeadlineCtrl = TextEditingController(
    text: 'What is new in Aura',
  );
  final _newsletterBodyCtrl = TextEditingController(
    text: 'A short update on the latest product improvements.',
  );
  final _newsletterCtaLabelCtrl = TextEditingController(text: 'Open Aura');
  final _newsletterCtaUrlCtrl = TextEditingController(
    text: 'https://auraplatform.org',
  );
  final _newsletterToCtrl = TextEditingController();
  CommunicationRenderPreview? _newsletterPreview;
  NewsletterTestResult? _newsletterTestResult;
  bool _newsletterBusy = false;
  String? _newsletterError;

  final _aiDraftTypeCtrl = TextEditingController(text: 'support_reply');
  final _aiCategoryCtrl = TextEditingController(text: 'support');
  final _aiAudienceCtrl = TextEditingController(text: 'member');
  final _aiGoalCtrl = TextEditingController(
    text: 'Reply to the member clearly and kindly.',
  );
  final _aiSourceCtrl = TextEditingController(
    text: 'The member asked for help with account access.',
  );
  CommunicationDraftResult? _aiDraftResult;
  bool _aiBusy = false;
  String? _aiError;

  final _campaignNameCtrl = TextEditingController(
    text: 'April product update',
  );
  final _campaignCategoryCtrl = TextEditingController(text: 'newsletter');
  final _campaignAudienceKindCtrl = TextEditingController(text: 'manual');
  final _campaignSubjectCtrl = TextEditingController(text: 'Aura update');
  final _campaignBodyCtrl = TextEditingController(
    text: 'Draft body for the approved communication.',
  );
  final _campaignCtaLabelCtrl = TextEditingController(text: 'Open Aura');
  final _campaignCtaUrlCtrl = TextEditingController(
    text: 'https://auraplatform.org',
  );
  final _campaignToCtrl = TextEditingController();
  final _campaignDraftIdCtrl = TextEditingController();
  CampaignCreationResult? _campaignCreationResult;
  CommunicationRenderPreview? _campaignPreview;
  CampaignActionResult? _campaignApproveResult;
  CampaignQueueResult? _campaignTestResult;
  bool _campaignBusy = false;
  String? _campaignError;

  CommunicationsRepository get _repo =>
      ref.read(communicationsRepositoryProvider);

  bool get _isAdmin => ref.watch(appAdminAccessProvider).maybeWhen(
        data: (value) => value.isAdmin,
        orElse: () => false,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _newsletterSubjectCtrl.dispose();
    _newsletterHeadlineCtrl.dispose();
    _newsletterBodyCtrl.dispose();
    _newsletterCtaLabelCtrl.dispose();
    _newsletterCtaUrlCtrl.dispose();
    _newsletterToCtrl.dispose();
    _aiDraftTypeCtrl.dispose();
    _aiCategoryCtrl.dispose();
    _aiAudienceCtrl.dispose();
    _aiGoalCtrl.dispose();
    _aiSourceCtrl.dispose();
    _campaignNameCtrl.dispose();
    _campaignCategoryCtrl.dispose();
    _campaignAudienceKindCtrl.dispose();
    _campaignSubjectCtrl.dispose();
    _campaignBodyCtrl.dispose();
    _campaignCtaLabelCtrl.dispose();
    _campaignCtaUrlCtrl.dispose();
    _campaignToCtrl.dispose();
    _campaignDraftIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final prefs = await _repo.loadPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _digestFrequency = prefs.group('digest')?.frequency ??
            CommunicationFrequencyOption.dailyDigest;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _savePreferencePatch(Map<String, dynamic> patch) async {
    final keys = patch.keys.map((e) => e.toString()).toList(growable: false);
    if (mounted) {
      setState(() {
        for (final key in keys) {
          _savingKeys.add(key);
        }
      });
    }

    try {
      final saved = await _repo.savePreferences(patch);
      if (!mounted) return;
      setState(() {
        _preferences = saved;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update communication settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          for (final key in keys) {
            _savingKeys.remove(key);
          }
        });
      }
    }
  }

  String _channelFieldFor(String key) {
    switch (key) {
      case 'securityAuth':
        return 'securityChannel';
      default:
        return '${key}Channel';
    }
  }

  String _frequencyFieldFor(String key) {
    switch (key) {
      case 'securityAuth':
        return 'securityFrequency';
      default:
        return '${key}Frequency';
    }
  }

  Future<void> _previewDigest() async {
    if (_digestBusy) return;
    setState(() {
      _digestBusy = true;
      _digestError = null;
    });

    try {
      final preview = await _repo.previewDigest(frequency: _digestFrequency);
      if (!mounted) return;
      setState(() {
        _digestPreview = preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _digestError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _digestBusy = false;
        });
      }
    }
  }

  Future<void> _createDigest() async {
    if (_digestBusy) return;
    setState(() {
      _digestBusy = true;
      _digestError = null;
    });

    try {
      await _repo.createDigest(frequency: _digestFrequency);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_digestFrequency.label} digest created or refreshed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _digestError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _digestBusy = false;
        });
      }
    }
  }

  Future<void> _previewNewsletter() async {
    if (_newsletterBusy) return;
    setState(() {
      _newsletterBusy = true;
      _newsletterError = null;
    });

    try {
      final preview = await _repo.previewNewsletter(
        subject: _newsletterSubjectCtrl.text.trim(),
        headline: _newsletterHeadlineCtrl.text.trim(),
        body: _newsletterBodyCtrl.text.trim(),
        ctaLabel: _newsletterCtaLabelCtrl.text.trim(),
        ctaUrl: _newsletterCtaUrlCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _newsletterPreview = preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _newsletterError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _newsletterBusy = false;
        });
      }
    }
  }

  Future<void> _testNewsletter() async {
    if (_newsletterBusy) return;
    final to = _newsletterToCtrl.text.trim();
    if (to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a recipient email first.')),
      );
      return;
    }

    setState(() {
      _newsletterBusy = true;
      _newsletterError = null;
    });

    try {
      final result = await _repo.testNewsletter(
        to: to,
        subject: _newsletterSubjectCtrl.text.trim(),
        headline: _newsletterHeadlineCtrl.text.trim(),
        body: _newsletterBodyCtrl.text.trim(),
        ctaLabel: _newsletterCtaLabelCtrl.text.trim(),
        ctaUrl: _newsletterCtaUrlCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _newsletterTestResult = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.skipped
                ? 'Newsletter test was suppressed.'
                : 'Newsletter test queued.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _newsletterError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _newsletterBusy = false;
        });
      }
    }
  }

  Future<void> _createAiDraft() async {
    if (_aiBusy) return;
    setState(() {
      _aiBusy = true;
      _aiError = null;
    });

    try {
      final draft = await _repo.createAiDraft(
        draftType: _aiDraftTypeCtrl.text.trim(),
        category: _aiCategoryCtrl.text.trim(),
        audience: _aiAudienceCtrl.text.trim(),
        goal: _aiGoalCtrl.text.trim(),
        sourceText: _aiSourceCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _aiDraftResult = draft;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _aiBusy = false;
        });
      }
    }
  }

  Future<void> _createCampaign() async {
    if (_campaignBusy) return;
    setState(() {
      _campaignBusy = true;
      _campaignError = null;
    });

    try {
      final result = await _repo.createCampaign(
        name: _campaignNameCtrl.text.trim(),
        category: _campaignCategoryCtrl.text.trim(),
        audienceKind: _campaignAudienceKindCtrl.text.trim(),
        subject: _campaignSubjectCtrl.text.trim(),
        bodyText: _campaignBodyCtrl.text.trim(),
        ctaLabel: _campaignCtaLabelCtrl.text.trim(),
        ctaUrl: _campaignCtaUrlCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _campaignCreationResult = result;
        _campaignDraftIdCtrl.text = result.draftId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _campaignError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _campaignBusy = false;
        });
      }
    }
  }

  Future<void> _previewCampaign() async {
    final draftId = _campaignDraftIdCtrl.text.trim();
    if (draftId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or enter a draft id first.')),
      );
      return;
    }
    if (_campaignBusy) return;

    setState(() {
      _campaignBusy = true;
      _campaignError = null;
    });

    try {
      final preview = await _repo.previewCampaignDraft(draftId);
      if (!mounted) return;
      setState(() {
        _campaignPreview = preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _campaignError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _campaignBusy = false;
        });
      }
    }
  }

  Future<void> _approveCampaign() async {
    final draftId = _campaignDraftIdCtrl.text.trim();
    if (draftId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or enter a draft id first.')),
      );
      return;
    }
    if (_campaignBusy) return;

    setState(() {
      _campaignBusy = true;
      _campaignError = null;
    });

    try {
      final result = await _repo.approveCampaignDraft(draftId);
      if (!mounted) return;
      setState(() {
        _campaignApproveResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _campaignError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _campaignBusy = false;
        });
      }
    }
  }

  Future<void> _testCampaign() async {
    final draftId = _campaignDraftIdCtrl.text.trim();
    final to = _campaignToCtrl.text.trim();
    if (draftId.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a draft id and recipient email first.'),
        ),
      );
      return;
    }
    if (_campaignBusy) return;

    setState(() {
      _campaignBusy = true;
      _campaignError = null;
    });

    try {
      final result = await _repo.testCampaignDraft(draftId: draftId, to: to);
      if (!mounted) return;
      setState(() {
        _campaignTestResult = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.skipped
                ? 'Campaign test was skipped.'
                : 'Campaign test queued.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _campaignError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _campaignBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminAsync = ref.watch(appAdminAccessProvider);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        color: AuraSurface.accent,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuraGradientHeader(
                      title: 'Communication center',
                      subtitle:
                          'Control how Aura reaches people, preview digests, and prepare communications without sending anything by accident.',
                    ),
                    const SizedBox(height: AuraSpace.s16),
                    Wrap(
                      spacing: AuraSpace.s12,
                      runSpacing: AuraSpace.s12,
                      children: [
                        _buildMetric(
                          label: 'In-app',
                          value: _preferences?.inAppEnabled == true
                              ? 'On'
                              : 'Off',
                          subtext: 'Primary signal',
                        ),
                        _buildMetric(
                          label: 'Email',
                          value: _preferences?.emailEnabled == true
                              ? 'On'
                              : 'Off',
                          subtext: 'Reserved and digest driven',
                        ),
                        _buildMetric(
                          label: 'Digest',
                          value: _digestFrequency.label,
                          subtext: 'Preview before creating',
                        ),
                        _buildMetric(
                          label: 'Admin tools',
                          value: _isAdmin ? 'Available' : 'Hidden',
                          subtext: 'Protected communication workspace',
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s16),
                    if (_loading)
                      const Center(
                        child: AuraLoadingState(
                          message: 'Loading communication settings…',
                        ),
                      )
                    else if (_error != null)
                      AuraErrorState(
                        title: 'Could not load communication settings',
                        body: _error!,
                        action: AuraSecondaryButton(
                          label: 'Try again',
                          onPressed: _load,
                          icon: Icons.refresh_rounded,
                        ),
                      )
                    else ...[
                      _buildPolicyCard(),
                      const SizedBox(height: AuraSpace.s16),
                      _buildPreferenceGroups(),
                      const SizedBox(height: AuraSpace.s16),
                      _buildDigestCard(),
                      const SizedBox(height: AuraSpace.s16),
                      _buildSupportCard(),
                      if (_isAdmin) ...[
                        const SizedBox(height: AuraSpace.s16),
                        _buildNewsletterCard(),
                        const SizedBox(height: AuraSpace.s16),
                        _buildAiDraftCard(),
                        const SizedBox(height: AuraSpace.s16),
                        _buildCampaignCard(),
                      ] else if (adminAsync.maybeWhen(
                        data: (value) => value.isAdmin,
                        orElse: () => false,
                      )) ...[
                        const SizedBox(height: AuraSpace.s16),
                        const AuraLoadingState(
                          message: 'Loading protected communication tools…',
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required String subtext,
  }) {
    return SizedBox(
      width: 230,
      child: AuraMetricCard(
        label: label,
        value: value,
        subtext: subtext,
      ),
    );
  }

  Widget _buildPolicyCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery posture', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'In-app is the primary channel. Email is reserved for important, digest, support, and security communication.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraBadge(
                label: _preferences?.inAppEnabled == true
                    ? 'In-app enabled'
                    : 'In-app disabled',
                icon: Icons.chat_bubble_outline,
              ),
              AuraBadge(
                label: _preferences?.emailEnabled == true
                    ? 'Email enabled'
                    : 'Email disabled',
                icon: Icons.mail_outline,
              ),
              const AuraBadge(
                label: 'Transactional support/security stay visible',
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: 'Open member preferences',
                onPressed: () => context.go('/me/settings/communications'),
                icon: Icons.tune_rounded,
              ),
              AuraSecondaryButton(
                label: 'Open admin workspace',
                onPressed: _isAdmin ? () => context.go('/admin') : null,
                icon: Icons.admin_panel_settings_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceGroups() {
    final prefs = _preferences;
    if (prefs == null) {
      return const SizedBox.shrink();
    }

    const order = <String>[
      'social',
      'messages',
      'institutions',
      'announcements',
      'securityAuth',
      'support',
      'productUpdates',
      'newsletter',
      'digest',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuraSectionHeader(
          title: 'Preferences',
          subtitle:
              'Choose where each category lands and how often it should arrive.',
        ),
        const SizedBox(height: AuraSpace.s12),
        ...order.map((key) {
          final group = prefs.group(key);
          if (group == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s12),
            child: _PreferenceGroupCard(
              group: group,
              saving: _savingKeys.contains(_channelFieldFor(key)) ||
                  _savingKeys.contains(_frequencyFieldFor(key)),
              onChannelChanged: (next) => _savePreferencePatch({
                _channelFieldFor(key): next.value,
              }),
              onFrequencyChanged: (next) => _savePreferencePatch({
                _frequencyFieldFor(key): next.value,
              }),
            ),
          );
        }),
        const SizedBox(height: AuraSpace.s8),
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Legacy email controls', style: AuraText.subtitle),
              const SizedBox(height: AuraSpace.s8),
              const Text(
                'These remain supported while Aura transitions to the newer channel/frequency model.',
                style: AuraText.body,
              ),
              const SizedBox(height: AuraSpace.s12),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: [
                  _LegacyToggle(
                    label: 'Messages',
                    value: prefs.legacy('emailMessageReceived'),
                    busy: _savingKeys.contains('emailMessageReceived'),
                    onChanged: (next) => _savePreferencePatch({
                      'emailMessageReceived': next,
                    }),
                  ),
                  _LegacyToggle(
                    label: 'Invites',
                    value: prefs.legacy('emailInviteReceived'),
                    busy: _savingKeys.contains('emailInviteReceived'),
                    onChanged: (next) => _savePreferencePatch({
                      'emailInviteReceived': next,
                    }),
                  ),
                  _LegacyToggle(
                    label: 'Invite responses',
                    value: prefs.legacy('emailInviteResponded'),
                    busy: _savingKeys.contains('emailInviteResponded'),
                    onChanged: (next) => _savePreferencePatch({
                      'emailInviteResponded': next,
                    }),
                  ),
                  _LegacyToggle(
                    label: 'Announcements',
                    value: prefs.legacy('emailAnnouncementPublished'),
                    busy: _savingKeys.contains('emailAnnouncementPublished'),
                    onChanged: (next) => _savePreferencePatch({
                      'emailAnnouncementPublished': next,
                    }),
                  ),
                  _LegacyToggle(
                    label: 'System',
                    value: prefs.legacy('emailSystem'),
                    busy: _savingKeys.contains('emailSystem'),
                    onChanged: (next) => _savePreferencePatch({
                      'emailSystem': next,
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDigestCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Digest controls', style: AuraText.subtitle),
              ),
              AuraStatusChip(
                label: _digestFrequency.label,
                backgroundColor: AuraSurface.accentSoft,
                textColor: AuraSurface.accentText,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Preview what a daily or weekly summary would look like before creating the record.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _digestFrequency.value,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(
                      value: 'DAILY_DIGEST',
                      child: Text('Daily digest'),
                    ),
                    DropdownMenuItem(
                      value: 'WEEKLY_DIGEST',
                      child: Text('Weekly digest'),
                    ),
                  ],
                  onChanged: _digestBusy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _digestFrequency =
                                communicationFrequencyOptionFromRaw(value);
                            _digestPreview = null;
                          });
                        },
                ),
              ),
              AuraPrimaryButton(
                label: _digestBusy ? 'Working…' : 'Preview digest',
                onPressed: _digestBusy ? null : _previewDigest,
                icon: Icons.visibility_outlined,
              ),
              AuraSecondaryButton(
                label: _digestBusy ? 'Working…' : 'Create digest',
                onPressed: _digestBusy ? null : _createDigest,
                icon: Icons.add_circle_outline,
              ),
            ],
          ),
          if (_digestError != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraErrorState(
              title: 'Digest action failed',
              body: _digestError!,
            ),
          ],
          const SizedBox(height: AuraSpace.s12),
          if (_digestPreview == null)
            const AuraEmptyState(
              title: 'No preview yet',
              body: 'Choose a digest frequency and preview it here.',
              icon: Icons.inbox_outlined,
            )
          else
            AuraCard(
              borderColor: AuraSurface.divider,
              color: AuraSurface.subtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _digestPreview!.subject,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s6),
                  Text(_digestPreview!.previewText, style: AuraText.muted),
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      AuraStatusChip(
                        label: '${_digestPreview!.itemCount} items',
                        backgroundColor: AuraSurface.accentSoft,
                        textColor: AuraSurface.accentText,
                      ),
                      AuraStatusChip(
                        label: _digestPreview!.frequency,
                        backgroundColor: AuraSurface.card,
                        textColor: AuraSurface.ink,
                      ),
                    ],
                  ),
                  if (_digestPreview!.items.isEmpty) ...[
                    const SizedBox(height: AuraSpace.s12),
                    const Text(
                      'No eligible items were available for this digest preview.',
                      style: AuraText.body,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Support and contact', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Support acknowledgements remain transactional. The public contact form already preserves its success state and confirmation behavior.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraSecondaryButton(
            label: 'Open contact',
            onPressed: () => context.go('/contact'),
            icon: Icons.mail_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildNewsletterCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Newsletter preview and test send',
                  style: AuraText.subtitle,
                ),
              ),
              AuraStatusChip(
                label: 'Admin only',
                backgroundColor: AuraSurface.warnBg,
                textColor: AuraSurface.warnInk,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Render the newsletter before queueing a test send. Normal members never see this surface.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          _twoColumnFields([
            AuraInput(
              controller: _newsletterSubjectCtrl,
              label: 'Subject',
            ),
            AuraInput(
              controller: _newsletterHeadlineCtrl,
              label: 'Headline',
            ),
            AuraInput(
              controller: _newsletterCtaLabelCtrl,
              label: 'CTA label',
            ),
            AuraInput(
              controller: _newsletterCtaUrlCtrl,
              label: 'CTA URL',
            ),
          ]),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _newsletterBodyCtrl,
            label: 'Body',
            maxLines: 6,
            minLines: 4,
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _newsletterToCtrl,
            label: 'Test recipient email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: _newsletterBusy ? 'Working…' : 'Preview newsletter',
                onPressed: _newsletterBusy ? null : _previewNewsletter,
                icon: Icons.visibility_outlined,
              ),
              AuraSecondaryButton(
                label: _newsletterBusy ? 'Working…' : 'Test send',
                onPressed: _newsletterBusy ? null : _testNewsletter,
                icon: Icons.send_outlined,
              ),
            ],
          ),
          if (_newsletterError != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraErrorState(
              title: 'Newsletter action failed',
              body: _newsletterError!,
            ),
          ],
          if (_newsletterTestResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            _resultCard(
              title: _newsletterTestResult!.skipped
                  ? 'Test send suppressed'
                  : 'Test send queued',
              body: _newsletterTestResult!.skipped
                  ? _newsletterTestResult!.reason.isNotEmpty
                      ? _newsletterTestResult!.reason
                      : 'The backend suppressed this test send.'
                  : 'Outbox ${_newsletterTestResult!.outboxId}',
              chipLabel: _newsletterTestResult!.queued
                  ? 'Queued'
                  : (_newsletterTestResult!.skipped ? 'Skipped' : 'Ok'),
            ),
          ],
          if (_newsletterPreview != null) ...[
            const SizedBox(height: AuraSpace.s12),
            _previewPanel(
              title: _newsletterPreview!.subject,
              previewText: _newsletterPreview!.previewText,
              text: _newsletterPreview!.text,
              html: _newsletterPreview!.html,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiDraftCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('AI draft only', style: AuraText.subtitle),
              ),
              AuraStatusChip(
                label: 'Draft only',
                backgroundColor: AuraSurface.infoBg,
                textColor: AuraSurface.infoInk,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Create a communication draft with AI, then review it before any campaign work begins.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          _twoColumnFields([
            AuraInput(controller: _aiDraftTypeCtrl, label: 'Draft type'),
            AuraInput(controller: _aiCategoryCtrl, label: 'Category'),
            AuraInput(controller: _aiAudienceCtrl, label: 'Audience'),
            AuraInput(controller: _aiGoalCtrl, label: 'Goal'),
          ]),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _aiSourceCtrl,
            label: 'Source text',
            maxLines: 6,
            minLines: 4,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: _aiBusy ? 'Working…' : 'Create AI draft',
                onPressed: _aiBusy ? null : _createAiDraft,
                icon: Icons.auto_awesome_outlined,
              ),
            ],
          ),
          if (_aiError != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraErrorState(title: 'AI draft failed', body: _aiError!),
          ],
          if (_aiDraftResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            _resultCard(
              title: _aiDraftResult!.subject.isNotEmpty
                  ? _aiDraftResult!.subject
                  : 'AI draft created',
              body:
                  'Status: ${_aiDraftResult!.status} · ${_aiDraftResult!.sendStatus.isNotEmpty ? _aiDraftResult!.sendStatus : 'NOT_SENT'}',
              chipLabel: _aiDraftResult!.source.isNotEmpty
                  ? _aiDraftResult!.source
                  : 'AI',
            ),
            const SizedBox(height: AuraSpace.s12),
            AuraCard(
              borderColor: AuraSurface.divider,
              color: AuraSurface.subtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Draft body preview', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    _aiDraftResult!.bodyText.isNotEmpty
                        ? _aiDraftResult!.bodyText
                        : 'No body returned.',
                    style: AuraText.muted,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCampaignCard() {
    final draftId = _campaignDraftIdCtrl.text.trim();
    final approved = _campaignApproveResult?.status.toUpperCase() == 'APPROVED';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Campaign draft workflow',
                  style: AuraText.subtitle,
                ),
              ),
              AuraStatusChip(
                label: approved ? 'Approved' : 'Draft',
                backgroundColor: approved
                    ? AuraSurface.goodBg
                    : AuraSurface.subtle,
                textColor: approved
                    ? AuraSurface.goodInk
                    : AuraSurface.muted,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Create a draft, preview it, approve it explicitly, and only then run a test send.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          _twoColumnFields([
            AuraInput(controller: _campaignNameCtrl, label: 'Name'),
            AuraInput(controller: _campaignCategoryCtrl, label: 'Category'),
            AuraInput(
              controller: _campaignAudienceKindCtrl,
              label: 'Audience kind',
            ),
            AuraInput(controller: _campaignSubjectCtrl, label: 'Subject'),
          ]),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _campaignBodyCtrl,
            label: 'Body text',
            maxLines: 6,
            minLines: 4,
          ),
          const SizedBox(height: AuraSpace.s12),
          _twoColumnFields([
            AuraInput(controller: _campaignCtaLabelCtrl, label: 'CTA label'),
            AuraInput(controller: _campaignCtaUrlCtrl, label: 'CTA URL'),
            AuraInput(controller: _campaignDraftIdCtrl, label: 'Draft id'),
            AuraInput(
              controller: _campaignToCtrl,
              label: 'Test recipient email',
            ),
          ]),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: _campaignBusy ? 'Working…' : 'Create campaign',
                onPressed: _campaignBusy ? null : _createCampaign,
                icon: Icons.add_circle_outline,
              ),
              AuraSecondaryButton(
                label: _campaignBusy ? 'Working…' : 'Preview',
                onPressed: _campaignBusy ? null : _previewCampaign,
                icon: Icons.visibility_outlined,
              ),
              AuraSecondaryButton(
                label: _campaignBusy ? 'Working…' : 'Approve',
                onPressed: _campaignBusy ? null : _approveCampaign,
                icon: Icons.verified_outlined,
              ),
              AuraGhostButton(
                label: _campaignBusy ? 'Working…' : 'Test send',
                onPressed: _campaignBusy ? null : _testCampaign,
                icon: Icons.send_outlined,
              ),
            ],
          ),
          if (_campaignError != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraErrorState(title: 'Campaign action failed', body: _campaignError!),
          ],
          if (_campaignCreationResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            _resultCard(
              title: 'Campaign created',
              body:
                  'Campaign ${_campaignCreationResult!.campaignId} · Draft ${_campaignCreationResult!.draftId}',
              chipLabel:
                  '${_campaignCreationResult!.campaignStatus} / ${_campaignCreationResult!.draftStatus}',
            ),
          ],
          if (_campaignApproveResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            _resultCard(
              title: 'Campaign approval',
              body: 'Status: ${_campaignApproveResult!.status}',
              chipLabel: _campaignApproveResult!.status,
            ),
          ],
          if (_campaignTestResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            _resultCard(
              title: _campaignTestResult!.skipped
                  ? 'Campaign test skipped'
                  : 'Campaign test queued',
              body: _campaignTestResult!.skipped
                  ? (_campaignTestResult!.reason.isNotEmpty
                      ? _campaignTestResult!.reason
                      : 'The backend skipped this test send.')
                  : 'Outbox ${_campaignTestResult!.outboxId}',
              chipLabel: _campaignTestResult!.queued
                  ? 'Queued'
                  : (_campaignTestResult!.skipped ? 'Skipped' : 'Ok'),
            ),
          ],
          if (_campaignPreview != null) ...[
            const SizedBox(height: AuraSpace.s12),
            _previewPanel(
              title: _campaignPreview!.subject,
              previewText: _campaignPreview!.previewText,
              text: _campaignPreview!.text,
              html: _campaignPreview!.html,
            ),
          ],
          if (draftId.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              approved
                  ? 'Draft $draftId is approved and can be tested.'
                  : 'Draft $draftId is not approved yet. Approve it before test sends.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _twoColumnFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final children = <Widget>[];
        if (wide) {
          for (var i = 0; i < fields.length; i += 2) {
            children.add(
              Row(
                children: [
                  Expanded(child: fields[i]),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: i + 1 < fields.length
                        ? fields[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
            if (i + 2 < fields.length) {
              children.add(const SizedBox(height: AuraSpace.s12));
            }
          }
        } else {
          for (var i = 0; i < fields.length; i++) {
            children.add(fields[i]);
            if (i != fields.length - 1) {
              children.add(const SizedBox(height: AuraSpace.s12));
            }
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  Widget _resultCard({
    required String title,
    required String body,
    required String chipLabel,
  }) {
    return AuraCard(
      borderColor: AuraSurface.divider,
      color: AuraSurface.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
              ),
              AuraStatusChip(
                label: chipLabel,
                backgroundColor: AuraSurface.card,
                textColor: AuraSurface.ink,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(body, style: AuraText.muted),
        ],
      ),
    );
  }

  Widget _previewPanel({
    required String title,
    required String previewText,
    required String text,
    required String html,
  }) {
    final htmlSummary = html.trim().isEmpty
        ? 'No HTML returned.'
        : html.trim().length <= 320
            ? html.trim()
            : '${html.trim().substring(0, 320)}…';

    return AuraCard(
      borderColor: AuraSurface.divider,
      color: AuraSurface.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AuraSpace.s6),
          Text(previewText, style: AuraText.muted),
          const SizedBox(height: AuraSpace.s12),
          const Text('Text preview', style: AuraText.label),
          const SizedBox(height: AuraSpace.s4),
          Text(text.isEmpty ? 'No text returned.' : text, style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),
          const Text('HTML summary', style: AuraText.label),
          const SizedBox(height: AuraSpace.s4),
          Text(htmlSummary, style: AuraText.small),
        ],
      ),
    );
  }
}

class _PreferenceGroupCard extends StatelessWidget {
  const _PreferenceGroupCard({
    required this.group,
    required this.saving,
    required this.onChannelChanged,
    required this.onFrequencyChanged,
  });

  final CommunicationPreferenceGroup group;
  final bool saving;
  final ValueChanged<CommunicationChannelOption> onChannelChanged;
  final ValueChanged<CommunicationFrequencyOption> onFrequencyChanged;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.title,
                            style: AuraText.subtitle,
                          ),
                        ),
                        if (group.protected) ...[
                          const SizedBox(width: AuraSpace.s8),
                          const AuraStatusChip(
                            label: 'Transactional',
                            backgroundColor: AuraSurface.infoBg,
                            textColor: AuraSurface.infoInk,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    Text(group.subtitle, style: AuraText.muted),
                  ],
                ),
              ),
              if (saving) ...[
                const SizedBox(width: AuraSpace.s10),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final channelField = _DropdownField<CommunicationChannelOption>(
                label: 'Channel',
                value: group.channel,
                items: CommunicationChannelOption.values
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        onChannelChanged(value);
                      },
              );
              final frequencyField =
                  _DropdownField<CommunicationFrequencyOption>(
                label: 'Frequency',
                value: group.frequency,
                items: CommunicationFrequencyOption.values
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        onFrequencyChanged(value);
                      },
              );

              if (wide) {
                return Row(
                  children: [
                    Expanded(child: channelField),
                    const SizedBox(width: AuraSpace.s12),
                    Expanded(child: frequencyField),
                  ],
                );
              }

              return Column(
                children: [
                  channelField,
                  const SizedBox(height: AuraSpace.s12),
                  frequencyField,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _LegacyToggle extends StatelessWidget {
  const _LegacyToggle({
    required this.label,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s8,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AuraText.small),
          const SizedBox(width: AuraSpace.s10),
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}
