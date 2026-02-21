// lib/core/config/aura_links.dart

/// Central place for any public, non-secret links used by the UI.
/// Keep this frontend-only. No API keys, no envs.
class AuraLinks {
  /// Path used by MissionScreen to open the white paper route/page.
  /// If you later host it as a real page or PDF, keep the UI referencing this.
  static const String whitePaperPath = '/white-paper';

  /// Optional: keep a single source of truth for external URLs as you grow.
  /// Use only if you want them. Safe to leave unused.
  static const String website = 'https://aura.example';
  static const String docs = 'https://aura.example/docs';
}