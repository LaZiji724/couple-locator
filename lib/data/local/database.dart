import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// 位置点（自己的与对方的；对方点为解密后缓存）。坐标为 WGS-84。
class Points extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerId => text()();
  TextColumn get clientId => text()();
  IntColumn get ts => integer()(); // 毫秒
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get accuracy => real().withDefault(const Constant(0))();
  RealColumn get speed => real().withDefault(const Constant(0))();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {ownerId, clientId, ts}
      ];
}

/// 待上传的加密事件/状态（断网时排队）。
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()(); // event / pin / status
  TextColumn get json => text()();
  IntColumn get createdAt => integer()();
}

/// 本地缓存的事件、标记（已解密 JSON）。
class CachedDocs extends Table {
  TextColumn get key => text()(); // event:<id> / pin:<id>
  TextColumn get kind => text()();
  IntColumn get ts => integer()();
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Points, Outbox, CachedDocs])
class AppDb extends _$AppDb {
  AppDb([QueryExecutor? e]) : super(e ?? driftDatabase(name: 'couple_locator'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX IF NOT EXISTS idx_points_owner_ts ON points(owner_id, ts)');
        },
      );

  /// 幂等写入：同 (owner, clientId, ts) 只保留一份。
  Future<void> upsertPoint(PointsCompanion p) =>
      into(points).insert(p, mode: InsertMode.insertOrIgnore);

  Future<List<Point>> pendingUploads({int limit = 200}) =>
      (select(points)
            ..where((t) => t.uploaded.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.ts)])
            ..limit(limit))
          .get();

  Future<void> markUploaded(List<int> ids) =>
      (update(points)..where((t) => t.id.isIn(ids))).write(const PointsCompanion(uploaded: Value(true)));

  Future<List<Point>> pointsBetween(String owner, DateTime from, DateTime to) =>
      (select(points)
            ..where((t) =>
                t.ownerId.equals(owner) &
                t.ts.isBiggerOrEqualValue(from.millisecondsSinceEpoch) &
                t.ts.isSmallerThanValue(to.millisecondsSinceEpoch))
            ..orderBy([(t) => OrderingTerm.asc(t.ts)]))
          .get();

  Future<Point?> latestPoint(String owner) =>
      (select(points)
            ..where((t) => t.ownerId.equals(owner))
            ..orderBy([(t) => OrderingTerm.desc(t.ts)])
            ..limit(1))
          .getSingleOrNull();

  /// 按保留天数清理本地数据（与服务端一致）。
  Future<int> purgeOlderThan(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    return (delete(points)..where((t) => t.ts.isSmallerThanValue(cutoff) & t.uploaded.equals(true))).go();
  }

  Future<void> wipeAll() async {
    await delete(points).go();
    await delete(outbox).go();
    await delete(cachedDocs).go();
  }
}
