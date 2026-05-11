import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config.dart';
import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/media/attachment.dart';
import '../../../core/media/media_mime.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../composition/data/composition_repository.dart';
import '../../composition/domain/composition_models.dart';
import '../domain/announcement.dart';
import '../providers.dart';
import 'announcement_distribution.dart';

enum AnnouncementEditorScope {
  platform,
  institution,
}

class AnnouncementEditorScreen extends ConsumerStatefulWidget {
  const AnnouncementEditorScreen({
    super.key,
    required this.scope,
  });

  final AnnouncementEditorScope scope;

  @override
  ConsumerState<AnnouncementEditorScreen> createState() =>
      _AnnouncementEditorScreenState();
}

bool _announcementEditorHasRtlScript(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;
  final rtl = RegExp(r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
  return rtl.hasMatch(value);
}

TextDirection _announcementEditorDirectionFor(String text) {
  return _announcementEditorHasRtlScript(text) ? TextDirection.rtl : TextDirection.ltr;
}

TextAlign _announcementEditorAlignFor(String text) {
  return _announcementEditorHasRtlScript(text) ? TextAlign.right : TextAlign.left;
}

class _AnnouncementEditorScreenState
    extends ConsumerState<AnnouncementEditorScreen> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _pinNotice = false;
  bool _publishToAura = true;
  bool _publishToLinkedIn = false;
  bool _publishToTikTok = false;

  bool _submitting = false;
  String? _submitError;

  bool _reviewing = false;
  String? _reviewError;
  CompositionReviewResult? _reviewResult;
  final Set<String> _applyingSuggestionIds = <String>{};

  bool _translating = false;
  String? _translationError;
  String _targetLanguage = 'Urdu';
  _AnnouncementTranslationPreview? _translationPreview;

  bool _tiktokLoading = false;
  bool _tiktokConnected = false;
  String _tiktokAccountLabel = '';
  String? _tiktokError;

  bool _linkedinLoading = false;
  bool _linkedinConnected = false;
  String _linkedinAccountLabel = '';
  String? _linkedinError;

  final List<Attachment> _attachments = <Attachment>[];
  bool _mediaUploading = false;

  static const List<String> _targetLanguages = <String>[
    'English',
    'Urdu',
    'Arabic',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Portuguese',
    'Turkish',
    'Persian',
    'Hindi',
    'Bengali',
    'Chinese',
    'Japanese',
    'Korean',
    'Russian',
  ];

  @override
  void initState() {
    super.initState();
    _targetLanguage = _preferredTargetLanguage();
    _titleController.addListener(_handleDraftChanged);
    _summaryController.addListener(_handleDraftChanged);
    _bodyController.addListener(_handleDraftChanged);
    if (_isPlatformMode) {
      _loadExternalConnections();
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleDraftChanged);
    _summaryController.removeListener(_handleDraftChanged);
    _bodyController.removeListener(_handleDraftChanged);
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _isPlatformMode => widget.scope == AnnouncementEditorScope.platform;

  bool get _canSubmit {
    if (_submitting) return false;
    if (_titleController.text.trim().isEmpty) return false;
    if (_summaryController.text.trim().isEmpty) return false;
    if (_bodyController.text.trim().isEmpty) return false;
    if (!_isPlatformMode) return false;
    return true;
  }

  String get _pageTitle => _isPlatformMode
      ? 'Platform announcement'
      : 'Institution announcement';

  String get _introText => _isPlatformMode
      ? 'Write once. Let the system support clarity without taking over the surface.'
      // Institution publishing is shipped through the institution post path,
      // not this surface. Surfacing this from here is intentional: the
      // editor's affordances (review, translate, attachments) remain
      // available for drafting, but the Publish action lives where the
      // institution voice rules apply.
      : 'Drafting surface. To publish on behalf of an institution, use the institution’s announcement composer where official-voice rules apply.';

  TextStyle get _sectionTitleStyle =>
      AuraText.body.copyWith(fontWeight: FontWeight.w800);

  CompositionRepository _compositionRepo() {
    final token = ref.read(tokenStoreProvider).accessToken ?? '';
    return CompositionRepository(
      baseUrl: AppConfig.apiBaseUrl,
      token: token,
    );
  }

  void _handleDraftChanged() {
    if (!mounted) return;
    setState(() {
      _submitError = null;
      _reviewError = null;
      _translationError = null;
      _reviewResult = null;
      _translationPreview = null;
    });
  }

  String _trimmedOrEmpty(String text) => text.trim();

  // MIME inference + kind mapping moved to lib/core/media/media_mime.dart
  // (canonical) and lib/core/media/attachment.dart (`kindFromMime`,
  // `wireKind`). The local copies here used to drift from the backend
  // allow-list; consolidated.

  Future<void> _pickMedia() async {
    if (_submitting || _mediaUploading) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'mov', 'webm'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = <Attachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final mime = inferMimeFromFileName(file.name) ?? 'application/octet-stream';
      picked.add(
        Attachment(
          localId: '${DateTime.now().microsecondsSinceEpoch}_${file.name}_${picked.length}',
          kind: kindFromMime(mime),
          source: AttachmentSource.gallery,
          fileName: file.name,
          bytes: bytes,
          mimeType: mime,
          sizeBytes: bytes.length,
          uploading: true,
        ),
      );
    }

    if (picked.isEmpty) return;

    setState(() {
      _attachments.addAll(picked);
      _mediaUploading = true;
      _submitError = null;
    });

    for (final attachment in picked) {
      await _uploadAttachment(attachment);
    }

    if (!mounted) return;
    setState(() {
      _mediaUploading = _attachments.any((item) => item.uploading);
    });
  }

  Future<void> _uploadAttachment(Attachment attachment) async {
    try {
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: attachment.bytes ?? Uint8List(0),
        fileName: attachment.fileName ?? '',
        mimeType: attachment.mimeType ?? '',
        kind: wireKind(attachment.kind),
        source: wireSource(attachment.source),
        metadataPatch: const <String, dynamic>{
          'caption': null,
        },
      );

      if (!mounted) return;
      setState(() {
        attachment.mediaId = result.mediaId;
        attachment.url = result.url.isNotEmpty ? result.url : null;
        attachment.thumbUrl = result.thumbUrl.isNotEmpty ? result.thumbUrl : null;
        attachment.storageKey = result.storageKey.isNotEmpty ? result.storageKey : null;
        attachment.uploading = false;
        attachment.error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        attachment.error = e.toString();
      });
    }
  }

  void _removeAttachment(Attachment attachment) {
    setState(() {
      _attachments.removeWhere((item) => item.localId == attachment.localId);
      _mediaUploading = _attachments.any((item) => item.uploading);
    });
  }

  String _canonicalAnnouncementUrl(String slug) {
    final cleanSlug = slug.trim();
    if (cleanSlug.isEmpty) return '';
    return '${Uri.base.origin}/announcements/$cleanSlug';
  }

  String _buildLinkedInAnnouncementCommentary() {
    return _firstNonEmpty([
      _trimmedOrEmpty(_summaryController.text),
      _trimmedOrEmpty(_bodyController.text),
      _trimmedOrEmpty(_titleController.text),
    ]);
  }

  String _buildTikTokAnnouncementCaption() {
    final base = _firstNonEmpty([
      _trimmedOrEmpty(_titleController.text),
      _trimmedOrEmpty(_summaryController.text),
    ]);
    if (base.length <= 150) return base;
    return '${base.substring(0, 147).trim()}...';
  }

  Future<void> _publishAnnouncementToLinkedIn({
    required String announcementId,
    required String slug,
  }) async {
    final dio = ref.read(dioProvider);
    final payload = {
      'announcementId': announcementId,
      'commentary': _buildLinkedInAnnouncementCommentary(),
      'canonicalUrl': _canonicalAnnouncementUrl(slug),
    };

    final attempts = <String>[
      '/integrations/linkedin/publish/announcement',
    ];

    DioException? lastDioError;
    Object? lastError;

    for (final path in attempts) {
      try {
        await dio.post(path, data: payload);
        return;
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode != 404) rethrow;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastDioError != null) throw lastDioError;
    if (lastError != null) throw Exception(lastError.toString());
    throw Exception('LinkedIn announcement endpoint was not available.');
  }

  Future<void> _publishAnnouncementToTikTok({
    required String announcementId,
    required Announcement announcement,
  }) async {
    final dio = ref.read(dioProvider);
    final video = announcement.media.cast<Map<String, dynamic>>().firstWhere(
      (item) => (item['type'] ?? '').toString().toUpperCase().contains('VIDEO'),
      orElse: () => <String, dynamic>{},
    );

    final mediaUrl = _firstNonEmpty([
      video['url']?.toString(),
      video['displayUrl']?.toString(),
    ]);

    if (mediaUrl.isEmpty) {
      throw Exception('TikTok announcement publishing requires one uploaded video.');
    }

    final payload = {
      'announcementId': announcementId,
      'mediaUrl': mediaUrl,
      'caption': _buildTikTokAnnouncementCaption(),
      'canonicalUrl': _canonicalAnnouncementUrl(announcement.slug),
    };

    final attempts = <String>[
      '/integrations/tiktok/publish/video/announcement',
    ];

    DioException? lastDioError;
    Object? lastError;

    for (final path in attempts) {
      try {
        await dio.post(path, data: payload);
        return;
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode != 404) rethrow;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastDioError != null) throw lastDioError;
    if (lastError != null) throw Exception(lastError.toString());
    throw Exception('TikTok announcement endpoint was not available.');
  }

  void _leaveEditorAfterSuccess(String slug) {
    Future.microtask(() {
      if (!mounted) return;
      final cleanSlug = slug.trim();
      if (cleanSlug.isNotEmpty) {
        context.go('/announcements/$cleanSlug');
        return;
      }
      context.go('/announcements');
    });
  }

  Future<void> _cancelEditor() async {
    if (_submitting) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    context.go('/announcements');
  }

  String _preferredTargetLanguage() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode
        .trim()
        .toLowerCase();

    switch (code) {
      case 'ur':
        return 'Urdu';
      case 'ar':
        return 'Arabic';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      case 'tr':
        return 'Turkish';
      case 'fa':
        return 'Persian';
      case 'hi':
        return 'Hindi';
      case 'bn':
        return 'Bengali';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'ru':
        return 'Russian';
      case 'en':
      default:
        return 'English';
    }
  }

  String? _languageCodeFor(String language) {
    switch (language.trim().toLowerCase()) {
      case 'urdu':
        return 'ur';
      case 'english':
        return 'en';
      case 'arabic':
        return 'ar';
      case 'spanish':
        return 'es';
      case 'french':
        return 'fr';
      default:
        return null;
    }
  }

  String _excerptFromDraft() {
    final summary = _summaryController.text.trim();
    if (summary.isNotEmpty) {
      return summary.length <= 180
          ? summary
          : '${summary.substring(0, 180).trim()}…';
    }
    final body = _bodyController.text.trim();
    if (body.isEmpty) return '';
    return body.length <= 180 ? body : '${body.substring(0, 180).trim()}…';
  }

  String _reviewText() {
    final parts = <String>[
      _titleController.text.trim(),
      _summaryController.text.trim(),
      _bodyController.text.trim(),
    ].where((e) => e.isNotEmpty).toList();
    return parts.join('\n\n');
  }

  Future<void> _reviewAnnouncement() async {
    final text = _reviewText();
    if (text.isEmpty) return;

    setState(() {
      _reviewing = true;
      _reviewError = null;
      _reviewResult = null;
    });

    try {
      final result = await _compositionRepo().review(
        text: text,
        surface: CompositionSurface.announcement,
      );
      if (!mounted) return;
      setState(() {
        _reviewResult = CompositionReviewResult(
          sessionId: result.sessionId,
          suggestions: result.suggestions.take(2).toList(growable: false),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _reviewing = false);
      }
    }
  }

  Future<void> _applySuggestion(CompositionSuggestion suggestion) async {
    final review = _reviewResult;
    if (review == null || !suggestion.canApply) return;

    setState(() {
      _applyingSuggestionIds.add(suggestion.id);
      _reviewError = null;
    });

    try {
      final updatedText = await _compositionRepo().apply(
        sessionId: review.sessionId,
        suggestionId: suggestion.id,
        currentText: _bodyController.text,
      );

      if (!mounted) return;

      final selection = TextSelection.collapsed(
        offset: updatedText.length.clamp(0, updatedText.length),
      );

      _bodyController.value = TextEditingValue(
        text: updatedText,
        selection: selection,
        composing: TextRange.empty,
      );

      setState(() {
        _reviewResult = CompositionReviewResult(
          sessionId: review.sessionId,
          suggestions: review.suggestions
              .where((item) => item.id != suggestion.id)
              .toList(growable: false),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _applyingSuggestionIds.remove(suggestion.id);
        });
      }
    }
  }

  Future<void> _translateDraft() async {
    if (_titleController.text.trim().isEmpty &&
        _summaryController.text.trim().isEmpty &&
        _bodyController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _translating = true;
      _translationError = null;
      _translationPreview = null;
    });

    try {
      final repo = _compositionRepo();
      final title = _titleController.text.trim();
      final summary = _summaryController.text.trim();
      final body = _bodyController.text.trim();

      final translatedTitle = title.isEmpty
          ? ''
          : (await repo.translate(text: title, targetLanguage: _targetLanguage))
              .translatedText;
      final translatedSummary = summary.isEmpty
          ? ''
          : (await repo.translate(text: summary, targetLanguage: _targetLanguage))
              .translatedText;
      final translatedBody = body.isEmpty
          ? ''
          : (await repo.translate(text: body, targetLanguage: _targetLanguage))
              .translatedText;

      if (!mounted) return;
      setState(() {
        _translationPreview = _AnnouncementTranslationPreview(
          language: _targetLanguage,
          title: translatedTitle,
          summary: translatedSummary,
          body: translatedBody,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translationError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _translating = false);
      }
    }
  }

  void _applyTranslationPreview() {
    final preview = _translationPreview;
    if (preview == null) return;

    _titleController.value = TextEditingValue(
      text: preview.title,
      selection: TextSelection.collapsed(offset: preview.title.length),
    );
    _summaryController.value = TextEditingValue(
      text: preview.summary,
      selection: TextSelection.collapsed(offset: preview.summary.length),
    );
    _bodyController.value = TextEditingValue(
      text: preview.body,
      selection: TextSelection.collapsed(offset: preview.body.length),
    );

    setState(() {
      _translationPreview = null;
    });
  }

  Future<void> _submitAnnouncement() async {
    if (!_canSubmit) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      if (!_isPlatformMode) {
        // Defense-in-depth. The Publish button is gated on _isPlatformMode
        // upstream (see _canSubmit), so this branch should be unreachable
        // from the UI. Use the canonical app-error shape so any future
        // codepath that does reach here surfaces a structured message,
        // not a free-text exception leak.
        throw Exception(
          'Publish on behalf of an institution from the institution composer.',
        );
      }

      if (_publishToTikTok) {
        final hasVideo = _attachments.any((item) => item.isUploaded && !item.uploading && item.isVideo);
        if (!hasVideo) {
          throw Exception('TikTok announcement publishing requires one uploaded video.');
        }
      }

      final repo = ref.read(announcementsRepoProvider);
      final mediaIds = _attachments
          .map((item) => (item.mediaId ?? '').trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      final draft = await repo.createDraft(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        excerpt: _excerptFromDraft(),
        bodyMarkdown: _bodyController.text.trim(),
        mediaIds: mediaIds,
      );

      if (_publishToAura) {
        await repo.publish(draft.id);
      }

      if (_pinNotice) {
        await repo.pin(draft.id);
      }

      final published = await repo.getBySlug(draft.slug) ?? draft;

      final completed = <String>['Aura'];
      final failed = <String>[];

      if (_publishToLinkedIn) {
        try {
          await _publishAnnouncementToLinkedIn(
            announcementId: published.id,
            slug: published.slug,
          );
          completed.add('LinkedIn');
        } catch (e) {
          failed.add('LinkedIn ($e)');
        }
      }

      if (_publishToTikTok) {
        try {
          await _publishAnnouncementToTikTok(
            announcementId: published.id,
            announcement: published,
          );
          completed.add('TikTok');
        } catch (e) {
          failed.add('TikTok ($e)');
        }
      }

      if (!mounted) return;

      final message = failed.isEmpty
          ? 'Announcement published to ${completed.join(', ')}.'
          : 'Announcement published to ${completed.join(', ')}. ${failed.join(', ')} could not be queued.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      _leaveEditorAfterSuccess(published.slug);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = _readDioError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _loadExternalConnections() async {
    await Future.wait<void>([
      _loadTikTokConnection(),
      _loadLinkedInConnection(),
    ]);
  }

  Future<void> _loadTikTokConnection() async {
    setState(() {
      _tiktokLoading = true;
      _tiktokError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await _getFirstSuccessful(
        dio,
        const [
          '/integrations/tiktok/account',
        ],
      );
      final data = _unwrapConnectedAccount(res.data);
      if (!mounted) return;
      setState(() {
        _tiktokConnected = data['connected'] == true;
        _tiktokAccountLabel = _firstNonEmpty([
          data['displayName']?.toString(),
          data['username']?.toString(),
          data['accountLabel']?.toString(),
          data['platformUserId']?.toString(),
        ]);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tiktokConnected = false;
        _tiktokAccountLabel = '';
        _tiktokError = null;
      });
    } finally {
      if (mounted) {
        setState(() => _tiktokLoading = false);
      }
    }
  }

  Future<void> _loadLinkedInConnection() async {
    setState(() {
      _linkedinLoading = true;
      _linkedinError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await _getFirstSuccessful(
        dio,
        const [
          '/integrations/linkedin/account',
        ],
      );
      final data = _unwrapConnectedAccount(res.data);
      if (!mounted) return;
      setState(() {
        _linkedinConnected = data['connected'] == true;
        _linkedinAccountLabel = _firstNonEmpty([
          data['displayName']?.toString(),
          data['username']?.toString(),
          data['accountLabel']?.toString(),
          data['name']?.toString(),
          data['email']?.toString(),
          data['linkedinMemberId']?.toString(),
        ]);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _linkedinConnected = false;
        _linkedinAccountLabel = '';
        _linkedinError = null;
      });
    } finally {
      if (mounted) {
        setState(() => _linkedinLoading = false);
      }
    }
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
        if (e.response?.statusCode != 404) {
          rethrow;
        }
      }
    }

    if (lastDioError != null) throw lastDioError;
    throw DioException(
      requestOptions: RequestOptions(path: paths.isEmpty ? '' : paths.first),
      error: 'No endpoint available.',
    );
  }

  Map<String, dynamic> _unwrapConnectedAccount(dynamic raw) {
    final root = _asMap(raw);
    final data = _asMap(root['data']);
    final nestedData = _asMap(data['data']);

    final candidates = <Map<String, dynamic>>[
      _asMap(root['account']),
      _asMap(data['account']),
      _asMap(nestedData['account']),
      nestedData,
      data,
      root,
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      final copy = Map<String, dynamic>.from(candidate);
      final connected = copy['connected'] == true ||
          _firstNonEmpty([
            copy['displayName']?.toString(),
            copy['username']?.toString(),
            copy['name']?.toString(),
            copy['email']?.toString(),
            copy['platformUserId']?.toString(),
            copy['linkedinMemberId']?.toString(),
            copy['memberId']?.toString(),
            copy['id']?.toString(),
          ]).isNotEmpty;
      copy['connected'] = connected;
      return copy;
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final candidate = (value ?? '').trim();
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  String _readDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = _firstNonEmpty([
        data['message']?.toString(),
        data['error']?.toString(),
      ]);
      if (message.isNotEmpty) return message;
    }
    return e.message ?? 'Request failed';
  }

  Widget _buildSuggestionStrip() {
    final review = _reviewResult;
    if (_reviewing) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (_reviewError != null && _reviewError!.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          _reviewError!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    if (review == null || review.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggestions', style: _sectionTitleStyle),
          const SizedBox(height: 10),
          ...review.suggestions.map((suggestion) {
            final applying = _applyingSuggestionIds.contains(suggestion.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE6E0D8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: SizedBox.shrink(),
                    ),
                    Expanded(
                      flex: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.message,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (suggestion.replacement.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              suggestion.replacement,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5E584F),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AuraSecondaryButton(
                      label: applying ? 'Applying' : 'Apply',
                      onPressed: applying || !suggestion.canApply
                          ? null
                          : () => _applySuggestion(suggestion),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTranslationPreview() {
    final preview = _translationPreview;
    if (_translating) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (_translationError != null && _translationError!.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          _translationError!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    if (preview == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E0D8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Translation preview · ${preview.language}',
                    style: _sectionTitleStyle,
                  ),
                ),
                AuraGhostButton(
                  label: 'Dismiss',
                  onPressed: () => setState(() => _translationPreview = null),
                ),
              ],
            ),
            if (preview.title.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Directionality(
                textDirection: _announcementEditorDirectionFor(preview.title),
                child: AuraTextBlock(
                  preview.title,
                  textAlign: _announcementEditorAlignFor(preview.title),
                  languageCode: _languageCodeFor(preview.language),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (preview.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Directionality(
                textDirection: _announcementEditorDirectionFor(preview.summary),
                child: AuraTextBlock(
                  preview.summary,
                  textAlign: _announcementEditorAlignFor(preview.summary),
                  languageCode: _languageCodeFor(preview.language),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5E584F),
                  ),
                ),
              ),
            ],
            if (preview.body.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Directionality(
                textDirection: _announcementEditorDirectionFor(preview.body),
                child: AuraTextBlock(
                  preview.body,
                  textAlign: _announcementEditorAlignFor(preview.body),
                  languageCode: _languageCodeFor(preview.language),
                  style: const TextStyle(fontSize: 15, height: 1.55),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: AuraSecondaryButton(
                label: 'Apply translation',
                onPressed: _applyTranslationPreview,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final institutionAccess = ref.watch(institutionAccessProvider);

    return AuraScaffold(
      maxWidth: 980,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_pageTitle, style: AuraText.title),
            const SizedBox(height: 8),
            Text(
              _introText,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFF5E584F),
              ),
            ),
            const SizedBox(height: 20),
            AuraCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Writing', style: _sectionTitleStyle),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _titleController,
                      builder: (context, value, _) {
                        final text = value.text;
                        return Directionality(
                          textDirection: _announcementEditorDirectionFor(text),
                          child: TextField(
                            controller: _titleController,
                            textDirection: _announcementEditorDirectionFor(text),
                            textAlign: _announcementEditorAlignFor(text),
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'What needs to be said clearly?',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _summaryController,
                      builder: (context, value, _) {
                        final text = value.text;
                        return Directionality(
                          textDirection: _announcementEditorDirectionFor(text),
                          child: TextField(
                            controller: _summaryController,
                            maxLines: 3,
                            minLines: 2,
                            textDirection: _announcementEditorDirectionFor(text),
                            textAlign: _announcementEditorAlignFor(text),
                            decoration: const InputDecoration(
                              labelText: 'Summary',
                              hintText: 'Keep it brief and plain.',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _bodyController,
                      builder: (context, value, _) {
                        final text = value.text;
                        return Directionality(
                          textDirection: _announcementEditorDirectionFor(text),
                          child: TextField(
                            controller: _bodyController,
                            maxLines: 14,
                            minLines: 10,
                            textDirection: _announcementEditorDirectionFor(text),
                            textAlign: _announcementEditorAlignFor(text),
                            decoration: const InputDecoration(
                              labelText: 'Announcement body',
                              hintText: 'Write the full notice here.',
                              alignLabelWithHint: true,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildSuggestionStrip(),
                    _buildTranslationPreview(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            AuraCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Writing support', style: _sectionTitleStyle),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AuraSecondaryButton(
                          label: _reviewing ? 'Reviewing' : 'Review wording',
                          onPressed: _reviewing ? null : _reviewAnnouncement,
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            initialValue: _targetLanguage,
                            decoration: const InputDecoration(
                              labelText: 'Translate to',
                              isDense: true,
                            ),
                            items: _targetLanguages
                                .map(
                                  (language) => DropdownMenuItem<String>(
                                    value: language,
                                    child: Text(language),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _translating
                                ? null
                                : (value) {
                                    if (value == null ||
                                        value == _targetLanguage) {
                                      return;
                                    }
                                    setState(() {
                                      _targetLanguage = value;
                                      _translationPreview = null;
                                    });
                                  },
                          ),
                        ),
                        AuraSecondaryButton(
                          label: _translating ? 'Translating' : 'Preview translation',
                          onPressed: _translating ? null : _translateDraft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Review stays light. Translation previews before it changes your draft.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6358),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            AuraCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Media', style: _sectionTitleStyle),
                    const SizedBox(height: 12),
                    AuraSecondaryButton(
                      label: _mediaUploading ? 'Uploading...' : 'Add image or video',
                      icon: Icons.attach_file,
                      onPressed: (_submitting || _mediaUploading) ? null : _pickMedia,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Attach media to the announcement. TikTok announcement publishing requires one uploaded video.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6358),
                      ),
                    ),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._attachments.map(
                        (attachment) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFCF7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE6E0D8)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                attachment.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                                size: 18,
                                color: const Color(0xFF5E584F),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attachment.fileName ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      attachment.uploading
                                          ? 'Uploading...'
                                          : ((attachment.error ?? '').trim().isNotEmpty
                                              ? attachment.error!
                                              : 'Ready'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B6358),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _submitting ? null : () => _removeAttachment(attachment),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            AuraCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Distribution', style: _sectionTitleStyle),
                    const SizedBox(height: 12),
                    AnnouncementDistribution(
                      linkedinConnected: _linkedinConnected,
                      tiktokConnected: _tiktokConnected,
                      tiktokEnabled: _tiktokConnected,
                      initialAura: _publishToAura,
                      initialLinkedin: _publishToLinkedIn,
                      initialTiktok: _publishToTikTok,
                      onChanged: ({
                        required bool aura,
                        required bool linkedin,
                        required bool tiktok,
                      }) {
                        setState(() {
                          _publishToAura = aura;
                          _publishToLinkedIn = linkedin;
                          _publishToTikTok = tiktok;
                        });
                      },
                    ),
                    if (_linkedinLoading || _tiktokLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_linkedinAccountLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('LinkedIn: $_linkedinAccountLabel'),
                    ],
                    if (_tiktokAccountLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('TikTok: $_tiktokAccountLabel'),
                    ],
                    if ((_linkedinError ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _linkedinError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    if ((_tiktokError ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _tiktokError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _pinNotice,
                      onChanged: _isPlatformMode
                          ? (value) =>
                              setState(() => _pinNotice = value ?? false)
                          : null,
                      title: const Text('Pin this notice'),
                      subtitle: const Text(
                        'Keep it visible at the top after publication.',
                      ),
                    ),
                    if (!_isPlatformMode) ...[
                      const SizedBox(height: 8),
                      Text(
                        institutionAccess.when(
                          data: (value) =>
                              'Institution state: ${value.toString().split('.').last}',
                          loading: () => 'Checking institution access…',
                          error: (_, __) =>
                              'Institution access could not be read.',
                        ),
                        style: const TextStyle(color: Color(0xFF6B6358)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if ((_submitError ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _submitError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                AuraGhostButton(
                  label: 'Cancel',
                  onPressed: _submitting ? null : _cancelEditor,
                ),
                AuraPrimaryButton(
                  label: _submitting ? 'Publishing' : 'Publish announcement',
                  onPressed: _canSubmit ? _submitAnnouncement : null,
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.xl),
          ],
        ),
      ),
    );
  }
}

// _AnnouncementEditorMediaAttachment removed — migrated to canonical
// `Attachment` from lib/core/media/attachment.dart.

class _AnnouncementTranslationPreview {
  const _AnnouncementTranslationPreview({
    required this.language,
    required this.title,
    required this.summary,
    required this.body,
  });

  final String language;
  final String title;
  final String summary;
  final String body;
}
