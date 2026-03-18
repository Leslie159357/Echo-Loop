/// 语音练习评级 Badge（共享组件）
///
/// 融合评级文字 + 播放图标的可点击胶囊 Badge。
/// 跟读、复述、难句补练页面共用，各自控制外部布局位置。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/speech_practice_models.dart';

/// 评分阈值配置。
class RatingThresholds {
  /// Perfect 阈值。
  final double perfect;

  /// Excellent 阈值。
  final double excellent;

  /// Good 阈值。
  final double good;

  /// Fair 阈值。
  final double fair;

  const RatingThresholds({
    required this.perfect,
    required this.excellent,
    required this.good,
    required this.fair,
  });

  /// 跟读场景默认阈值。
  static const listenAndRepeat = RatingThresholds(
    perfect: 0.95,
    excellent: 0.80,
    good: 0.60,
    fair: 0.40,
  );

  /// 复述场景阈值（比跟读宽松）。
  static const retell = RatingThresholds(
    perfect: 0.90,
    excellent: 0.75,
    good: 0.50,
    fair: 0.20,
  );
}

/// 语音练习评级 Badge。
///
/// 融合评级文字和播放图标，点击整个 badge 播放/停止录音回放。
/// 无 transcript 时降级为纯文字反馈。
class SpeechRatingBadge extends StatelessWidget {
  final AppLocalizations l10n;
  final SpeechPracticeAttempt attempt;
  final bool isPlaying;
  final VoidCallback? onTap;

  /// 评分阈值，默认跟读阈值。
  final RatingThresholds thresholds;

  const SpeechRatingBadge({
    super.key,
    required this.l10n,
    required this.attempt,
    required this.isPlaying,
    this.onTap,
    this.thresholds = RatingThresholds.listenAndRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTranscript = (attempt.finalTranscript ?? '').isNotEmpty;

    // 无识别结果时降级为纯文字反馈
    if (!hasTranscript) {
      return Text(
        _feedbackText(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: _statusColor(theme),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final style = _ratingStyle(theme);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [style.backgroundStart, style.backgroundEnd],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: style.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _ratingLabel(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: style.textColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            if (attempt.hasRecording) ...[
              const SizedBox(width: 6),
              Icon(
                isPlaying ? Icons.stop_rounded : Icons.volume_up_outlined,
                size: 16,
                color: style.textColor.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _ratingLabel() {
    final score = attempt.score ?? 0;
    if (score >= thresholds.perfect) {
      return l10n.listenAndRepeatRatingPerfect;
    }
    if (score >= thresholds.excellent) {
      return l10n.listenAndRepeatRatingExcellent;
    }
    if (score >= thresholds.good) {
      return l10n.listenAndRepeatRatingGood;
    }
    if (score >= thresholds.fair) {
      return l10n.listenAndRepeatRatingFair;
    }
    return l10n.listenAndRepeatRatingKeepGoing;
  }

  String _feedbackText() {
    return switch (attempt.status) {
      SpeechPracticeAttemptStatus.noEnglishDetected =>
        l10n.listenAndRepeatRecognitionNoEnglish,
      SpeechPracticeAttemptStatus.permissionDenied =>
        l10n.listenAndRepeatRecognitionPermissionDenied,
      SpeechPracticeAttemptStatus.unavailable =>
        l10n.listenAndRepeatRecognitionUnavailable,
      SpeechPracticeAttemptStatus.error => l10n.listenAndRepeatRecognitionError,
      SpeechPracticeAttemptStatus.awaitingFinal ||
      SpeechPracticeAttemptStatus.passed ||
      SpeechPracticeAttemptStatus.belowThreshold ||
      SpeechPracticeAttemptStatus.recording ||
      SpeechPracticeAttemptStatus.idle => '',
    };
  }

  Color _statusColor(ThemeData theme) {
    return switch (attempt.status) {
      SpeechPracticeAttemptStatus.passed => const Color(0xFF2E9B51),
      SpeechPracticeAttemptStatus.awaitingFinal => theme.colorScheme.primary,
      SpeechPracticeAttemptStatus.belowThreshold ||
      SpeechPracticeAttemptStatus.noEnglishDetected ||
      SpeechPracticeAttemptStatus.permissionDenied ||
      SpeechPracticeAttemptStatus.unavailable ||
      SpeechPracticeAttemptStatus.error => theme.colorScheme.error,
      _ => theme.colorScheme.onSurface,
    };
  }

  _RatingBadgeStyle _ratingStyle(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final score = attempt.score ?? 0;

    if (score >= thresholds.perfect) {
      return isDark
          ? const _RatingBadgeStyle(
              textColor: Color(0xFFFFE082),
              backgroundStart: Color(0x33C9A030),
              backgroundEnd: Color(0x1A7A5F14),
              borderColor: Color(0x40E0B84A),
            )
          : const _RatingBadgeStyle(
              textColor: Color(0xFF8B6914),
              backgroundStart: Color(0xFFFFF8E1),
              backgroundEnd: Color(0xFFFFF0B8),
              borderColor: Color(0xFFE0C068),
            );
    }
    if (score >= thresholds.excellent) {
      return isDark
          ? const _RatingBadgeStyle(
              textColor: Color(0xFFB9F5C8),
              backgroundStart: Color(0x3347B66B),
              backgroundEnd: Color(0x1A245B38),
              borderColor: Color(0x4057C878),
            )
          : const _RatingBadgeStyle(
              textColor: Color(0xFF1E7A3D),
              backgroundStart: Color(0xFFEAF8EF),
              backgroundEnd: Color(0xFFDDF2E4),
              borderColor: Color(0xFFA8D6B6),
            );
    }
    if (score >= thresholds.good) {
      return isDark
          ? const _RatingBadgeStyle(
              textColor: Color(0xFFE4F3B2),
              backgroundStart: Color(0x33A4B84B),
              backgroundEnd: Color(0x1A56611F),
              borderColor: Color(0x40BDD460),
            )
          : const _RatingBadgeStyle(
              textColor: Color(0xFF687A18),
              backgroundStart: Color(0xFFF6F8DF),
              backgroundEnd: Color(0xFFEEF3C8),
              borderColor: Color(0xFFD6DD9A),
            );
    }
    if (score >= thresholds.fair) {
      return isDark
          ? const _RatingBadgeStyle(
              textColor: Color(0xFFF7D79B),
              backgroundStart: Color(0x33C68A38),
              backgroundEnd: Color(0x1A6D4617),
              borderColor: Color(0x40E0A450),
            )
          : const _RatingBadgeStyle(
              textColor: Color(0xFF8A5A14),
              backgroundStart: Color(0xFFFFF1DD),
              backgroundEnd: Color(0xFFF9E3BF),
              borderColor: Color(0xFFE6C48C),
            );
    }
    return isDark
        ? const _RatingBadgeStyle(
            textColor: Color(0xFFB0BEC5),
            backgroundStart: Color(0x33607D8B),
            backgroundEnd: Color(0x1A37474F),
            borderColor: Color(0x4078909C),
          )
        : const _RatingBadgeStyle(
            textColor: Color(0xFF546E7A),
            backgroundStart: Color(0xFFECEFF1),
            backgroundEnd: Color(0xFFE0E4E8),
            borderColor: Color(0xFFB0BEC5),
          );
  }
}

/// 评级 Badge 内部样式
class _RatingBadgeStyle {
  final Color textColor;
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color borderColor;

  const _RatingBadgeStyle({
    required this.textColor,
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.borderColor,
  });
}
