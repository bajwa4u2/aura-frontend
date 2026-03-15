import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configureDioForPlatform(Dio dio) {
  final current = dio.httpClientAdapter;

  if (current is BrowserHttpClientAdapter) {
    current.withCredentials = true;
    return;
  }

  final adapter = BrowserHttpClientAdapter();
  adapter.withCredentials = true;
  dio.httpClientAdapter = adapter;
}
