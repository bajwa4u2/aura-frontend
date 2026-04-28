import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'support_models.dart';
import 'support_repository.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(dioProvider));
});

// Active conversation state

class SupportConversationState {
  final bool loading;
  final bool sending;
  final String? conversationId;
  final String? sessionToken;
  final String? caseRef;
  final List<SupportMessage> messages;
  final String? error;

  const SupportConversationState({
    this.loading = false,
    this.sending = false,
    this.conversationId,
    this.sessionToken,
    this.caseRef,
    this.messages = const [],
    this.error,
  });

  SupportConversationState copyWith({
    bool? loading,
    bool? sending,
    String? conversationId,
    String? sessionToken,
    String? caseRef,
    List<SupportMessage>? messages,
    String? error,
    bool clearError = false,
  }) {
    return SupportConversationState(
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      conversationId: conversationId ?? this.conversationId,
      sessionToken: sessionToken ?? this.sessionToken,
      caseRef: caseRef ?? this.caseRef,
      messages: messages ?? this.messages,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SupportConversationNotifier extends StateNotifier<SupportConversationState> {
  SupportConversationNotifier(this._repo) : super(const SupportConversationState());

  final SupportRepository _repo;

  Future<void> start({String source = 'PUBLIC', String? institutionId}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final conv = await _repo.startConversation(source: source, institutionId: institutionId);
      state = state.copyWith(
        loading: false,
        conversationId: conv.conversationId,
        sessionToken: conv.sessionToken,
        caseRef: conv.caseRef,
        messages: conv.messages,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> send(String content) async {
    final conversationId = state.conversationId;
    if (conversationId == null || state.sending) return;

    state = state.copyWith(sending: true, clearError: true);
    try {
      final messages = await _repo.sendMessage(
        conversationId: conversationId,
        content: content,
        sessionToken: state.sessionToken,
      );
      state = state.copyWith(sending: false, messages: messages);
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
    }
  }

  Future<SupportEscalateResult?> escalate({
    String? requesterEmail,
    String? requesterName,
  }) async {
    final conversationId = state.conversationId;
    if (conversationId == null) return null;
    try {
      final result = await _repo.escalate(
        conversationId: conversationId,
        sessionToken: state.sessionToken,
        requesterEmail: requesterEmail,
        requesterName: requesterName,
      );
      state = state.copyWith(caseRef: result.caseRef);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  void reset() {
    state = const SupportConversationState();
  }
}

final supportConversationProvider =
    StateNotifierProvider.autoDispose<SupportConversationNotifier, SupportConversationState>(
  (ref) => SupportConversationNotifier(ref.watch(supportRepositoryProvider)),
);

// Admin cases list

class AdminSupportCasesState {
  final bool loading;
  final List<SupportCaseSummary> cases;
  final int total;
  final String? statusFilter;
  final String? categoryFilter;
  final String? search;
  final String? error;

  const AdminSupportCasesState({
    this.loading = false,
    this.cases = const [],
    this.total = 0,
    this.statusFilter,
    this.categoryFilter,
    this.search,
    this.error,
  });

  AdminSupportCasesState copyWith({
    bool? loading,
    List<SupportCaseSummary>? cases,
    int? total,
    String? statusFilter,
    String? categoryFilter,
    String? search,
    String? error,
    bool clearError = false,
    bool clearFilters = false,
  }) {
    return AdminSupportCasesState(
      loading: loading ?? this.loading,
      cases: cases ?? this.cases,
      total: total ?? this.total,
      statusFilter: clearFilters ? null : (statusFilter ?? this.statusFilter),
      categoryFilter: clearFilters ? null : (categoryFilter ?? this.categoryFilter),
      search: clearFilters ? null : (search ?? this.search),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AdminSupportCasesNotifier extends StateNotifier<AdminSupportCasesState> {
  AdminSupportCasesNotifier(this._repo) : super(const AdminSupportCasesState());

  final SupportRepository _repo;

  Future<void> load({
    String? status,
    String? category,
    String? search,
    int skip = 0,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _repo.adminListCases(
        status: status,
        category: category,
        search: search,
        skip: skip,
      );
      state = state.copyWith(
        loading: false,
        cases: result.cases,
        total: result.total,
        statusFilter: status,
        categoryFilter: category,
        search: search,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load(
        status: state.statusFilter,
        category: state.categoryFilter,
        search: state.search,
      );
}

final adminSupportCasesProvider =
    StateNotifierProvider.autoDispose<AdminSupportCasesNotifier, AdminSupportCasesState>(
  (ref) => AdminSupportCasesNotifier(ref.watch(supportRepositoryProvider)),
);
