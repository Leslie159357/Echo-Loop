import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/analytics/permission_snapshot.dart';
import 'package:echo_loop/services/network_permission_trigger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NetworkPermissionTrigger.channel, null);
  });

  void mockChannel(Object? Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          NetworkPermissionTrigger.channel,
          (MethodCall call) async => handler(call),
        );
  }

  group('NetworkPermissionTrigger.trigger', () {
    test('原生返回 ok=true 时写 SP', () async {
      mockChannel((call) {
        expect(call.method, 'triggerNetworkPermission');
        expect(call.arguments, {'url': 'https://api.example.com'});
        return {'ok': true};
      });

      await NetworkPermissionTrigger.trigger(prefs, 'https://api.example.com');

      expect(prefs.getBool(PermissionSnapshot.spKeyNetworkOk), true);
    });

    test('原生返回 ok=false 时不写 SP（避免假 denied）', () async {
      mockChannel((_) => {'ok': false, 'reason': 'timeout'});

      await NetworkPermissionTrigger.trigger(prefs, 'https://api.example.com');

      expect(prefs.containsKey(PermissionSnapshot.spKeyNetworkOk), isFalse);
    });

    test('channel 抛错时静默吞掉，不写 SP', () async {
      mockChannel((_) {
        throw PlatformException(code: 'INVALID_URL');
      });

      await NetworkPermissionTrigger.trigger(prefs, 'bad-url');

      expect(prefs.containsKey(PermissionSnapshot.spKeyNetworkOk), isFalse);
    });

    test('原生返回 null 时不写 SP', () async {
      mockChannel((_) => null);

      await NetworkPermissionTrigger.trigger(prefs, 'https://api.example.com');

      expect(prefs.containsKey(PermissionSnapshot.spKeyNetworkOk), isFalse);
    });

    test('原生返回非预期 payload（缺 ok 字段）时不写 SP', () async {
      mockChannel((_) => {'reason': 'something'});

      await NetworkPermissionTrigger.trigger(prefs, 'https://api.example.com');

      expect(prefs.containsKey(PermissionSnapshot.spKeyNetworkOk), isFalse);
    });

    test('已经写过 SP 时再次成功保持 true（幂等）', () async {
      SharedPreferences.setMockInitialValues({
        PermissionSnapshot.spKeyNetworkOk: true,
      });
      prefs = await SharedPreferences.getInstance();
      mockChannel((_) => {'ok': true});

      await NetworkPermissionTrigger.trigger(prefs, 'https://api.example.com');

      expect(prefs.getBool(PermissionSnapshot.spKeyNetworkOk), true);
    });

    test('已经写过 SP 时本次失败不会回退为 false', () async {
      SharedPreferences.setMockInitialValues({
        PermissionSnapshot.spKeyNetworkOk: true,
      });
      prefs = await SharedPreferences.getInstance();
      mockChannel((_) => {'ok': false});

      await NetworkPermissionTrigger.trigger(prefs, 'https://api.example.com');

      // 关键不变量：失败永远不写 SP，已成功的状态不会被回退
      expect(prefs.getBool(PermissionSnapshot.spKeyNetworkOk), true);
    });
  });
}
