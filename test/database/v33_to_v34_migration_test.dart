import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v33 → v34 迁移：learning_progresses 新增 review0_plan_version 列。
///
/// - 列默认 2（= 新版 review0：难句补练 + 全文盲听）
/// - 迁移规则：currentStage 已进入 review1+ 的行回填 1（保留旧版 UI）；
///   firstLearn / review0 的行留 2（新版生效）
void main() {
  test('v33→v34 为 learning_progresses 加 review0_plan_version 列并按 stage 回填',
      () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v33_to_v34_');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    final file = File('${dir.path}/echo_loop.db');
    _createV33LearningProgress(file);

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final columns = await db
        .customSelect('PRAGMA table_info(learning_progresses)')
        .get();
    final columnNames = columns
        .map((row) => row.data['name'] as String)
        .toSet();
    expect(columnNames, contains('review0_plan_version'));

    final rows = await db
        .customSelect(
          'SELECT audio_item_id, review0_plan_version FROM learning_progresses '
          'ORDER BY audio_item_id',
        )
        .get();
    final byId = {
      for (final r in rows)
        r.data['audio_item_id'] as String: r.data['review0_plan_version'] as int,
    };

    // (A) 全新音频 / 仍在 firstLearn → 新版
    expect(byId['audio-firstlearn'], 2);
    // (B) 已进入 review0 但未完成 → 新版
    expect(byId['audio-review0'], 2);
    // (C) 已完成 review0（review1+）→ 旧版
    expect(byId['audio-review1'], 1);
    expect(byId['audio-review28'], 1);
    expect(byId['audio-completed'], 1);
  });
}

void _createV33LearningProgress(File file) {
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('''
      CREATE TABLE learning_progresses (
        audio_item_id TEXT NOT NULL PRIMARY KEY,
        current_stage TEXT NOT NULL DEFAULT 'firstLearn',
        current_sub_stage TEXT NOT NULL DEFAULT 'blindListen',
        difficulty INTEGER NOT NULL DEFAULT 1,
        first_learn_completed_at INTEGER,
        last_stage_completed_at INTEGER,
        current_stage_started_at INTEGER,
        total_study_duration_ms INTEGER NOT NULL DEFAULT 0,
        blind_listen_pass_count INTEGER NOT NULL DEFAULT 0,
        intensive_listen_sentence_index INTEGER,
        intensive_listen_difficult_count INTEGER,
        intensive_listen_pass_count INTEGER,
        shadowing_pass_count INTEGER,
        shadowing_sentence_index INTEGER,
        difficult_practice_sentence_index INTEGER,
        retell_paragraph_index INTEGER,
        retell_pass_count INTEGER,
        blind_listen_paragraph_index INTEGER,
        free_play_blind_listen_paragraph_index INTEGER,
        free_play_intensive_listen_sentence_index INTEGER,
        free_play_shadowing_sentence_index INTEGER,
        free_play_difficult_practice_sentence_index INTEGER,
        free_play_retell_paragraph_index INTEGER,
        new_learning_breakpoint_saved_at INTEGER,
        free_play_breakpoint_saved_at INTEGER,
        updated_at INTEGER NOT NULL,
        skipped_sub_stages TEXT NOT NULL DEFAULT '',
        is_paused INTEGER NOT NULL DEFAULT 0
      );
    ''');

    final now = DateTime(2026, 5, 1).millisecondsSinceEpoch;
    final fixtures = <(String, String)>[
      ('audio-firstlearn', 'firstLearn'),
      ('audio-review0', 'review0'),
      ('audio-review1', 'review1'),
      ('audio-review28', 'review28'),
      ('audio-completed', 'completed'),
    ];
    for (final (id, stage) in fixtures) {
      raw.execute(
        '''
        INSERT INTO learning_progresses (
          audio_item_id, current_stage, current_sub_stage, updated_at
        ) VALUES (?, ?, ?, ?)
        ''',
        [id, stage, 'blindListen', now],
      );
    }
    raw.execute('PRAGMA user_version = 33');
  } finally {
    raw.dispose();
  }
}
