import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/learning_progresses.dart';

part 'learning_progress_dao.g.dart';

/// 学习进度 DAO
///
/// 提供学习进度的 CRUD 操作，遵循 PlaybackStateDao 的简洁模式。
@DriftAccessor(tables: [LearningProgresses])
class LearningProgressDao extends DatabaseAccessor<AppDatabase>
    with _$LearningProgressDaoMixin {
  LearningProgressDao(super.db);

  /// 获取指定音频的学习进度
  Future<LearningProgressesData?> getByAudioId(String audioItemId) {
    return (select(
      learningProgresses,
    )..where((t) => t.audioItemId.equals(audioItemId))).getSingleOrNull();
  }

  /// 获取所有学习进度
  Future<List<LearningProgressesData>> getAll() {
    return select(learningProgresses).get();
  }

  /// 插入或更新学习进度
  Future<void> upsert(LearningProgressesCompanion entry) {
    return into(learningProgresses).insertOnConflictUpdate(entry);
  }

  /// 删除指定音频的学习进度
  Future<void> deleteByAudioId(String audioItemId) {
    return (delete(
      learningProgresses,
    )..where((t) => t.audioItemId.equals(audioItemId))).go();
  }

  /// 更新指定音频的暂停状态。
  ///
  /// 仅在该音频存在 learning_progresses 行时生效（更新 0 行不会创建新行）。
  Future<int> setPaused(String audioItemId, bool paused) {
    return (update(
      learningProgresses,
    )..where((t) => t.audioItemId.equals(audioItemId))).write(
      LearningProgressesCompanion(
        isPaused: Value(paused),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
