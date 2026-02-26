import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

/// Web: ensure cookies are included for cross-site calls (HttpOnly refresh cookie).
void configureDioHttpAdapter(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}