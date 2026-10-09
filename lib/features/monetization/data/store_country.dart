import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// The App Store country this iPhone or iPad buys from, as StoreKit names it
/// ("USA"), or null anywhere else, or when StoreKit cannot say.
///
/// Read only to decide whether Billing may point an owner to the web: Apple
/// allows that on the United States storefront alone (3.1.1(a)). The device
/// region is not the storefront and is never used for this.
final appStoreCountryProvider = FutureProvider<String?>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  try {
    final storefront = await SKPaymentQueueWrapper().storefront();
    return storefront?.countryCode;
  } catch (_) {
    return null;
  }
});
