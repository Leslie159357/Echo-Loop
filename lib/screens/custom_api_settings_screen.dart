import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/custom_api/custom_api_config.dart';

class CustomApiSettingsScreen extends ConsumerWidget {
  const CustomApiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(customApiConfigNotifierProvider);
    final notifier = ref.read(customApiConfigNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('自定义 API')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('启用自定义 API'),
            subtitle: const Text('开启后可免登录使用翻译、分析、意群功能'),
            value: config.enabled,
            onChanged: (v) => notifier.update(enabled: v),
          ),
          if (config.enabled) ...[
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'API 地址',
                hintText: 'https://your-api.com/v1',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: config.baseUrl),
              onChanged: (v) => notifier.update(baseUrl: v),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: config.apiKey),
              onChanged: (v) => notifier.update(apiKey: v),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: '模型',
                hintText: 'gpt-4o-mini 或 deepseek-chat',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: config.model),
              onChanged: (v) => notifier.update(model: v),
            ),
          ],
        ],
      ),
    );
  }
}