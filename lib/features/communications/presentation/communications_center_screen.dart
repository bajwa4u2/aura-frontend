import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_access_provider.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../domain/communications_models.dart';
import '../providers.dart';
import 'widgets/communication_center_shell.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final prefs =
          await ref.read(communicationsRepositoryProvider).loadPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
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
    final keys = patch.keys.toList(growable: false);
    if (mounted) {
      setState(() {
        for (final key in keys) {
          _savingKeys.add(key);
        }
      });
    }
    try {
      final saved = await ref
          .read(communicationsRepositoryProvider)
          .savePreferences(patch);
      if (!mounted) return;
      setState(() => _preferences = saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update communication settings: $e'),
        ),
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
    if (key == 'securityAuth') return 'securityChannel';
    return '${key}Channel';
  }

  String _frequencyFieldFor(String key) {
    if (key == 'securityAuth') return 'securityFrequency';
    return '${key}Frequency';
  }

  void _onChannelChanged(String key, CommunicationChannelOption value) {
    unawaited(_savePreferencePatch({_channelFieldFor(key): value.value}));
  }

  void _onFrequencyChanged(String key, CommunicationFrequencyOption value) {
    unawaited(_savePreferencePatch({_frequencyFieldFor(key): value.value}));
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
                child: CommunicationCenterShell(
                  preferences: _preferences,
                  loading: _loading,
                  error: _error,
                  savingKeys: _savingKeys,
                  onLoad: _load,
                  onChannelChanged: _onChannelChanged,
                  onFrequencyChanged: _onFrequencyChanged,
                  adminAsync: adminAsync,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
