# CLAUDE.md - Claude Code 工作规范

## 0 目标

你是 Claude Code，在本仓库内协助完成开发任务。你的首要目标是按计划稳定推进，并保持改动可验证。

**核心原则**：
1. 文件驱动 — 决策写进 PLAN.md / TASKS.md，不依赖聊天记忆
2. 单任务聚焦 — 一次只做一件事，做完再下一件
3. 测试先行 — 先写测试定义预期，再写实现
4. 功能解耦 — 每个模块独立可测，不耦合无关逻辑；单文件 ≤500 行，单函数 ≤50 行
5. 逐步验证 — 每次改动立即可运行、可检查，不攒大变更
6. 文档完善 - 公共接口、核心逻辑必须有文档/注释，符合项目规范
7. 文档同步 — 代码改完，立刻更新对应文档状态

---

## 1 单一事实来源

本项目的计划与任务以以下文件为准，优先级从高到低：

1. **CLAUDE.md** - 工作规范和执行流程（本文件）
2. **PLAN.md** - 项目概述、里程碑、技术设计
3. **TASKS.md** - 当前待完成任务队列

**冲突处理规则**：
- 如果聊天指令与上述文件冲突，**必须先更新文件再执行代码改动**
- 如果发现需求不清、缺少信息或出现新约束，**先写回 PLAN.md 或 TASKS.md**
- 如果文件间存在冲突，以优先级高的为准

---

## 2 启动流程（每个会话必须执行）

⚠️ **强制要求**：开始任何工作前，必须按顺序完成以下步骤：

### 步骤 1: 读取规划文档
```bash
# 读取项目规划
cat PLAN.md

# 理解以下内容：
# - 当前处于哪个阶段（Phase 1/2/3）
# - 本阶段的目标和范围
# - 验收标准是什么
# - 当前的风险和假设
```

### 步骤 2: 读取任务队列
```bash
# 读取任务清单
cat TASKS.md

# 选择任务：
# - 优先选择位置靠前的任务
# - 检查依赖关系（依赖的任务必须已完成）
```

### 步骤 3: 输出执行计划
在开始修改代码前，必须输出一段简短执行计划：

```markdown
## 执行计划

**当前任务**: [任务标题]

**将运行的验证命令**:
- pnpm lint
- pnpm test path/to/test.ts
- pnpm run i18n:check
```

### 步骤 4: 等待用户确认
输出执行计划后，等待用户回复确认，再开始修改代码。

---

## 3 执行规则

### 3.1 任务执行原则

1. **一次只做一个任务**：不允许并行多个任务
2. **优先最小改动**：避免大范围重构，除非任务明确要求
3. **只改相关文件**：不允许改动与当前任务无关的文件
4. **必须有验证**：任何新增行为必须有对应测试或最小验证步骤

### 3.2 发现新问题时

如果在执行过程中发现：
- 需求不清晰
- 缺少关键信息
- 出现新的技术约束
- 设计决策需要变更

**必须先暂停**，执行以下步骤：

1. **更新 PLAN.md**：
   - 如果是范围变更，更新"范围界定"章节
   - 如果是风险发现，更新"风险与假设"章节
   - 如果是技术决策，更新"技术设计文档"章节

2. **更新 TASKS.md**：
   - 如果需要拆分任务，添加新的子任务
   - 如果需要调整优先级，移动任务位置
   - 如果发现依赖关系，更新依赖字段

3. **通知用户**：说明发现的问题和已做的文档更新

4. **再继续改代码**：确保文档和代码保持同步

---

## 4 收尾流程（每次完成任务必须执行）

⚠️ **强制要求**：完成当前任务后，必须按顺序完成以下步骤：

### 步骤 1: 运行验证命令
```bash
# 运行 TASKS.md 中该任务的 Done Definition 命令
# 记录所有命令的输出结果
```

