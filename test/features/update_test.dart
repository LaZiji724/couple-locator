import 'package:couple_locator/features/update/update_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> rel(String tag, {List<String> files = const ['a.apk', 'b.ipa'], bool draft = false}) => {
      'tag_name': tag,
      'draft': draft,
      'html_url': 'https://x/$tag',
      'body': '说明',
      'assets': [for (final f in files) {'name': f, 'browser_download_url': 'https://x/$tag/$f', 'size': 10}],
    };

void main() {
  test('版本号解析与比较', () {
    expect(parseVersion('v2.1.0'), [2, 1, 0]);
    expect(parseVersion('v2.1.0-build7'), [2, 1, 0]);
    expect(parseVersion('2.1.0+3'), [2, 1, 0]);
    expect(parseVersion('abc'), isNull);
    expect(compareVersions([2, 1, 0], [2, 0, 9]) > 0, isTrue);
  });

  test('按平台挑选最新且更高的版本', () {
    final rs = [rel('v2.0.0'), rel('v2.1.0'), rel('v2.2.0', draft: true), rel('v2.1.0-build9')];
    expect(findUpdate(releases: rs, ios: false, current: '2.0.0')!.assetName, 'a.apk');
    expect(findUpdate(releases: rs, ios: true, current: '2.0.0')!.assetName, 'b.ipa');
    expect(findUpdate(releases: rs, ios: false, current: '2.1.0'), isNull);
    expect(findUpdate(releases: [rel('v3.0.0', files: ['b.ipa'])], ios: false, current: '2.0.0'), isNull);
  });
}
