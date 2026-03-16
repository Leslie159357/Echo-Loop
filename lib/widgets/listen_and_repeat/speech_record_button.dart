/// 跟读录音按钮组件。
///
/// 大圆形按钮 + 话筒图标，录音中在图标两侧显示 3 层音波弧线：
/// - **待录音**（idle / waitingForUser）：柔和轮廓 + 话筒图标，无动画
/// - **等待说话**（awaitingSpeech）：红色按钮 + 慢速音波
/// - **正在说话**（speaking）：红色按钮 + 快速音波
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../providers/listen_and_repeat_turn_controller_provider.dart';

/// 按钮直径（与播放按钮一致）。
const _buttonSize = 56.0;
const _iconSize = 28.0;

/// 录音按钮组件。
class SpeechRecordButton extends StatefulWidget {
  /// 当前跟读回合阶段。
  final ListenAndRepeatTurnPhase phase;

  /// 点击回调。
  final VoidCallback onTap;

  const SpeechRecordButton({
    super.key,
    required this.phase,
    required this.onTap,
  });

  @override
  State<SpeechRecordButton> createState() => _SpeechRecordButtonState();
}

class _SpeechRecordButtonState extends State<SpeechRecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  /// 等待说话慢速，说话时快速。
  static const _slowDuration = Duration(milliseconds: 2400);
  static const _fastDuration = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: _slowDuration);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant SpeechRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final phase = widget.phase;
    if (phase == ListenAndRepeatTurnPhase.awaitingSpeech) {
      _waveController.duration = _slowDuration;
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
    } else if (phase == ListenAndRepeatTurnPhase.speaking) {
      _waveController.duration = _fastDuration;
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
    } else {
      _waveController.stop();
      _waveController.reset();
    }
  }

  void _handleTap() {
    widget.onTap();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = widget.phase;
    final isRecording =
        phase == ListenAndRepeatTurnPhase.awaitingSpeech ||
        phase == ListenAndRepeatTurnPhase.speaking;

    final Color bgColor;
    final Color iconColor;
    final double elevation;

    if (isRecording) {
      bgColor = theme.colorScheme.error;
      iconColor = theme.colorScheme.onError;
      elevation = 4;
    } else {
      bgColor = theme.colorScheme.primaryContainer;
      iconColor = theme.colorScheme.primary;
      elevation = 1;
    }

    return SizedBox(
      width: _buttonSize,
      height: _buttonSize,
      child: Material(
        shape: const CircleBorder(),
        color: bgColor,
        elevation: elevation,
        shadowColor: bgColor.withValues(alpha: 0.4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _handleTap,
          customBorder: const CircleBorder(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 音波弧线（按钮内部，被 Material 的 CircleBorder 裁剪）
              if (isRecording)
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) => CustomPaint(
                    size: const Size(_buttonSize, _buttonSize),
                    painter: _WaveArcPainter(
                      progress: _waveController.value,
                      color: iconColor,
                    ),
                  ),
                ),
              Icon(Icons.mic_rounded, size: _iconSize, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// 音波弧线画笔。
///
/// 在话筒图标左右各绘制 3 条弧线，依次淡入淡出。
/// 弧线绘制在按钮内部，由外层 Material 的 CircleBorder 裁剪。
class _WaveArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveArcPainter({required this.progress, required this.color});

  static const _arcCount = 3;
  static const _arcWindow = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _arcCount; i++) {
      final start = i / _arcCount;
      final localT = _localProgress(progress, start, _arcWindow);
      if (localT <= 0) continue;

      // 淡入前半段，淡出后半段
      final alpha = localT <= 0.5 ? localT * 2 : (1.0 - localT) * 2;
      paint.color = color.withValues(alpha: alpha * 0.65);
      paint.strokeWidth = 2.0;

      // 弧线半径：从图标旁开始向按钮边缘扩散（适配 56px 按钮）
      final radius = 14.0 + 5.0 * i + 3.0 * localT;
      // 弧线张角约 55 度
      const sweepAngle = 55.0 * math.pi / 180;
      const halfSweep = sweepAngle / 2;

      // 右侧弧线
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -halfSweep,
        sweepAngle,
        false,
        paint,
      );
      // 左侧弧线
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi - halfSweep,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  double _localProgress(double global, double start, double window) {
    var diff = global - start;
    if (diff < 0) diff += 1.0;
    if (diff > window) return 0.0;
    return diff / window;
  }

  @override
  bool shouldRepaint(covariant _WaveArcPainter old) => old.progress != progress;
}
