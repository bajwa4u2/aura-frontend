import 'package:dio/dio.dart';

import 'platform_http_adapter_stub.dart'
    if (dart.library.html) 'platform_http_adapter_web.dart'
    if (dart.library.io) 'platform_http_adapter_io.dart';

void configureDioForPlatform(Dio dio) => configureDioForPlatformImpl(dio);