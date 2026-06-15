# Echo Loop 任务清单

> 最后更新：2026-06-15（已归档已完成任务至 Milestone 5）
> 当前焦点：Android 结束录音闪退（离线 ASR / Silero VAD）——**仍未解决**

## 已修复：字幕丢失 + 冷重启音频显示未下载（同一根因）

- [x] **根因**：`AudioItemDao.batchInsert` 用 `InsertMode.insertOrReplace`，在 SQLite 是整行 **DELETE+INSERT**。由 commit `3768a131` 把 `_upsertItem` 改走批量 `insertOrReplace` 引入。两个后果：
  1. `_audioItemToCompanion` 不携带 `transcript_srt` / `word_timestamps_json`，整行替换把这两列抹成 NULL → 「句数词数还在但字幕没了」（编辑字幕/自由练习/盲听都拿不到字幕）。
  2. DELETE 行触发所有子表 `ON DELETE CASCADE`（`collection_audio_items` / `bookmarks` / `playback_states` / `learning_progresses`）→ 音频被静默移出合集、丢书签与学习进度。冷启动若有旧绝对路径音频触发 `hasMigratedItems`，会对全部音频回写一遍，整片合集 junction 被删空 → 官方/podcast 音频在详情页"消失"并回落到下载态 → 显示「下载按钮」。
  - 任何走 `_upsertItem` 的回写都会触发：`updateAudioItem` / `togglePin` / `checkAudioContent`（下载完成后立即调用）/ `backfill*` / 路径迁移。
  - **修复**：`batchInsert` 改为逐条 `insert(..., onConflict: DoUpdate((_) => entry))`（INSERT … ON CONFLICT DO UPDATE），已存在行只更新 companion 携带的列、不删行 → 大字段保留、不触发级联。
  - **测试**：`test/database/dao_test.dart` 新增 2 个回归用例（保留 transcript_srt/word_timestamps 大字段；不级联删除合集 junction/书签），旧实现下精确 fail、修复后通过。
  - **注意**：已被旧版本抹掉 `transcript_srt` 的存量数据无法从统计反推；有遗留 `transcriptPath` 文件的可由启动 `backfillTranscriptSrt` 恢复，否则需重新下载/转录。被级联删空的合集 junction 由下次官方 sync 重建。

  **完成时间**: 2026-06-15

---

## 待办：Android 离线 ASR 结束录音仍闪退

- [ ] 崩在 sherpa-onnx 的 Silero VAD native 推理（`_extractSpeechWithVad`）；cpu provider、AudioRecord 串行、自适应跳过 VAD 三种尝试均未解决（skip-VAD 真机连续崩多次已撤销）。诊断设施已保留，待真机 **logcat + `/data/tombstones`** 确诊信号/栈后再定方案。详见 CLAUDE.md §7.4。

---

## 进行中：启动埋点附带 4 类授权状态

PostHog 自动事件 `Application Opened` 不带任何系统授权属性，无法做"授权状态 vs 留存"分析。本期把麦克风 / 语音识别 / 通知 / 网络 4 类授权状态作为 PostHog **super properties + person properties + 自定义事件 `app_permission_snapshot`** 上报；不修改任何现有权限弹窗时机。

### 任务拆分（一次一项）
- [x] **任务 1：埋点常量 + PermissionSnapshot helper + 单测**
  - `event_names.dart`：新增 `Events.appPermissionSnapshot` + 4 个 EventParams（mic/speech/notification/network）
  - `lib/analytics/permission_snapshot.dart`：不可变值对象 + `toEventParams()` + 静态 `capture(prefs, {probe})`
  - `PermissionProbe` 抽象 + `DefaultPermissionProbe` 实现（mic/speech 走 `SpeechPracticePlatform`，notification 走 `flutter_local_notifications`；网络读 SP `network_data_task_succeeded`，仅 iOS 有意义，其他平台 `not_applicable`）
  - 网络状态映射：iOS 上 SP 缺失 → `notDetermined`，true → `granted`，**不引入假 denied 推断**
  - `test/analytics/permission_snapshot_test.dart`：11 个测试覆盖 toEventParams 映射 / 网络状态平台分支 / probe 容错 / 状态常量
  
  **完成时间**: 2026-04-26
