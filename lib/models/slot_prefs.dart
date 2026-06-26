/// 通用「按槽位」用户偏好容器
///
/// 学习设置的真正单位是**槽位** = 子阶段 × 复习轮次(见 [stageSlotKey])。同一子阶段
/// 在不同轮次的设置各自独立(如盲听 firstLearn / review2 / review14 互不影响)。
///
/// 本容器是不可变的 `槽位 → 偏好[P]` 映射;[P] 为某 Settings 模型对应的「全字段
/// 可空」偏好(null=用默认,含动态智能默认),由各模型自带 resolve 出生效设置。
/// 与逐句精听首版一致的「单一真相源 + 可空覆盖」模式,只是加回了槽位维度。
library;

import 'package:flutter/foundation.dart' show mapEquals;

/// 按槽位存储的不可变偏好表。
///
/// [P] 须实现值相等(`==`/`hashCode`),以支持「值未变化不写盘」判断。
class SlotPrefs<P> {
  /// 槽位 key → 该槽位的偏好。缺失槽位表示「全用默认」。
  final Map<String, P> _bySlot;

  const SlotPrefs(this._bySlot);

  /// 空表(无任何记忆)。
  const SlotPrefs.empty() : _bySlot = const {};

  /// 取某槽位的偏好;无则返回 null(调用方用各模型的空偏好兜底)。
  P? maybe(String slot) => _bySlot[slot];

  /// 返回把 [slot] 偏好替换为 [prefs] 后的新表。
  SlotPrefs<P> withSlot(String slot, P prefs) =>
      SlotPrefs<P>({..._bySlot, slot: prefs});

  /// 序列化为 `{槽位: enc(偏好)}`(只含有记忆的槽位)。
  Map<String, dynamic> toJson(Map<String, dynamic> Function(P) enc) => {
    for (final e in _bySlot.entries) e.key: enc(e.value),
  };

  /// 从 `{槽位: json}` 反序列化;[dec] 解析单槽位偏好。
  ///
  /// 结构不符的条目跳过,整体退化到可用子集(不抛错)。
  static SlotPrefs<P> fromJson<P>(
    Object? raw,
    P Function(Map<String, dynamic>) dec,
  ) {
    if (raw is! Map) return SlotPrefs<P>.empty();
    final parsed = <String, P>{};
    raw.forEach((key, value) {
      if (key is String && value is Map) {
        parsed[key] = dec(Map<String, dynamic>.from(value));
      }
    });
    return SlotPrefs<P>(parsed);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotPrefs<P> && mapEquals(_bySlot, other._bySlot);

  @override
  int get hashCode => Object.hashAllUnordered(_bySlot.keys);
}
