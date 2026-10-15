import 'package:doc_scanner/utils/app_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('supplied splash JSON loads as a portrait animation', () async {
    final composition = await AssetLottie(AppAssets.splashAnimation).load();
    expect(composition.bounds.width, 375);
    expect(composition.bounds.height, 812);
    expect(composition.duration.inSeconds, greaterThanOrEqualTo(1));
  });
}