- [x] **任务 2：iOS 网络 channel 改造 + main.dart 写 SP**
  - `ios/Runner/AppDelegate.swift:1144-1170` channel handler 返回 `{ok, reason}` + `hasResponded` Once 守护 + 5s 超时（避免 method channel 多次 result 踩坑，参考 CLAUDE.md §7.2）
  - 把原 `_triggerNetworkPermission` 抽到 `lib/services/network_permission_trigger.dart` 的 `NetworkPermissionTrigger.trigger(prefs, url)`，便于单测；成功时写 SP `network_data_task_succeeded = true`，**失败/超时/异常不写 SP**（防止飞行模式 / 弱网 / 服务端故障被误判为 denied）
  - `lib/main.dart` 删除内联 `_triggerNetworkPermission`，启动调用改为 `NetworkPermissionTrigger.trigger(prefs, apiBaseUrl)`，并清理掉不再用的 `package:flutter/services.dart` import
  - `test/services/network_permission_trigger_test.dart`：7 个测试覆盖 ok=true/false/null/缺字段/抛错/幂等/失败不回退
  
  **完成时间**: 2026-04-26
- [x] **任务 3：AnalyticsChannel.registerSuperProperties + PostHog 实现 + 其他 channel no-op + AnalyticsService 转发**
  - `analytics_channel.dart` 接口新增 `registerSuperProperties(Map<String, Object>)` + 中文文档注释（解释与 setUserProperty 的区别）
  - `posthog_channel.dart` 实现：循环调用 `Posthog().register(key, value)`（5.x SDK 一次接受一个 key/value）
  - `firebase_channel.dart` / `umeng_channel.dart` no-op 实现 + 注释说明为何
  - `log_only_channel.dart` 实现：把 `key=value` 列表打到 `AppLogger`
  - `analytics_service.dart` 加 `registerSuperProperties` 方法：consent gate + try/catch 兜底（埋点不影响主业务）
  - 更新所有现有 mock channel 实现新方法（`MockChannel` / `_RecordingChannel`）
  - 新增 4 个测试：转发 / consent 拦截 / 异常静默吞 / LogOnly 日志格式
  
  **完成时间**: 2026-04-26
- [x] **任务 4：main.dart 启动序列接入 + Onboarding 末页权限预告 label**
  - `lib/analytics/permission_snapshot.dart` 新增 `PermissionSnapshotReporting` extension on `AnalyticsService`，把"super properties + 4 个 person property + `app_permission_snapshot` 事件"三路写入封装在一个方法里
  - `lib/main.dart` 在 `initAnalytics` 之后 `await PermissionSnapshot.capture(prefs)` → `await analyticsService.reportPermissionSnapshot(snapshot)`，用 try/catch 包裹避免影响启动
  - Onboarding 方法论页（summary）"开始学习"按钮上方加权限预告：小号提示 + 两个 `Wrap` chip（`notifications_outlined` / `wifi_outlined` + 短 label "系统通知" / "网络权限"），独立 Padding 区不滚动总能见，仅展示无交互
  - 网络权限保持启动即触发（保留原行为）：埋点上报依赖网络通畅，推迟到 Onboarding 完成会丢事件；系统弹窗具体呈现时机由 OS 决定
  - ARB 新增 3 个 key（zh + en）
  - 测试：`permission_snapshot_test.dart` 加 2 个测试覆盖 extension（三路写入 / consent 拦截）；`onboarding_survey_screen_test.dart` 加权限 label 渲染断言
  
  **完成时间**: 2026-04-26
- [ ] 任务 5：手动验证（PostHog Live Events / Persons / Insights）

