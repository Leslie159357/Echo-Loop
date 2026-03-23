import 'dart:async';

/// 通知点击意图（sealed class，支持携带数据）
sealed class NotificationIntent {
  const NotificationIntent();
}

/// 打开学习任务列表页
class OpenStudyTasks extends NotificationIntent {
  const OpenStudyTasks();
}

/// 打开收藏页
class OpenFavorites extends NotificationIntent {
  const OpenFavorites();
}

/// 打开指定音频的学习计划页
class OpenAudioLearningPlan extends NotificationIntent {
  final String audioId;
  const OpenAudioLearningPlan(this.audioId);
}

/// 通知点击到路由层的桥接器
///
/// 插件回调不在 Widget 上下文内，先写入桥接器，再由 UI 层消费并导航。
class NotificationTapRouterBridge {
  final StreamController<NotificationIntent> _controller =
      StreamController<NotificationIntent>.broadcast();

  NotificationIntent? _pendingIntent;

  Stream<NotificationIntent> get intents => _controller.stream;

  void emit(NotificationIntent intent) {
    _pendingIntent = intent;
    _controller.add(intent);
  }

  NotificationIntent? takePendingIntent() {
    final pending = _pendingIntent;
    _pendingIntent = null;
    return pending;
  }

  void dispose() {
    _controller.close();
  }
}