### 步骤 2: 更新 TASKS.md
```markdown
# 必须完成：
1. 勾选已完成任务（- [x]）
2. 在任务下添加完成记录：

**完成时间**: 2026-01-31
**Commit**: [hash]
**变更点**:
- 修改了 X 文件，实现 Y 功能
- 添加了 Z 测试，覆盖 A 场景

**验收结果**:
✅ pnpm lint - 通过
✅ pnpm test - 12/12 通过
✅ 功能测试 - 符合预期
```

### 步骤 3: 更新 PLAN.md（如有需要）
如果本次任务导致里程碑进度变化，必须更新 PLAN.md：

```markdown
# 可能需要更新的章节：
- 当前阶段状态（Phase X）
- 里程碑完成情况（✅/🚧/📋）
- 风险与假设的验证结果
- 技术设计的实际实现细节
```

### 步骤 4: 提交代码
```bash
# 遵循 Commit 消息规范
git add .
git commit -m "FEAT: 任务标题

详细描述变更内容。

Ref: P0-X

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### 步骤 5: 输出完成摘要
```markdown
## 完成摘要

**任务编号**: P0-X
**任务标题**: [标题]

**修改的文件** (X 个):
- path/to/file1.ts (+50 -10)
- path/to/file2.tsx (+30 -5)

**关键变更点**:
1. 实现了 X 功能
2. 添加了 Y 测试
3. 修复了 Z 问题

**验收结果**:
✅ 所有验证命令通过
✅ 符合 Done Definition 标准

**下一步建议**:
- 继续执行 P0-Y 任务
- 或等待用户指示
```

---

## 5 TASKS.md 归档规则

### 5.1 何时触发归档

满足以下任一条件时，**必须执行归档**：

1. **里程碑完成**：当 PLAN.md 中的某个 Milestone 完成时
2. **文件过大**：TASKS.md 超过 200 行
3. **任务过多**：已完成任务超过 30 条
4. **手动触发**：用户明确要求归档

### 5.2 归档执行步骤

#### 步骤 1: 创建归档文件
```bash
# 归档文件命名规范：docs/tasks-archive/milestone-X-completed.md
# 例如：
# - docs/tasks-archive/milestone-1-mvp-completed.md
# - docs/tasks-archive/milestone-2-production-ready.md
```

#### 步骤 2: 归档文件内容
```markdown
# Milestone X 已完成任务归档

> 归档时间：YYYY-MM-DD
> 里程碑：Milestone X - [里程碑名称]
> 完成任务数：XX 个

## 归档摘要

本里程碑完成的主要工作：
- 核心功能 1（P0-1 到 P0-3）
- 核心功能 2（P1-1 到 P1-5）
- 关键改动：XXX

验收标准达成情况：
- ✅ 标准 1
- ✅ 标准 2

## P0 已完成任务

### ✅ P0-1: [任务标题]
**完成时间**: YYYY-MM-DD
**Commit**: [hash]
**关键改动**: 简短描述
**验收命令**:
```bash
pnpm lint && pnpm test
```
**结果**: 通过

### ✅ P0-2: [任务标题]
...

## P1 已完成任务

...
```

#### 步骤 3: 清理 TASKS.md
```markdown
# 将已完成任务全部移除
# 仅保留：
1. P0 必须做（未完成）
2. P1 应该做（未完成）
3. P2 可选做（未完成）

# 在 TASKS.md 顶部添加归档链接
## 历史归档
- [Milestone 1 - MVP 发布](./docs/tasks-archive/milestone-1-mvp-completed.md)
- [Milestone 2 - 生产就绪](./docs/tasks-archive/milestone-2-production-ready.md)
```

#### 步骤 4: 更新 PLAN.md
```markdown
# 标记里程碑为已完成
### ✅ Milestone X: [名称] (完成时间)

# 更新当前阶段
### Phase X+1: [下一阶段名称] 🚧 进行中
```

### 5.3 归档后的 TASKS.md 结构

归档后，TASKS.md 应保持精简：

```markdown
# Fluency 任务清单

> 最后更新：YYYY-MM-DD
> 当前焦点：Phase X - [阶段名称]

