import 'package:flutter_web_plugins/url_strategy.dart';

void configureUrlStrategy() {
  // ignore: prefer_const_constructors
  setUrlStrategy(PathUrlStrategy());  
}
