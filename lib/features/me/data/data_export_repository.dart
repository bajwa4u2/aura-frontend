/// DOWNLOAD MY DATA — the client half of the self-service export (SOC 2,
/// Privacy; founder, 2026-10-26/27).
///
/// The backend (`src/privacy-export`, live at 937cf49) answers
/// `POST /v1/me/export` and `POST /v1/institutions/:id/export` with the data
/// as a file (`Content-Disposition: attachment; filename="…"`), once in any 24
/// hours. A second request inside that window is refused with 429 and
/// `{code: EXPORT_ONCE_A_DAY, retryAt}`; this repository turns that into
/// [ExportOnceADay] so the screen can say when, instead of "something failed".
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

/// The file the server prepared.
class ExportFile {
  const ExportFile({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// The server's once-a-day answer. [retryAt] is when another export is
/// allowed, when the server said so.
class ExportOnceADay implements Exception {
  const ExportOnceADay(this.retryAt);

  final DateTime? retryAt;
}

class DataExportRepository {
  DataExportRepository(this._dio);

  final Dio _dio;

  /// Everything the signed-in person put into Aura.
  Future<ExportFile> exportMine() =>
      _download('/v1/me/export', fallbackName: 'aura-my-data');

  /// The institution's own posts, announcements and member list. The server
  /// refuses anyone below administrator; the client only hides the door.
  Future<ExportFile> exportInstitution(String institutionId) => _download(
        '/v1/institutions/${Uri.encodeComponent(institutionId)}/export',
        fallbackName: 'aura-institution',
      );

  Future<ExportFile> _download(String path, {required String fallbackName}) async {
    try {
      final res = await _dio.post<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(res.data ?? const <int>[]);
      return ExportFile(
        bytes: bytes,
        filename: filenameFrom(
          res.headers.value('content-disposition'),
          fallback: '$fallbackName-${_today()}.json',
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw ExportOnceADay(retryAtFrom(e.response?.data));
      }
      rethrow;
    }
  }

  /// The name the server gave the file, or [fallback].
  static String filenameFrom(String? contentDisposition, {required String fallback}) {
    final m = RegExp(r'filename="?([^";]+)"?').firstMatch(contentDisposition ?? '');
    final name = m?.group(1)?.trim() ?? '';
    return name.isEmpty ? fallback : name;
  }

  /// `retryAt` from the 429 body, which arrives as bytes because the request
  /// asked for bytes.
  static DateTime? retryAtFrom(Object? data) {
    try {
      final text = data is List<int>
          ? utf8.decode(data)
          : data is String
              ? data
              : data is Map
                  ? jsonEncode(data)
                  : '';
      final body = jsonDecode(text);
      final raw = body is Map ? body['retryAt'] : null;
      return raw is String ? DateTime.tryParse(raw) : null;
    } catch (_) {
      return null;
    }
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);
}

final dataExportRepositoryProvider = Provider<DataExportRepository>(
  (ref) => DataExportRepository(ref.watch(dioProvider)),
);
