/// One "download your data" panel, used by a person (Settings → Download my
/// data) and by an institution's administrators (its Profile page).
///
/// States, each said plainly: ready; preparing (the button is busy); saved
/// (names the file and where it went); nothing saved (the save dialog was
/// closed); already today (the server's once-a-day answer, with the time it
/// opens again); and a plain failure with Retry.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/files/save_file_bytes.dart';
import '../../../../core/product/product_language.dart';
import '../../../../core/product/temporal.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../data/data_export_repository.dart';

typedef ExportFetch = Future<ExportFile> Function();
typedef ExportSave = Future<MediaSaveResult> Function(ExportFile file);

enum DataExportPhase { ready, preparing, saved, notSaved, onceADay, failed }

class DataExportPanel extends StatefulWidget {
  const DataExportPanel({
    super.key,
    required this.fetch,
    required this.buttonLabel,
    this.save,
    this.dialogTitle = 'Save your data',
    this.initialPhase = DataExportPhase.ready,
    this.initialFilename,
    this.initialRetryAt,
  });

  final ExportFetch fetch;
  final String buttonLabel;

  /// Defaults to the platform save; tests pass their own.
  final ExportSave? save;
  final String dialogTitle;

  /// For review screenshots only: start in a given state.
  @visibleForTesting
  final DataExportPhase initialPhase;
  @visibleForTesting
  final String? initialFilename;
  @visibleForTesting
  final DateTime? initialRetryAt;

  @override
  State<DataExportPanel> createState() => _DataExportPanelState();
}

class _DataExportPanelState extends State<DataExportPanel> {
  late DataExportPhase _phase = widget.initialPhase;
  late String? _filename = widget.initialFilename;
  late DateTime? _retryAt = widget.initialRetryAt;

  Future<void> _run() async {
    setState(() => _phase = DataExportPhase.preparing);
    try {
      final file = await widget.fetch();
      final save = widget.save ??
          (f) => saveFileBytes(
                bytes: f.bytes,
                filename: f.filename,
                mimeType: 'application/json',
                dialogTitle: widget.dialogTitle,
              );
      final result = await save(file);
      if (!mounted) return;
      setState(() {
        _filename = file.filename;
        _phase = switch (result.status) {
          MediaSaveStatus.saved => DataExportPhase.saved,
          MediaSaveStatus.cancelled => DataExportPhase.notSaved,
          _ => DataExportPhase.failed,
        };
      });
    } on ExportOnceADay catch (e) {
      if (!mounted) return;
      setState(() {
        _retryAt = e.retryAt;
        _phase = DataExportPhase.onceADay;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = DataExportPhase.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase == DataExportPhase.preparing;
    final blocked = _phase == DataExportPhase.onceADay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AuraPrimaryButton(
            label: busy
                ? 'Preparing your data…'
                : _phase == DataExportPhase.failed
                    ? ProductLabels.of(ProductAction.retry)
                    : widget.buttonLabel,
            icon: busy ? null : Icons.download_rounded,
            onPressed: busy || blocked ? null : _run,
          ),
        ),
        if (_status() case final status?) ...[
          const SizedBox(height: AuraSpace.s12),
          status,
        ],
      ],
    );
  }

  Widget? _status() {
    switch (_phase) {
      case DataExportPhase.ready:
      case DataExportPhase.preparing:
        return null;
      case DataExportPhase.saved:
        return _StatusLine(
          icon: Icons.check_circle_outline_rounded,
          color: AuraSurface.goodInk,
          text: 'Your data is saved as ${_filename ?? 'a file'}. '
              '${kIsWeb ? 'It is in your browser\'s downloads.' : 'It is where you chose to save it.'}',
        );
      case DataExportPhase.notSaved:
        return const _StatusLine(
          icon: Icons.info_outline_rounded,
          color: AuraSurface.muted,
          text: 'Nothing was saved. Your download for today has been used.',
        );
      case DataExportPhase.onceADay:
        final at = _retryAt;
        return _StatusLine(
          icon: Icons.schedule_rounded,
          color: AuraSurface.warnInk,
          text: at == null
              ? 'You can download your data again tomorrow.'
              : 'You can download your data again after '
                  '${AuraTemporal.fullShort(at)}.',
        );
      case DataExportPhase.failed:
        return const _StatusLine(
          icon: Icons.error_outline_rounded,
          color: AuraSurface.dangerInk,
          text: 'Your data could not be prepared. Please try again.',
        );
    }
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: AuraSpace.s8),
        Expanded(
          child: Text(
            text,
            style: AuraText.small.copyWith(color: color, height: 1.4),
          ),
        ),
      ],
    );
  }
}
