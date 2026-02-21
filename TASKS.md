# Fluency 任务清单

> 最后更新：2026-02-21
> 当前焦点：Milestone 2 - 学习流程引擎

---

## 基础设施：迁移到 go_router

- [x] 添加 go_router 依赖，创建路由配置（AppRoutes + appRouterProvider）
- [x] 创建 MainShell 组件（StatefulShellRoute.indexedStack 保持 Tab 状态）
- [x] 创建 PackageInfo Provider（替代构造函数传参）
- [x] 改造 main.dart（MaterialApp.router + 删除 MainScreen）
- [x] 改造 SettingsScreen（用 provider 替代构造函数参数）
- [x] 改造 LearningPlanScreen（接收 ID 参数 + ConsumerStatefulWidget + 自行 loadAudio）
- [x] 迁移所有导航调用（collection_screen、collection_detail_screen、learning_plan_screen）
- [x] 更新测试基础设施（test_app.dart、test_notifiers.dart）
- [x] 更新受影响的测试（settings_screen、learning_plan_screen、widget_test）
- [x] 编写路由测试（app_router_test.dart，9 个测试）
- [x] 全部验证通过（flutter analyze + flutter test 196 通过 + flutter build macos）

**完成时间**: 2026-02-21

---

## 实现单个音频学习流程引擎
- [x] 用户点击一个音频之后，展示一个学习计划表，有两个大阶段：首学、复习，每个大阶段下面是具体的学习步骤：首学：全文盲听-逐句精听-难句跟读-段级复述；复习：第一轮复习(6小时后), 第二轮复习 (1天后)，第三轮复习（3天后），第四轮复习（5天后），第五轮复习（8天后），第六轮复习（11天后），第七轮复习（2周后），第八轮复习（3周后），第九轮复习（4周后）。

**完成时间**: 2026-02-21

- [ ] 设计学习进度数据模型（阶段、小阶段、完成状态、难度）
- [ ] 实现首学流程 — 全文盲听模式
- [ ] 实现首学流程 — 逐句精听+标注模式
- [ ] 实现首学流程 — 难句跟读模式
- [ ] 实现首学流程 — 段级复述模式
- [ ] 实现复习调度引擎（R1-R28 间隔计算与提醒）
- [ ] 实现学习进度记录与断点续学


## 基础设施：SharedPreferences → Drift 迁移

- [x] 添加 drift, sqlite3_flutter_libs, drift_dev 依赖
- [x] 定义 5 张表（audio_items, collections, collection_audio_items, bookmarks, playback_states）+ 枚举 + 数据库 + 索引
- [x] 编写 4 个 DAO（AudioItemDao, CollectionDao, BookmarkDao, PlaybackStateDao）+ 29 个 DAO 测试
- [x] 编写 SP → Drift 一次性迁移服务 + 7 个迁移测试
- [x] 改造 main.dart（数据库初始化 + 迁移 + Provider override）
- [x] 改造 AudioLibrary Provider（数据源 → AudioItemDao）
- [x] 改造 Collection Provider + Collection 模型（junction 表 + audioIdsMap 缓存 + 移除 audioItemIds）
- [x] 改造 BookmarkManager（数据源 → BookmarkDao，增强版书签存 text/startTime/endTime）
- [x] 改造 PlaybackStateStorage（数据源 → PlaybackStateDao，精简为只存 position_ms）
- [x] 清理 StorageService（仅保留 PlaybackSettings 方法）

**完成时间**: 2026-02-21

---

## 导航重构

- [x] 将四个 Tab 从 Library | Collections | Player | Account 改为 合集 | 学习 | 收藏 | 我的，默认是学习

**完成时间**: 2026-02-20

## 优化 UI

- [x] 创建主题系统 `lib/theme/app_theme.dart`（颜色、组件主题、间距常量、语义色）
- [x] 接入主题系统到 main.dart，优化导航栏图标和样式
- [x] 优化播放器页面（控制面板、句子卡片、进度条、图标颜色统一）
- [x] 优化合集页面（卡片视觉、图标颜色、空状态 CTA）
- [x] 优化音频库页面（图标颜色、elevation 统一、空状态）
- [x] 优化设置页面和对话框（Card 分组、间距统一）
- [x] 优化占位页面 StudyScreen / FavoritesScreen 空状态
- [x] 更新测试适配 UI 变更，运行全部验证命令
- [x] 参考 Learna AI 风格视觉改造（蓝色主色调、浅灰背景、卡片去边框加微弱阴影、圆角增大）
- [x] 导航栏选中态蓝色 + 设置页面布局优化（分割线、单行 trailing 值）

**完成时间**: 2026-02-21

## 优化合集 Tab

- [x] 图标颜色优化：folder/audiotrack 图标从 `onPrimaryContainer` 改为 `primary`（蓝色）
- [x] 音频菜单改为"重命名 + 删除"（原仅"从合集移除"）
- [x] 上传同名音频到同一合集时弹出错误提醒
- [x] 修复字幕标记显示错误：loadLibrary 增加字幕文件存在性验证；AudioItem.copyWith 支持显式 null transcriptPath
- [x] 去掉图标 CircleAvatar 背景色（backgroundColor 改为 transparent）
- [x] 修复合集音频数量不正确：删除音频时清理合集引用 + 启动时清理过期引用

**完成时间**: 2026-02-21

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

**完成时间**: 2026-XX-XX
-->