### 范围内不做
- 自定义教育弹窗 / 调整任何现有权限弹窗时机 / 跳系统设置引导 / AppLifecycleState.resumed 监听 / Android 13+ 通知权限 UI 验证

---

## 录音+识别功能（进行中）

- [x] **段落复述评级开关**
  
  **完成时间**: 2026-06-15 16:04 +0800
  
  学习设置页新增「计算并显示复述评级」开关，默认开启。关闭后段落复述只保留录音和自动回听，不再启用识别、转录、匹配或评分，胶囊降级为「录音」胶囊（不显示评级）；段间停顿按无评分策略计算。
  - [x] `LearningSettings` 新增 `retellRatingEnabled`，使用 `learning_retell_rating_enabled` 持久化，默认 true
  - [x] 段落复述录音关闭评级时跳过 ASR/transcript/matcher/embedding，只保存录音 attempt
  - [x] 关闭评级时胶囊降级为「录音」胶囊（`unavailable + filePath`），仍挂载并复用 badge controller
  - [x] 补充学习设置、复述录音 controller、复述页面回归测试
  - [x] 2026-06-15 16:08 +0800：调整学习设置页复述评级开关文案为「复述时关闭评级」，描述改为关闭后只保留录音回听且不再显示评分
  - [x] 2026-06-15：修复关闭评级时自动回听不显示停止图标的 bug——删除绕过 badge 的 `_playAttemptRecordingDirectly` 直连路径，开启/关闭统一走 `_ratingBadgeController.play()`，使「录音」胶囊在自动回听时正确显示停止图标且可点停止；修正被该 bug 固化的测试断言；补全 `_TestLearningSettingsNotifier.setRetellRatingEnabled` 缺失实现
  - [x] `flutter analyze lib/providers/learning_settings_provider.dart lib/providers/retell_recording_controller_provider.dart lib/screens/learning_settings_screen.dart lib/screens/retell_player_screen.dart lib/widgets/common/repeat_practice_panel.dart lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart test/providers/learning_settings_provider_test.dart test/providers/retell_recording_controller_test.dart test/screens/learning_settings_screen_test.dart test/screens/retell_player_screen_test.dart`：No issues found
  - [x] `flutter test test/providers/learning_settings_provider_test.dart test/screens/learning_settings_screen_test.dart test/providers/retell_recording_controller_test.dart test/screens/retell_player_screen_test.dart`：39 passed
  - [ ] `scripts/check.sh`：未跑；本次为学习设置与段落复述局部行为改动，按规范仅运行直接相关检查

- [ ] 段落复述页面复用同一模块接入录音识别能力。

---

## 优化UI（进行中）

- [ ] 支持自定义背景、背景音

---

## 用户体验优化（待办）

- [ ] 计算每个任务的估计学习时长，显示在音频学习计划页以及学习tab页的任务item上。没有学习的显示估计时长，已经学习的显示真实的耗时。
- [ ] 学习 tab 页面点击学习或复习要直接打开学习页面，跳过学习计划页面
- [ ] 在学习tab，增加显示今日完成任务（如果有），默认折叠起来，避免用户不知道今天都学了哪些
- [ ] 给句子增加复制功能，在移动端长按，在PC端右键，弹出一个菜单，现在只有一个选项就是复制。

---

## 加入特效

- [ ] 一个句子/单词播放完成，一遍播放完成，播放音效
- [ ] 任务完成，播放动画+音效

---

## 埋点

- [ ] 支持中国大陆区
- [ ] 支持全球

---

## 历史归档
- [Milestone 2 - 学习流程引擎](./docs/tasks-archive/milestone-2-learning-engine.md)
- [Milestone 3 - 收藏与标注体系 + 体验优化](./docs/tasks-archive/milestone-3-completed.md)
- [Milestone 4 - 功能完善与体验打磨](./docs/tasks-archive/milestone-4-features-and-polish.md)
- [Milestone 5 - 登录认证 / Podcast / 离线 ASR / 字幕编辑器](./docs/tasks-archive/milestone-5-completed.md)

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
