import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:amap_map/amap_map.dart';
import 'package:flutter/painting.dart';

import '../../core/theme/tokens.dart';

/// 绘制地图头像标记：圆形头像 + 渐变外环 + 下方小三角 + 可选徽标。
/// 输出 PNG 供高德 Marker 使用（原生 Marker 不能直接放 Flutter Widget）。
class AvatarMarkerPainter {
  static final _cache = <String, BitmapDescriptor>{};

  static Future<BitmapDescriptor> build({
    required PersonalPalette palette,
    String? emoji,
    String? photoDataUri,
    bool lowBattery = false,
    bool paused = false,
    double scale = 3, // 生成 3x 位图，在高分屏上清晰
    double size = 56,
  }) async {
    final key = '${palette.id}|$emoji|${photoDataUri?.hashCode}|$lowBattery|$paused|$scale';
    final hit = _cache[key];
    if (hit != null) return hit;
    final bytes = await _render(palette, emoji, photoDataUri, lowBattery, paused, scale, size);
    final d = BitmapDescriptor.fromBytes(bytes);
    _cache[key] = d;
    return d;
  }

  static Future<Uint8List> _render(PersonalPalette pal, String? emoji, String? photo, bool low, bool paused, double s, double size) async {
    final w = (size + 16) * s, h = (size + 16 + 14) * s;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.scale(s);
    final cx = (size + 16) / 2, cy = (size + 16) / 2;
    final r = size / 2;

    final tint = paused ? const ui.ColorFilter.mode(Color(0xFF9E9E9E), ui.BlendMode.saturation) : null;
    final layerPaint = ui.Paint();
    if (tint != null) layerPaint.colorFilter = tint;
    c.saveLayer(ui.Rect.fromLTWH(0, 0, size + 16, size + 16 + 14), layerPaint);

    // 柔和阴影
    c.drawCircle(Offset(cx, cy + 3), r + 3, ui.Paint()
      ..color = pal.start.withValues(alpha: 0.35)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6));
    // 下方小三角（颜色取渐变末端）
    final tri = ui.Path()
      ..moveTo(cx - 8, cy + r + 1)
      ..lineTo(cx + 8, cy + r + 1)
      ..lineTo(cx, cy + r + 13)
      ..close();
    c.drawPath(tri, ui.Paint()..color = pal.end);
    // 渐变外环
    final ring = ui.Rect.fromCircle(center: Offset(cx, cy), radius: r);
    c.drawCircle(Offset(cx, cy), r, ui.Paint()
      ..shader = ui.Gradient.linear(ring.topLeft, ring.bottomRight, [pal.start, pal.end]));
    // 白色内底
    final inner = r - 5;
    c.drawCircle(Offset(cx, cy), inner + 2, ui.Paint()..color = const Color(0xFFFFFFFF));
    // 头像
    c.save();
    c.clipPath(ui.Path()..addOval(ui.Rect.fromCircle(center: Offset(cx, cy), radius: inner)));
    if (photo != null && photo.startsWith('data:')) {
      final img = await _decode(base64Decode(photo.split(',').last));
      if (img != null) {
        final src = ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final side = math.min(src.width, src.height);
        final crop = ui.Rect.fromCenter(center: src.center, width: side, height: side);
        c.drawImageRect(img, crop, ui.Rect.fromCircle(center: Offset(cx, cy), radius: inner), ui.Paint()..filterQuality = ui.FilterQuality.high);
      }
    } else {
      c.drawRect(ui.Rect.fromCircle(center: Offset(cx, cy), radius: inner), ui.Paint()..color = pal.start.withValues(alpha: 0.18));
      final tp = TextPainter(
        text: TextSpan(text: emoji ?? '🙂', style: TextStyle(fontSize: inner * 1.15)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
    c.restore();
    c.restore();

    // 徽标（不受去饱和影响）
    if (low) {
      final b = Offset(cx + r * 0.72, cy - r * 0.72);
      c.drawCircle(b, 10, ui.Paint()..color = const Color(0xFFFFFFFF));
      c.drawCircle(b, 8, ui.Paint()..color = const Color(0xFFFF4D6D));
      final tp = TextPainter(text: const TextSpan(text: '!', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 12, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(b.dx - tp.width / 2, b.dy - tp.height / 2));
    }
    if (paused) {
      final b = Offset(cx + r * 0.72, cy - r * 0.72);
      c.drawCircle(b, 10, ui.Paint()..color = const Color(0xFFFFFFFF));
      final tp = TextPainter(text: const TextSpan(text: '⏸', style: TextStyle(fontSize: 12)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(b.dx - tp.width / 2, b.dy - tp.height / 2));
    }

    final pic = rec.endRecording();
    final img = await pic.toImage(w.round(), h.round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 160);
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  /// 共同标记的小圆标。
  static Future<BitmapDescriptor> pin(String emoji, {double scale = 3}) async {
    final key = 'pin|$emoji|$scale';
    final hit = _cache[key];
    if (hit != null) return hit;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.scale(scale);
    const w = 44.0, h = 54.0;
    c.drawCircle(const Offset(w / 2, 24), 19, ui.Paint()
      ..color = const Color(0x55A78BFA)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5));
    final tri = ui.Path()..moveTo(w / 2 - 7, 38)..lineTo(w / 2 + 7, 38)..lineTo(w / 2, 52)..close();
    c.drawPath(tri, ui.Paint()..color = AppColors.accent);
    c.drawCircle(const Offset(w / 2, 22), 19, ui.Paint()..color = AppColors.accent);
    c.drawCircle(const Offset(w / 2, 22), 16, ui.Paint()..color = const Color(0xFFFFFFFF));
    final tp = TextPainter(text: TextSpan(text: emoji, style: const TextStyle(fontSize: 20)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(w / 2 - tp.width / 2, 22 - tp.height / 2));
    final img = await rec.endRecording().toImage((w * scale).round(), (h * scale).round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final d = BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
    _cache[key] = d;
    return d;
  }
}
