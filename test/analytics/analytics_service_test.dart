import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluency/analytics/analytics_channel.dart';
import 'package:fluency/analytics/analytics_service.dart';
import 'package:fluency/analytics/consent_manager.dart';
import 'package:fluency/analytics/models/event_names.dart';

/// 记录所有调用的 Mock Channel
class MockChannel implements AnalyticsChannel {
  final List<({String name, Map<String, Object>? params})> events = [];
  final List<String?> userIds = [];
  final List<({String name, String? value})> userProperties = [];

  @override
  String get name => 'Mock';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    events.add((name: name, params: parameters));
  }

  @override
  Future<void> setUserId(String? id) async {
    userIds.add(id);
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProperties.add((name: name, value: value));
  }
}

void main() {
  group('AnalyticsService', () {
    late MockChannel channel;
    late SharedPreferences prefs;
    late ConsentManager consent;
    late AnalyticsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      channel = MockChannel();
      consent = ConsentManager(prefs);
      service = AnalyticsService(channel: channel, consent: consent);
    });

    test('track 转发事件到 channel', () async {
      await service.track(Events.appOpen, {
        EventParams.isFirstLaunch: true,
        EventParams.launchType: 'cold',
      });

      expect(channel.events, hasLength(1));
      expect(channel.events.first.name, Events.appOpen);
      expect(channel.events.first.params?[EventParams.isFirstLaunch], true);
      expect(channel.events.first.params?[EventParams.launchType], 'cold');
    });

    test('track 无参数时传 null', () async {
      await service.track(Events.appBackground);

      expect(channel.events, hasLength(1));
      expect(channel.events.first.name, Events.appBackground);
      expect(channel.events.first.params, isNull);
    });

    test('用户未同意时 track 静默丢弃', () async {
      await consent.revokeConsent();

      await service.track(Events.appOpen);
      await service.track(Events.sessionStart, {EventParams.audioId: '123'});

      expect(channel.events, isEmpty);
    });

    test('用户未同意时 setUserId 静默丢弃', () async {
      await consent.revokeConsent();

      await service.setUserId('user-123');

      expect(channel.userIds, isEmpty);
    });

    test('用户未同意时 setUserProperty 静默丢弃', () async {
      await consent.revokeConsent();

      await service.setUserProperty('locale', 'zh');

      expect(channel.userProperties, isEmpty);
    });

    test('撤回同意后停止采集，重新同意后恢复', () async {
      // 同意状态：事件正常
      await service.track(Events.appOpen);
      expect(channel.events, hasLength(1));

      // 撤回同意：事件丢弃
      await consent.revokeConsent();
      await service.track(Events.sessionStart);
      expect(channel.events, hasLength(1)); // 没有新增

      // 重新同意：事件恢复
      await consent.grantConsent();
      await service.track(Events.sessionEnd);
      expect(channel.events, hasLength(2));
    });

    test('setUserId 转发到 channel', () async {
      await service.setUserId('anonymous-uuid-123');

      expect(channel.userIds, hasLength(1));
      expect(channel.userIds.first, 'anonymous-uuid-123');
    });

    test('setUserProperty 转发到 channel', () async {
      await service.setUserProperty('app_locale', 'zh');

      expect(channel.userProperties, hasLength(1));
      expect(channel.userProperties.first.name, 'app_locale');
      expect(channel.userProperties.first.value, 'zh');
    });

    test('channelName 返回通道名', () {
      expect(service.channelName, 'Mock');
    });
  });
}