## 历史归档
- [Milestone 1 - MVP 发布](./docs/tasks-archive/milestone-1-mvp-completed.md)

---

## P0 必须做（阻塞发布）
[仅保留 3-7 个未完成任务]

## P1 应该做（提升质量）
[仅保留 10-20 个未完成任务]

## P2 可选做（锦上添花）
[仅保留少量占位任务]
```

---

## 6 输出格式要求

### 6.1 开始执行前必须输出

```markdown
## 执行计划

**当前任务**: P0-X - [任务标题]
**依赖检查**: 无依赖 / 依赖 P0-Y（已完成）
**预计工时**: X 小时

**文件清单**:
- path/to/file1.ts
- path/to/file2.tsx

**验证命令**:
- pnpm lint
- pnpm test path/to/test.ts
```

### 6.2 完成后必须输出

```markdown
## 完成摘要

**完成情况**: ✅ 已完成 / ⚠️ 部分完成 / ❌ 失败

**验收结果**:
✅ pnpm lint - 通过
✅ pnpm test - 通过
✅ 功能测试 - 符合预期

**下一步建议**:
- 继续执行 P0-Y 任务
- 或需要用户确认 X 问题
```

---

## 7 安全边界

在执行任何操作前，必须遵守以下安全规则：

### 7.1 禁止操作

❌ **严格禁止**以下操作：
1. 删除 10 个以上文件（除非归档操作）
2. 执行 `rm -rf` 等破坏性命令
3. 修改 `.git/` 目录
4. 修改 `node_modules/` 目录
5. 直接修改生产数据库
6. 提交包含密钥的代码

### 7.2 高风险操作必须先说明

⚠️ **需要说明风险和回滚方案**的操作：
1. 数据库迁移（schema 变更）
2. 删除或重命名数据库字段
3. 修改环境变量配置
4. 修改 CI/CD 配置
5. 修改 `.env.example` 或密钥相关文件

**说明格式**：
```markdown
## 风险说明

**操作**: 数据库迁移 - 添加 usage 表

**影响范围**:
- 新增表 `transcription_usage`
- 不影响现有表

**回滚方案**:
```bash
# 如果出错，执行：
pnpm db:rollback
```

**是否继续**: 等待用户确认
```

### 7.3 敏感信息处理

🔒 **必须保护**的敏感信息：
- API Keys（Deepgram, OpenAI 等）
- 数据库连接字符串
- JWT Secret
- Stripe 密钥
- 用户个人数据

**处理规则**：
1. 使用环境变量，不硬编码
2. 不记录到日志
3. 不提交到 git
4. 示例配置使用占位符

---

## 8 代码规范

### 8.1 基本规范

- **中文优先**: 所有代码注释和 git commit 消息必须使用中文
- **文件大小限制**: 单个源文件不超过 500 行
- **类型安全**: 优先使用类型安全的编程方式
- **模块化设计**: 功能要模块化，提高可复用性，方便迁移到其他项目

### 8.2 API 设计原则

优先使用 Next.js Server Actions 进行数据交互。

**仅在以下明确场景使用 API 端点**：
- 提供给第三方调用
- Webhook 回调
- 需要流式响应 (streaming)

### 8.3 Commit 消息规范

格式: `<类型>: <简短描述>`

**常用类型**:
- `FEAT`: 新功能
- `FIX`: Bug 修复
- `REFACTOR`: 代码重构
- `DOCS`: 文档更新
- `TEST`: 测试相关
- `CHORE`: 构建/工具链变更

**完整示例**:
```
FEAT: 添加 OpenAI Whisper 转录 Provider

实现 OpenAI API 集成，支持多语言转录。

变更：
- 新增 packages/transcription/providers/openai.ts
- 更新 ProviderSelector 支持 OpenAI
- 添加 OpenAI 转录测试

Ref: P1-3

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

---

## 9 工作流规则

### 9.1 代码修改流程

1. 修改代码后，运行 `pnpm lint` 检查
2. 如发现 lint 错误：
   - 优先修复错误
   - 如果错误不影响代码理解且修复成本高，可添加 ignore 注释
