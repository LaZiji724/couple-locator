/// 一个可以更新到的新版本（来自 GitHub Release）。
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.assetName,
    required this.assetUrl,
    required this.assetSize,
  });

  /// 如 2.1.0
  final String version;
  final String notes;

  /// Release 网页（iOS 跳转下载、安卓下载失败时手动打开）。
  final String pageUrl;
  final String assetName;
  final String assetUrl;
  final int assetSize;
}

/// 把 `v2.1.0` / `v2.1.0-build12` / `2.1.0+3` 解析成 [2, 1, 0]；格式不对返回 null。
List<int>? parseVersion(String text) {
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:-build\d+)?(?:\+\d+)?$').firstMatch(text.trim());
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// a 比 b 新返回正数，相同返回 0，旧返回负数。
int compareVersions(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

/// 从 GitHub `releases` 接口返回的列表里找出比 [current] 新的最高版本。
/// 本项目每个 Release 同时带 APK 和 IPA，按平台挑对应后缀的附件。
AppUpdate? findUpdate({required List<dynamic> releases, required bool ios, required String current}) {
  final cur = parseVersion(current);
  if (cur == null) return null;
  final ext = ios ? '.ipa' : '.apk';
  AppUpdate? best;
  List<int>? bestVer;
  for (final r in releases) {
    if (r is! Map) continue;
    if (r['draft'] == true || r['prerelease'] == true) continue;
    final ver = parseVersion('${r['tag_name'] ?? ''}');
    if (ver == null || compareVersions(ver, cur) <= 0) continue;
    if (bestVer != null && compareVersions(ver, bestVer) <= 0) continue;
    final assets = r['assets'];
    if (assets is! List) continue;
    final asset = assets.whereType<Map>().where((a) => '${a['name'] ?? ''}'.toLowerCase().endsWith(ext)).firstOrNull;
    if (asset == null) continue;
    bestVer = ver;
    best = AppUpdate(
      version: ver.join('.'),
      notes: '${r['body'] ?? ''}'.trim(),
      pageUrl: '${r['html_url'] ?? ''}',
      assetName: '${asset['name']}',
      assetUrl: '${asset['browser_download_url']}',
      assetSize: (asset['size'] as num?)?.toInt() ?? 0,
    );
  }
  return best;
}
