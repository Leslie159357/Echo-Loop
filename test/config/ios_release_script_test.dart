import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS 发布脚本存在且 bash 语法合法', () async {
    final file = File('scripts/release_ios.sh');

    expect(await file.exists(), isTrue);

    final result = await Process.run('bash', ['-n', file.path]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('iOS 发布脚本 help 暴露一键发布关键选项', () async {
    final result = await Process.run('bash', [
      'scripts/release_ios.sh',
      '--help',
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());

    final output = result.stdout.toString();
    expect(output, contains('--wait'));
    expect(output, contains('--skip-upload'));
    expect(output, contains('--work-dir'));
    expect(output, contains('--build-name'));
    expect(output, contains('--build-number'));
    expect(output, contains('Archive the iOS app'));
  });

  test('iOS 发布脚本包含导出失败时的兜底封包逻辑', () async {
    final content = await File('scripts/release_ios.sh').readAsString();

    expect(content, contains("XcodeDistPipeline."));
    expect(content, contains('/usr/bin/ditto'));
    expect(content, contains('--upload-app'));
    expect(content, contains('--build-status'));
    expect(content, contains('FLUTTER_BUILD_NUMBER'));
  });
}
