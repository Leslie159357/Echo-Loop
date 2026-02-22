// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$learningSessionHash() => r'f0cfb0d0b548892ac606d447dd27133f79f0f626';

/// 学习会话 Provider
///
/// 作为播放器之上的学习流程控制层。
/// 进入盲听模式时暂停 LP 监听、初始化 BlindListenPlayer，
/// 退出时停止盲听播放、恢复 LP 监听。
///
/// Copied from [LearningSession].
@ProviderFor(LearningSession)
final learningSessionProvider =
    NotifierProvider<LearningSession, LearningSessionState>.internal(
      LearningSession.new,
      name: r'learningSessionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$learningSessionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LearningSession = Notifier<LearningSessionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
