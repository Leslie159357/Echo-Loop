/// 屏幕常亮 Mixin
///
/// 用于学习播放器页面，防止用户学习时屏幕自动熄灭。
/// 混入到 State 后，页面显示时自动启用常亮，页面销毁时自动关闭。
library;

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 屏幕常亮 Mixin
///
/// 在 [initState] 时启用屏幕常亮，在 [dispose] 时关闭。
/// 使用方法：`class _MyScreenState extends State<MyScreen> with WakelockMixin`
mixin WakelockMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }
}
