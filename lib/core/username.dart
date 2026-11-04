/// 用户名登录：不收集真实邮箱。内部把用户名映射成一个固定域名下的“假邮箱”交给 Supabase Auth，
/// 因此必须在 Supabase 后台关闭 “Confirm email”（见 docs/SETUP.md）。
/// 注意：没有真实邮箱 = 无法通过邮件找回密码，请提醒用户牢记密码并备份密钥。
abstract final class Username {
  static const domain =
      String.fromEnvironment('AUTH_EMAIL_DOMAIN', defaultValue: 'couple-locator.app');

  static final _re = RegExp(r'^[a-z0-9_]{3,20}$');

  /// 规范化：去空格、转小写（用户名不区分大小写）。
  static String normalize(String input) => input.trim().toLowerCase();

  static bool isValid(String input) => _re.hasMatch(normalize(input));

  /// 用户名 → Supabase 使用的内部邮箱。
  static String toAuthEmail(String input) => '${normalize(input)}@$domain';
}
