import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

void configureDioForPlatformImpl(Dio dio) {
  final adapter = BrowserHttpClientAdapter();
  adapter.withCredentials = true; // <<< THIS is the whole game
  dio.httpClientAdapter = adapter;
}