3. 所有类型错误必须修复，不能忽略

### 9.2 提交前检查清单

执行 git commit 前，必须完成以下检查：

- [ ] **i18n 一致性检查**: `pnpm run i18n:check`
  - 开发过程中，只需保证 `en` 语言文件完整
  - 其他语言可以稍后补充
- [ ] **Lint 检查**: `pnpm lint` 无错误
- [ ] **类型检查**: TypeScript 编译通过
- [ ] **相关测试**: 新增功能有对应测试
- [ ] **文档更新**: TASKS.md 状态已更新

### 9.3 Monorepo 工作流

本项目使用 Turborepo 管理 monorepo:
- `apps/`: 应用程序（Next.js 主应用）
- `packages/`: 可复用的包（22 个通用库包）

**跨包依赖**:
- 使用 workspace 协议: `"@repo/database": "workspace:*"`
- 添加依赖后需要重新运行 `pnpm install`

**常用命令**:
- `pnpm dev`: 启动所有开发服务器
- `pnpm build`: 构建所有包和应用
- `pnpm lint`: 运行所有包的 lint
- `pnpm test`: 运行所有测试

---

## 10 项目特定知识

### 10.1 i18n 系统

- 使用 `next-intl` + `languine` 管理国际化
- 翻译文件位置: `packages/i18n/locales/`
- 修改文案后必须运行 `pnpm run i18n:check` 验证一致性

### 10.2 Lint 和格式化

- 使用 `ultracite/biome` 进行 lint 和格式化
- 配置文件: `biome.json`
- 不要使用 ESLint 或 Prettier，项目已统一使用 Biome

### 10.3 数据库

- 使用 Drizzle ORM
- Schema 位置: `packages/database/schema.ts`
- 修改 schema 后运行: `pnpm db:generate && pnpm db:migrate`

### 10.4 测试规范

- 使用 Vitest 作为测试框架
- 测试文件命名: `*.test.ts` 或 `*.spec.ts`
- 每个新功能或 bug 修复应该包含相应的测试

### 10.5 WaveSurfer.js 使用规范

本项目使用 WaveSurfer.js v7 + Regions 插件实现音频编辑器。**修改波形编辑器前必读**: [docs/wavesurfer-usage.md](./docs/wavesurfer-usage.md)

关键陷阱：
- **不要用 `region-in`/`region-out` 管理 activeRegion**：相邻 region 边界会触发意外切换
- **`region-clicked` 的 `e.stopPropagation()` 不能阻止 `interaction` 事件**：它们在不同事件总线上，需要时间戳去重
- **`setTime()` 前必须先 `pause()`**：否则 `dragToSeek` 的异步 seek 可能覆盖位置
- **闭包变量不能跨 hook 共享**：跨 `useEffect`/`useImperativeHandle` 的状态必须用 ref

---

## 11 技能 (Skills)

使用以下技能简化常见工作流:
- `/commit-workflow`: 标准化 git 提交流程
- `/monorepo-navigation`: 理解和导航 monorepo 结构
- `/test-workflow`: 测试编写和运行指南
- `/fix-issue`: 自动化问题修复工作流

---

## 12 快速启动命令

每次新会话开始时，用户只需发送：

```
按 CLAUDE.md 的启动流程开始，先读 PLAN.md 和 TASKS.md，从 P0 必须做的第一条未完成任务做起，按收尾流程更新文件并给出验证结果。
```

Claude Code 会自动：
1. ✅ 读取 PLAN.md 理解当前阶段
2. ✅ 读取 TASKS.md 选择任务
3. ✅ 输出执行计划等待确认
4. ✅ 执行任务
5. ✅ 运行验证命令
6. ✅ 更新 TASKS.md 和 PLAN.md
7. ✅ 提交代码
8. ✅ 输出完成摘要

---

**文档版本**: v2.0
**创建时间**: 2026-01-31
**维护者**: Claude Code + Fluency Team
