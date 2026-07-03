/// 词典数据源统一契约
///
/// 单个词典源只暴露「我是谁 + 怎么查」，不碰 UI、不持有查询状态。
/// 副作用（网络/DB/平台调用）通过实现类构造器注入，便于 mock 测试。
/// 新增源 = 实现本接口 + 在注册表加一行，不改任何现有源。
library;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../models/dictionary/dictionary_lookup_result.dart';

/// 数据源需要登录态但未提供时抛出。
///
/// 由 controller 捕获并转为「需登录」状态，区别于普通网络失败。
class DictionaryAuthRequiredException implements Exception {
  const DictionaryAuthRequiredException();
  @override
  String toString() => 'DictionaryAuthRequiredException';
}

/// 查询词组过长（后端返回 code=phrase_too_long）时抛出。
///
/// 由 controller 捕获并转为「词组过长」状态，区别于普通网络失败——
/// 该错误重试无意义（词太长不会变短），视图不显示重试按钮。
class DictionaryPhraseTooLongException implements Exception {
  const DictionaryPhraseTooLongException();
  @override
  String toString() => 'DictionaryPhraseTooLongException';
}

/// 查词请求参数（聚合，避免接口参数膨胀）
class DictionaryLookupRequest {
  /// 已清洗的查询词形
  final String word;

  /// 语境句（部分源用于释义消歧，其余源忽略）
  final String? sentence;

  /// 登录态 access token（需鉴权的源用，如 AI）
  final String? accessToken;

  /// 目标语言 BCP 47 代码（如 zh-CN），用于释义语言与缓存隔离
  final String? targetLanguage;

  const DictionaryLookupRequest({
    required this.word,
    this.sentence,
    this.accessToken,
    this.targetLanguage,
  });
}

/// 词典数据源
abstract interface class DictionarySource {
  /// 稳定唯一 id（如 'local'/'ai'/'cambridge'）。
  /// 一经发布不可更改——它同时是持久化 key、缓存 key 前缀、切换器选中标识。
  String get id;

  /// 切换器/设置页图标。
  /// 优先用内置 [IconData]（矢量内置，避免 release 资源压缩删图标）。
  IconData get icon;

  /// 能否被用户在设置里禁用。本地/AI 返回 false（恒可见），其它源返回 true。
  bool get canBeDisabled;

  /// 是否需要联网（用于离线兜底与提示）。
  bool get requiresNetwork;

  /// 查词。
  ///
  /// - 返回结果 = 命中；
  /// - 返回 `null` = 未收录；
  /// - 抛异常 = 失败（由 controller 转 error 态，禁止吞异常）。
  ///
  /// [cancelToken] 用于切词/切源时取消在途请求。源可选择忽略它——
  /// 如 AI 源采用后台单请求语义（不可取消，跑完落缓存供复用）。
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  });
}
