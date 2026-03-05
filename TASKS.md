# Fluency 任务清单

> 最后更新：2026-03-05
> 当前焦点：管理字幕功能（AI 转录）

## 历史归档
- [Milestone 2 - 学习流程引擎](./docs/tasks-archive/milestone-2-learning-engine.md)

---

## 已完成：管理字幕功能

### Phase 1：底部弹窗 + 本地上传 + 删除字幕

- [x] #1 数据模型扩展（TranscriptSource 枚举 + AudioItem 新字段 + DB 迁移 v12→v13）
- [x] #2 管理字幕底部弹窗 UI 骨架（ManageSubtitlesSheet）
- [x] #3 菜单入口替换 + 本地上传集成
- [x] #4 删除字幕功能
- [x] #5 国际化（25 个新 key）

  **完成时间**: 2026-03-05

### Phase 2：AI 转录完整流程

- [x] #6 SHA256 计算工具（`lib/utils/audio_fingerprint.dart`，Isolate + crypto 包）
- [x] #7 后端：user_audios + user_audio_transcripts 表 + 5 个 HTTP API Routes
- [x] #8 转录 API 客户端（`lib/services/transcription_api_client.dart`，Dio）
- [x] #9 SRT 格式转换工具（`lib/utils/srt_generator.dart`）
- [x] #10 转录状态 Provider（`lib/providers/transcription_task_provider.dart`，keepAlive）
- [x] #11 AI 转录 UI 集成（进度显示、语言禁用逻辑、覆盖确认）
- [x] #12 AudioListTile 后台转录进度指示

  **完成时间**: 2026-03-05

### 测试覆盖

- [x] AudioItem 模型测试（31 个，含新字段 copyWith + 序列化）
- [x] ManageSubtitlesSheet Widget 测试（10 个）
- [x] SRT 格式转换测试（8 个）
- [x] SHA256 计算工具测试（5 个）
- [x] 转录 API 客户端测试（11 个）
- [x] TranscriptionTaskManager 单元测试（15 个）
- [x] 管理字幕集成测试（7 个 E2E 场景）

  **完成时间**: 2026-03-05

### UI 优化与错误处理

- [x] #13 管理字幕弹窗 UI 优化（卡片式选项、删除按钮移至标题栏）
- [x] #14 简化转录错误提示（短码 + i18n 本地化）
- [x] #15 移除字幕来源状态标签（避免歧义）
- [x] #16 提取全局 API 配置（`lib/config/api_config.dart`）
- [x] #17 iOS 原生网络权限触发（Method Channel + URLSession）
- [x] #18 iOS ATS 例外配置（NSAllowsArbitraryLoads）

  **完成时间**: 2026-03-05

### 验证结果

- flutter analyze: 通过（info，无错误）
- flutter test: 全部通过
- flutter test integration_test -d macos: 全部通过（61 个）
- flutter build macos: 通过

---

## 待完成：学习进度记录与断点续学
- [ ] 实现学习进度记录与断点续学

## 用户体验优化
- [ ] 在倒计时阶段（逐句精听、跟读、复述、难句补练等），播放按钮的行为改成再播放一遍（播放时取消已有倒计时，播放完成后重新倒计时），另外显示两个控制倒计时的按钮：暂停计时，和快进
- [ ] 在进入一个学习阶段的时候，显示预估时长
- [ ] 难句跟读页面，精听页面，难句星标放在右侧
- [ ] 学习页面左上角的返回按钮改成 X，并且不用支持滑动返回效果
- [ ] 在自由学习模式下，学完也弹窗，提醒用户完成或再学一遍
- [ ] 学习过程中，如果息屏了，要后台播放
- [ ] 统计用户每日的学习时长
- [ ] 在所有界面支持快捷键控制播放、暂停、上一句、下一句
- [ ] 在用户打开设置界面的时候要暂停
- [ ] 在段级复述页面，把连续的隐藏的文字的蒙版连续显示
- [ ] 优化段级复述页面的复述时间的计算逻辑，改成三倍段落长度

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
