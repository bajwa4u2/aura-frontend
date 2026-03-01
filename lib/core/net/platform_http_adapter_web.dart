import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

void configureDioForPlatformImpl(Dio dio) {
  // On web, cookies are NOT sent cross-origin unless credentials are enabled.
  // This is required for HttpOnly refresh cookie (api.*) to be sent from app.*.
  final current = dio.httpClientAdapter;
  if (current is BrowserHttpClientAdapter) {
    current.withCredentials = true;
    return;
  }

  final adapter = BrowserHttpClientAdapter();
  adapter.withCredentials = true;
  dio.httpClientAdapter = adapter;
}