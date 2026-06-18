/// 自由练习播放器的「下一步」决策纯函数。
///
/// 把「越过当前句尾后该做什么」从命令式协程中剥离为无副作用的纯函数，
/// 便于单元测试覆盖全部分支。Provider 采用永不 setClip 的 gapless 播放：
/// 监听 positionStream，当播放头越过当前监听句的 endTime 时把业务真相源快照喂给
/// [decideNext]，再根据返回的 [NextAction] 驱动引擎（seek / play / stop）。
///
/// 支持两组相互独立、可同时开启的循环：
/// - 整篇循环（[loopWhole]）：整篇播完后回到开头重播，总共播 [wholeLoopCount] 遍。
/// - 单句循环（[loopSentence]）：每句重复 [sentenceLoopCount] 次后进下一句。
///
/// 整篇自然播完（gapless 整段 completed、未开单句循环/不监听句尾）由 Provider 直接
/// 调用 [shouldLoopWhole] 判定，不走 [decideNext]。
library;

/// [decideNext] 的决策结果。
sealed class NextAction {
  const NextAction();
}

/// 重播当前句（单句循环）。[pauseBefore] 为重播前的停顿。
class ReplayCurrent extends NextAction {
  /// 执行前的间隔停顿。
  final Duration pauseBefore;

  const ReplayCurrent({this.pauseBefore = Duration.zero});
}

/// 跳到播放列表中第 [position] 条（顺次推进或回卷到开头）。
/// [pauseBefore] 为跳转前的停顿。
class GoToPosition extends NextAction {
  /// 目标在播放列表中的序号（0-based）。
  final int position;

  /// 执行前的间隔停顿。
  final Duration pauseBefore;

  const GoToPosition(this.position, {this.pauseBefore = Duration.zero});
}

/// 停止播放。
class StopPlayback extends NextAction {
  const StopPlayback();
}

/// 决定「越过当前监听句尾」后的下一步动作。
///
/// gapless 播放下，单句循环/收藏跳播靠 positionStream 越界检测触发，每次越过当前
/// 监听句的 endTime 调用一次。入参均为业务真相源的快照，函数无副作用：
/// - [loopSentence]/[sentenceLoopCount]/[sentenceInterval]：单句循环参数
///   （[sentenceLoopCount] 为 `0` 表示无限重复当前句）。
/// - [loopWhole]/[wholeLoopCount]/[wholeInterval]：整篇循环参数
///   （[wholeLoopCount] 为 `0` 表示无限循环整篇）。
/// - [sentenceRepeatsDone]：当前句已完成播放次数（含刚越界这次，>=1）。
/// - [wholeLoopsDone]：整篇已完成遍数（本次计入前的值）。
/// - [currentPos]：当前句在播放列表中的序号（0-based）。
/// - [playableCount]：播放列表长度（全文=句子数；收藏=收藏句数）。
NextAction decideNext({
  required bool loopSentence,
  required int sentenceLoopCount,
  required Duration sentenceInterval,
  required bool loopWhole,
  required int wholeLoopCount,
  required Duration wholeInterval,
  required int sentenceRepeatsDone,
  required int wholeLoopsDone,
  required int currentPos,
  required int playableCount,
}) {
  if (playableCount <= 0) return const StopPlayback();

  final isLast = currentPos >= playableCount - 1;

  // 1) 先把当前句重复够（单句循环）。
  if (loopSentence &&
      (sentenceLoopCount == 0 || sentenceRepeatsDone < sentenceLoopCount)) {
    return ReplayCurrent(pauseBefore: sentenceInterval);
  }

  // 2) 当前句已重复够 → 推进。
  if (!isLast) {
    // 句间间隔：单句循环开则用其间隔；仅收藏逐句跳播时不停顿。
    final gap = loopSentence ? sentenceInterval : Duration.zero;
    return GoToPosition(currentPos + 1, pauseBefore: gap);
  }

  // 3) 到列表末尾 → 整篇循环判定。
  if (shouldLoopWhole(loopWhole, wholeLoopCount, wholeLoopsDone)) {
    return GoToPosition(0, pauseBefore: wholeInterval);
  }
  return const StopPlayback();
}

/// 是否应继续整篇循环：开启且（无限 或 已完成遍数未达目标）。
///
/// 既用于 [decideNext] 末句判定，也供 Provider 在 gapless 整段自然 completed 时
/// 直接判定（此时不监听句尾，不走 [decideNext]）。
bool shouldLoopWhole(bool loopWhole, int wholeLoopCount, int wholeLoopsDone) {
  if (!loopWhole) return false;
  if (wholeLoopCount == 0) return true; // ∞
  return wholeLoopsDone < wholeLoopCount;
}
