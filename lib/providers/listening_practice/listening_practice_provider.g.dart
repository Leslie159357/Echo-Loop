// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listening_practice_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$listeningPracticeHash() => r'e337984ab82c23f8764208c09001ed3a7ce5a9ea';

/// 自由练习播放器的状态与业务编排。
///
/// 播放推进采用单一的「事件驱动」模型：底层 [AudioEngine]（多个功能共享的
/// 单实例 just_audio）只在「一句/整段播放完成」时回调 [_onPlayerStateChanged]，
/// 由纯函数 [decideNext] 决定下一步（重播 / 进下一句 / 回卷 / 停止）。
/// 不再有跨多次 await 持有状态的长协程，避免索引乱跳。
///
/// 真相源是 [ListeningPracticeState.currentFullIndex] /
/// [ListeningPracticeState.currentBookmarkIndex]，只在以下入口被修改：
/// 用户显式选句/上下句、连播时位置流推进（仅 gapless 模式）、完成事件归约器。
///
/// Copied from [ListeningPractice].
@ProviderFor(ListeningPractice)
final listeningPracticeProvider =
    NotifierProvider<ListeningPractice, ListeningPracticeState>.internal(
      ListeningPractice.new,
      name: r'listeningPracticeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$listeningPracticeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ListeningPractice = Notifier<ListeningPracticeState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
