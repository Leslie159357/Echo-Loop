/// 后端权益仓库接口 + 实现。
///
/// 查询后端权威权益（后端经 RevenueCat webhook 落库，绑定 Supabase user_id）。
/// 后端 `user_entitlements` 由 RC webhook 单向投影，对所有购买渠道
/// （App Store / Play / Web Billing）返回一致结果——**桌面 / 侧载等无 RC 原生 SDK
/// 的端也能据此拿到权威权益**（这正是 [SubscriptionController.refresh] 先查后端、
/// 再退回 RC 的对账顺序所依赖的能力）。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../services/api_log_interceptor.dart';
import '../../../services/app_logger.dart';
import '../models/entitlement.dart';
import '../models/subscription_plan.dart';

/// 后端权益仓库抽象。
abstract class EntitlementRepository {
  /// 查询后端权威权益。
  ///
  /// - 返回非空：后端确认的权益（active 或 [Entitlement.free]）。
  /// - 返回 **null**：未能获取（离线 / 错误 / 后端未就绪），调用方据此走缓存兜底，
  ///   **不可**把「获取失败」误判为「无权益」。
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
  });
}

/// Phase 0 占位实现：恒返回 null（触发缓存兜底 / 未知态）。
///
/// 保留供未接后端的构建 / 测试使用（如未注入 `API_BASE_URL` 的纯离线场景）。
class StubEntitlementRepository implements EntitlementRepository {
  const StubEntitlementRepository();

  @override
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
  }) async {
    return null;
  }
}

/// 后端权益仓库实现（`GET /api/entitlements`）。
///
/// 响应体：`{ isPremium, entitlementIds, productId, expiresAtMs }`（见后端
/// `apps/app/app/api/entitlements/route.ts`）。带 `Authorization: Bearer <token>`，
/// 参照 [TranscriptionApiClient] 的既有鉴权模式。
///
/// 错误策略（对齐接口契约）：
/// - HTTP 2xx → 映射为 [Entitlement]（`isPremium:false` 即权威的 [Entitlement.free]，
///   允许后端据此**降级**，而非误判为「获取失败」）。
/// - 网络异常 / 非 2xx / 解析失败 → 返回 **null**（走缓存 / RC 兜底，绝不误降级）。
class BackendEntitlementRepository implements EntitlementRepository {
  BackendEntitlementRepository({required String baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ) {
    _dio.interceptors.add(ApiLogInterceptor(tag: 'ENTITLEMENT'));
  }

  /// 测试用构造：注入 Dio。
  BackendEntitlementRepository.withDio(this._dio);

  final Dio _dio;

  @override
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data;
      if (data == null) {
        AppLogger.log('Subscription', '后端权益：响应体为空，走兜底');
        return null;
      }
      return _entitlementFrom(data);
    } on DioException catch (e) {
      // 网络 / 超时 / 非 2xx：不可误判为无权益，返回 null 由上层走缓存兜底。
      AppLogger.log(
        'Subscription',
        '后端权益查询失败（走兜底）: ${e.type} ${e.response?.statusCode ?? ""}',
      );
      return null;
    } catch (e) {
      AppLogger.log('Subscription', '后端权益解析异常（走兜底）: $e');
      return null;
    }
  }

  /// 把后端响应映射为 [Entitlement]。周期用 productId 启发式补全（后端不存周期）。
  Entitlement _entitlementFrom(Map<String, dynamic> json) {
    final isPremium = json['isPremium'] == true;
    if (!isPremium) return Entitlement.free;
    final rawIds = json['entitlementIds'];
    final entitlements = rawIds is List
        ? rawIds.whereType<String>().toSet()
        : <String>{};
    final productId = json['productId'] is String
        ? json['productId'] as String
        : null;
    final rawExpiry = json['expiresAtMs'];
    final expiresAt = rawExpiry is int
        ? DateTime.fromMillisecondsSinceEpoch(rawExpiry, isUtc: true)
        : null;
    return Entitlement(
      isPremium: true,
      activeEntitlements: entitlements,
      productId: productId,
      // 后端无周期字段：用 productId 字符串启发式推断，供会员 UI 显示套餐名。
      period: subscriptionPeriodFromProductId(productId),
      expiresAt: expiresAt,
      // 后端当前不投影自动续费标志，保守置 false（不影响 isActive 门禁判定）。
      willRenew: false,
    );
  }
}

/// 后端权益仓库 Provider（测试可 override 注入 Fake）。
final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return BackendEntitlementRepository(baseUrl: apiBaseUrl);
});
