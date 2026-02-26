import 'package:dio/dio.dart';

import 'platform_http_adapter_stub.dart'
    if (dart.library.html) 'platform_http_adapter_web.dart';

/// Configures Dio per platform (web vs non-web).
void configureDioForPlatform(Dio dio) => configureDioHttpAdapter(dio);