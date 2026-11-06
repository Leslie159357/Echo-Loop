import 'api_config.dart';

/// 全球静态资源 CDN 地址（模型、单词发音、词典资源等）——指向自建网关。
const globalStaticCdnBaseUrl = 'https://echoloop.1122275.xyz';

/// 中国大陆静态资源 CDN 地址——自建网关无区域分流，同一域名。
const chinaStaticCdnBaseUrl = 'https://echoloop.1122275.xyz';

/// 兼容本地旧引用（上游已改名 staticCdn，此处保留别名避免大面积改动）。
const globalModelCdnBaseUrl = globalStaticCdnBaseUrl;
const chinaModelCdnBaseUrl = chinaStaticCdnBaseUrl;

/// 中国 API 与静态资源 CDN 地址；与全球地址一起编入同一个发布包。
/// 中国 API 可通过 `API_CHINA_BASE_URL` 编译期变量覆盖。
const chinaApiBaseUrl = String.fromEnvironment(
  'API_CHINA_BASE_URL',
  defaultValue: defaultSelfHostedUrl,
);

class RegionalServiceEndpoints {
  const RegionalServiceEndpoints({
    required this.globalApiBaseUrl,
    required this.chinaApiBaseUrl,
    required this.globalStaticCdnBaseUrl,
    required this.chinaStaticCdnBaseUrl,
  });

  final String globalApiBaseUrl;
  final String chinaApiBaseUrl;
  final String globalStaticCdnBaseUrl;
  final String chinaStaticCdnBaseUrl;

  String? apiBaseUrlFor(ServiceEndpointRegion region) =>
      _configuredUrl(switch (region) {
        ServiceEndpointRegion.global => globalApiBaseUrl,
        ServiceEndpointRegion.china => chinaApiBaseUrl,
      });

  String? staticCdnBaseUrlFor(ServiceEndpointRegion region) =>
      _configuredUrl(switch (region) {
        ServiceEndpointRegion.global => globalStaticCdnBaseUrl,
        ServiceEndpointRegion.china => chinaStaticCdnBaseUrl,
      });

  static String? _configuredUrl(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }
}

enum ServiceEndpointRegion { global, china }

const regionalServiceEndpoints = RegionalServiceEndpoints(
  globalApiBaseUrl: apiBaseUrl,
  chinaApiBaseUrl: chinaApiBaseUrl,
  globalStaticCdnBaseUrl: globalStaticCdnBaseUrl,
  chinaStaticCdnBaseUrl: chinaStaticCdnBaseUrl,
);
