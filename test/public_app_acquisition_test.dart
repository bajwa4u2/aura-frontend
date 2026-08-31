import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/public/widgets/public_app_acquisition.dart';

void main() {
  test('Aura acquisition is limited to the approved static public inventory', () {
    expect(shouldShowAuraPublicAppAcquisition('/'), isTrue);
    expect(shouldShowAuraPublicAppAcquisition('/discover'), isTrue);
    expect(shouldShowAuraPublicAppAcquisition('/p/public-object'), isFalse);
    expect(shouldShowAuraPublicAppAcquisition('/media/file'), isFalse);
    expect(shouldShowAuraPublicAppAcquisition('/private'), isFalse);
  });

  test('Aura uses the canonical web URL as its Android continuation target', () {
    expect(auraPublicAppAcquisitionConfig.canonicalHost, 'auraplatform.org');
    expect(auraPublicAppAcquisitionConfig.androidOpenSupported, isTrue);
    expect(auraPublicAppAcquisitionConfig.androidStoreUrl, isNull);
  });
}
