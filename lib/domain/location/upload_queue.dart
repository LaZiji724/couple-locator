/// 待上传的一条记录（本地先存，补传幂等）。
class PendingItem {
  const PendingItem({required this.clientId, required this.ts, required this.payload});
  final String clientId; // 设备生成的 uuid
  final int ts; // 客户端毫秒时间戳
  final Object payload;

  /// 幂等键：client_id + 时间戳。服务端对 (user_id, client_id, ts) 建唯一索引。
  String get dedupeKey => '$clientId@$ts';
}

/// 按时间顺序排序并去重，然后切成批次。
List<List<PendingItem>> buildBatches(Iterable<PendingItem> items, {int batchSize = 100}) {
  final seen = <String>{};
  final list = <PendingItem>[];
  for (final i in items) {
    if (seen.add(i.dedupeKey)) list.add(i);
  }
  list.sort((a, b) => a.ts.compareTo(b.ts));
  return [
    for (var i = 0; i < list.length; i += batchSize)
      list.sublist(i, i + batchSize > list.length ? list.length : i + batchSize)
  ];
}
