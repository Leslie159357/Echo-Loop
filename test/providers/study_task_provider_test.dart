import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/study_task_provider.dart';
import 'package:echo_loop/providers/time_provider.dart';

import '../helpers/mock_providers.dart';

void main() {
  group('studyTaskProvider', () {
    test('任务排序遵循：可复习 > 未到时间复习 > 首次学习', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Alpha',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'Beta',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'c',
          name: 'Gamma',
          audioPath: 'audios/c.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(minutes: 2)),
        ),
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now.subtract(const Duration(minutes: 1)),
        ),
        'c': LearningProgress(
          audioItemId: 'c',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), ['a', 'b', 'c']);
      expect(tasks[0].type, StudyTaskType.reviewReady);
      expect(tasks[1].type, StudyTaskType.reviewUpcoming);
      expect(tasks[2].type, StudyTaskType.firstStudy);
    });

    test('多个 firstLearn 音频时只显示学习进度最深的那个', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'first-shallow',
          name: 'TPO-46-C2',
          audioPath: 'audios/tpo46c2.mp3',
          addedDate: now.subtract(const Duration(days: 2)),
          totalDuration: 300,
        ),
        AudioItem(
          id: 'first-deep',
          name: 'TPO-57-C1',
          audioPath: 'audios/tpo57c1.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 280,
        ),
      ];

      final progressMap = {
        // blindListen 是首次学习最初始的子阶段，进度最浅
        'first-shallow': LearningProgress(
          audioItemId: 'first-shallow',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.blindListen,
          // 即使 updatedAt 更新，进度浅的也不应被保留
          updatedAt: now,
        ),
        // listenAndRepeat 子阶段更靠后，说明已有实际学习进度
        'first-deep': LearningProgress(
          audioItemId: 'first-deep',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.listenAndRepeat,
          updatedAt: now.subtract(const Duration(hours: 3)),
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'first-deep');
      expect(tasks.single.type, StudyTaskType.firstStudy);
      expect(tasks.single.subStage, SubStageType.listenAndRepeat);
    });

    test('无进度音频时只投放 1 个首次学习任务', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'audio-1',
          name: 'No Progress Audio',
          audioPath: 'audios/a1.mp3',
          addedDate: now,
          totalDuration: 180,
        ),
        AudioItem(
          id: 'audio-2',
          name: 'Second Audio',
          audioPath: 'audios/a2.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 240,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'audio-1');
      expect(tasks.single.type, StudyTaskType.firstStudy);
      expect(tasks.single.stage, LearningStage.firstLearn);
      expect(tasks.single.subStage, SubStageType.blindListen);
    });

    test('存在首次学习任务时不投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'in-progress',
          name: 'In Progress Audio',
          audioPath: 'audios/in-progress.mp3',
          addedDate: now,
          totalDuration: 300,
        ),
        AudioItem(
          id: 'unstarted',
          name: 'Unstarted Audio',
          audioPath: 'audios/unstarted.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 120,
        ),
      ];

      final progressMap = {
        'in-progress': LearningProgress(
          audioItemId: 'in-progress',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.listenAndRepeat,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'in-progress');
    });

    test('存在 review0 任务时不投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'review0',
          name: 'Review 0 Audio',
          audioPath: 'audios/review0.mp3',
          addedDate: now,
          totalDuration: 300,
        ),
        AudioItem(
          id: 'unstarted',
          name: 'Unstarted Audio',
          audioPath: 'audios/unstarted.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 60,
        ),
      ];

      final progressMap = {
        'review0': LearningProgress(
          audioItemId: 'review0',
          currentStage: LearningStage.review0,
          currentSubStage: SubStageType.reviewDifficultPractice,
          lastStageCompletedAt: now.subtract(const Duration(hours: 6)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'review0');
    });

    test('仅有 review1 及之后任务且数量不超过 3 时投放 1 个新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'review-1',
          name: 'Review Audio 1',
          audioPath: 'audios/review1.mp3',
          addedDate: now,
          totalDuration: 180,
        ),
        AudioItem(
          id: 'review-2',
          name: 'Review Audio 2',
          audioPath: 'audios/review2.mp3',
          addedDate: now,
          totalDuration: 200,
        ),
        AudioItem(
          id: 'new-short',
          name: 'New Short Audio',
          audioPath: 'audios/new-short.mp3',
          addedDate: now,
          totalDuration: 90,
        ),
        AudioItem(
          id: 'new-long',
          name: 'New Long Audio',
          audioPath: 'audios/new-long.mp3',
          addedDate: now.subtract(const Duration(days: 2)),
          totalDuration: 240,
        ),
      ];

      final progressMap = {
        'review-1': LearningProgress(
          audioItemId: 'review-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
        ),
        'review-2': LearningProgress(
          audioItemId: 'review-2',
          currentStage: LearningStage.review2,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), [
        'review-1',
        'review-2',
        'new-short',
      ]);
      expect(tasks.last.type, StudyTaskType.firstStudy);
    });

    test('只有未到时间的 review1 任务时仍可投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'review-upcoming',
          name: 'Upcoming Review Audio',
          audioPath: 'audios/review-upcoming.mp3',
          addedDate: now,
          totalDuration: 180,
        ),
        AudioItem(
          id: 'new-audio',
          name: 'New Audio',
          audioPath: 'audios/new.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 100,
        ),
      ];

      final progressMap = {
        'review-upcoming': LearningProgress(
          audioItemId: 'review-upcoming',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), [
        'review-upcoming',
        'new-audio',
      ]);
      expect(tasks.first.type, StudyTaskType.reviewUpcoming);
      expect(tasks.last.type, StudyTaskType.firstStudy);
    });

    test('在学任务超过 3 个时不投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        for (var i = 0; i < 4; i++)
          AudioItem(
            id: 'review-$i',
            name: 'Review Audio $i',
            audioPath: 'audios/review-$i.mp3',
            addedDate: now,
            totalDuration: 120 + i,
          ),
        AudioItem(
          id: 'unstarted',
          name: 'Unstarted Audio',
          audioPath: 'audios/unstarted.mp3',
          addedDate: now.subtract(const Duration(days: 1)),
          totalDuration: 60,
        ),
      ];

      final progressMap = {
        for (var i = 0; i < 4; i++)
          'review-$i': LearningProgress(
            audioItemId: 'review-$i',
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now.subtract(const Duration(days: 1)),
            updatedAt: now,
          ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 4);
      expect(tasks.any((task) => task.audioId == 'unstarted'), isFalse);
    });

    test('新音频选择遵循 最短时长 -> 最早导入 -> 名称 -> id', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'duration-zero',
          name: 'Duration Zero',
          audioPath: 'audios/duration-zero.mp3',
          addedDate: now.subtract(const Duration(days: 3)),
          totalDuration: 0,
        ),
        AudioItem(
          id: 'same-duration-b',
          name: 'Bravo',
          audioPath: 'audios/bravo.mp3',
          addedDate: now.subtract(const Duration(days: 2)),
          totalDuration: 120,
        ),
        AudioItem(
          id: 'same-duration-a',
          name: 'Alpha',
          audioPath: 'audios/alpha.mp3',
          addedDate: now.subtract(const Duration(days: 2)),
          totalDuration: 120,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.single.audioId, 'same-duration-a');
    });

    test('没有未学习音频时不投放新音频', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'review-only',
          name: 'Review Only',
          audioPath: 'audios/review-only.mp3',
          addedDate: now,
          totalDuration: 180,
        ),
      ];

      final progressMap = {
        'review-only': LearningProgress(
          audioItemId: 'review-only',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 1);
      expect(tasks.single.audioId, 'review-only');
    });

    test('边界时刻 now == nextReviewAt 时任务归类为可复习', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'audio-1',
          name: 'Boundary Review Audio',
          audioPath: 'audios/a1.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.single.type, StudyTaskType.reviewReady);
    });

    test('可复习任务内按逾期优先且逾期越久越靠前', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Overdue 5h',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'Overdue 2h',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'c',
          name: 'Ready Not Overdue',
          audioPath: 'audios/c.mp3',
          addedDate: now,
        ),
      ];
      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // review1 窗口结束 = completed + 48h，这里逾期 5h
          lastStageCompletedAt: now.subtract(const Duration(hours: 53)),
          updatedAt: now,
        ),
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // 逾期 2h
          lastStageCompletedAt: now.subtract(const Duration(hours: 50)),
          updatedAt: now,
        ),
        'c': LearningProgress(
          audioItemId: 'c',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // 已解锁但还在 24h 学习窗口内
          lastStageCompletedAt: now.subtract(const Duration(hours: 30)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), ['a', 'b', 'c']);
      expect(tasks[0].type, StudyTaskType.reviewReady);
      expect(tasks[0].isOverdue, true);
      expect(tasks[0].overdueDuration, const Duration(hours: 5));
      expect(tasks[1].isOverdue, true);
      expect(tasks[1].overdueDuration, const Duration(hours: 2));
      expect(tasks[2].isOverdue, false);
      expect(tasks[2].overdueDuration, isNull);
    });

    test('review0 采用 6 小时窗口判定逾期', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'review0 overdue',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'review0 in window',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
      ];
      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review0,
          currentSubStage: SubStageType.reviewDifficultPractice,
          // review0 窗口结束 = completed + 12h，这里逾期 1h
          lastStageCompletedAt: now.subtract(const Duration(hours: 13)),
          updatedAt: now,
        ),
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review0,
          currentSubStage: SubStageType.reviewDifficultPractice,
          // 已解锁但仍在 6h 窗口内
          lastStageCompletedAt: now.subtract(const Duration(hours: 7)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((e) => e.audioId).toList(), ['a', 'b']);
      expect(
        tasks.every((task) => task.type == StudyTaskType.reviewReady),
        true,
      );
      expect(tasks[0].isOverdue, true);
      expect(tasks[0].overdueDuration, const Duration(hours: 1));
      expect(tasks[1].isOverdue, false);
    });

    test('暂停学习的音频不进入任务列表', () {
      final now = DateTime(2026, 5, 16, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'paused-review',
          name: 'Paused Review',
          audioPath: 'audios/p.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'paused-first',
          name: 'Paused First',
          audioPath: 'audios/q.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'active-review',
          name: 'Active Review',
          audioPath: 'audios/r.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        'paused-review': LearningProgress(
          audioItemId: 'paused-review',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
          isPaused: true,
        ),
        'paused-first': LearningProgress(
          audioItemId: 'paused-first',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.listenAndRepeat,
          updatedAt: now,
          isPaused: true,
        ),
        'active-review': LearningProgress(
          audioItemId: 'active-review',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.map((t) => t.audioId).toList(), ['active-review']);
    });
  });

  group('pendingStudyTaskCountProvider', () {
    test('不计入 reviewUpcoming 类型的任务', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Alpha',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'Beta',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'c',
          name: 'Gamma',
          audioPath: 'audios/c.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        // reviewReady：已过复习时间
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(minutes: 2)),
        ),
        // reviewUpcoming：未到复习时间
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now.subtract(const Duration(minutes: 1)),
        ),
        // firstStudy：首次学习
        'c': LearningProgress(
          audioItemId: 'c',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      // studyTaskProvider 包含 3 个任务（reviewReady + reviewUpcoming + firstStudy）
      final tasks = container.read(studyTaskProvider);
      expect(tasks.length, 3);

      // pendingStudyTaskCountProvider 应只计算 reviewReady + firstStudy = 2
      final count = container.read(pendingStudyTaskCountProvider);
      expect(count, 2);
    });

    test('全部为 reviewUpcoming 时返回 0', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Upcoming Only',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
      ];

      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final tasks = container.read(studyTaskProvider);
      expect(tasks.single.type, StudyTaskType.reviewUpcoming);

      final count = container.read(pendingStudyTaskCountProvider);
      expect(count, 0);
    });
  });

  group('completedAudioProvider', () {
    test('已完成音频正确返回', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'Completed',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'b',
          name: 'In Progress',
          audioPath: 'audios/b.mp3',
          addedDate: now,
        ),
        AudioItem(
          id: 'c',
          name: 'Also Completed',
          audioPath: 'audios/c.mp3',
          addedDate: now,
        ),
      ];
      final progressMap = {
        'a': LearningProgress(
          audioItemId: 'a',
          currentStage: LearningStage.completed,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
        'b': LearningProgress(
          audioItemId: 'b',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
        'c': LearningProgress(
          audioItemId: 'c',
          currentStage: LearningStage.completed,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      };

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(progressMap: progressMap),
            ),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final completed = container.read(completedAudioProvider);
      expect(completed.length, 2);
      expect(completed[0].audioName, 'Completed');
      expect(completed[1].audioName, 'Also Completed');
    });

    test('无已完成音频时返回空列表', () {
      final now = DateTime(2026, 2, 25, 12, 0);
      final audioItems = [
        AudioItem(
          id: 'a',
          name: 'First Study',
          audioPath: 'audios/a.mp3',
          addedDate: now,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final completed = container.read(completedAudioProvider);
      expect(completed, isEmpty);
    });
  });
}
