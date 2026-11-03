import 'package:couple_locator/domain/location/sampling.dart';
import 'package:couple_locator/domain/location/upload_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('驾车 5s 采集 / 8s 上传（均衡）', () {
    final p = planFor(motion: MoveState.driving, mode: ReportMode.balanced, batteryPercent: 80, charging: false);
    expect(p.sampleInterval.inSeconds, 5);
    expect(p.uploadInterval.inSeconds, 8);
  });
  test('省电 ×2、精准 ×0.5', () {
    final s = planFor(motion: MoveState.walking, mode: ReportMode.saver, batteryPercent: 80, charging: false);
    final a = planFor(motion: MoveState.walking, mode: ReportMode.precise, batteryPercent: 80, charging: false);
    expect(s.sampleInterval.inSeconds, 24);
    expect(a.sampleInterval.inMilliseconds, 6000);
  });
  test('静止：显著变化 + 5 分钟心跳', () {
    final p = planFor(motion: MoveState.still, mode: ReportMode.balanced, batteryPercent: 80, charging: false);
    expect(p.significantOnly, isTrue);
    expect(p.uploadInterval.inMinutes, 5);
  });
  test('低电量降一档、充电时不降', () {
    final low = planFor(motion: MoveState.walking, mode: ReportMode.balanced, batteryPercent: 10, charging: false);
    final chg = planFor(motion: MoveState.walking, mode: ReportMode.balanced, batteryPercent: 10, charging: true);
    expect(low.sampleInterval, chg.sampleInterval * 2);
    expect(low.uploadInterval > chg.uploadInterval * 2, isTrue);
  });
  test('SOS 3 秒立即上传', () {
    final p = planFor(motion: MoveState.still, mode: ReportMode.saver, batteryPercent: 5, charging: false, sos: true);
    expect(p.sampleInterval.inSeconds, 3);
    expect(p.uploadInterval, Duration.zero);
    expect(p.significantOnly, isFalse);
  });
  test('移动状态分类', () {
    expect(classifyMotion(speedMps: 0.1), MoveState.still);
    expect(classifyMotion(speedMps: 1.4), MoveState.walking);
    expect(classifyMotion(speedMps: 3.0), MoveState.running);
    expect(classifyMotion(speedMps: 6), MoveState.cycling);
    expect(classifyMotion(speedMps: 20), MoveState.driving);
    expect(classifyMotion(speedMps: 0.2, activity: 'IN_VEHICLE'), MoveState.driving);
  });

  test('补传：按时间排序、幂等去重、分批', () {
    final items = [
      const PendingItem(clientId: 'a', ts: 3, payload: 1),
      const PendingItem(clientId: 'a', ts: 1, payload: 1),
      const PendingItem(clientId: 'a', ts: 3, payload: 1), // 重复
      const PendingItem(clientId: 'a', ts: 2, payload: 1),
    ];
    final b = buildBatches(items, batchSize: 2);
    expect(b.length, 2);
    expect(b.expand((e) => e).map((e) => e.ts), [1, 2, 3]);
    // 重复补传两次结果相同
    expect(buildBatches([...items, ...items]).expand((e) => e).length, 3);
  });
}
