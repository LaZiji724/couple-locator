import 'package:flutter/foundation.dart';

/// 简单日志：环形缓冲，设置页可查看。永远不记录明文坐标。
class AppLog {
  AppLog._();
  static final entries = ValueNotifier<List<String>>(const []);
  static String? lastUploadOk;
  static String? lastUploadError;

  static final _coord = RegExp(r'-?\d{1,3}\.\d{4,}');

  static void i(String tag, String msg) => _add('I', tag, msg);
  static void w(String tag, String msg) => _add('W', tag, msg);
  static void e(String tag, Object err) => _add('E', tag, err.toString());

  static void _add(String lvl, String tag, String msg) {
    final clean = msg.replaceAll(_coord, '***');
    final line = '${DateTime.now().toIso8601String().substring(5, 19)} $lvl/$tag $clean';
    if (kDebugMode) debugPrint(line);
    final next = [...entries.value, line];
    entries.value = next.length > 200 ? next.sublist(next.length - 200) : next;
  }

  static void uploadOk() => lastUploadOk = DateTime.now().toIso8601String();
  static void uploadFail(Object e) {
    lastUploadError = '${DateTime.now().toIso8601String().substring(5, 19)} ${e.toString().replaceAll(_coord, '***')}';
    _add('E', 'upload', e.toString());
  }
}
