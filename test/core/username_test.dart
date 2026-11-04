import 'package:couple_locator/core/username.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('用户名校验与映射', () {
    expect(Username.isValid('Tiny_Cat1'), isTrue);
    expect(Username.isValid(' ab '), isFalse);
    expect(Username.isValid('a b c'), isFalse);
    expect(Username.isValid('小猫咪咪'), isFalse);
    expect(Username.isValid('a' * 21), isFalse);
    expect(Username.toAuthEmail(' Tiny_Cat1 '), 'tiny_cat1@${Username.domain}');
  });
}
