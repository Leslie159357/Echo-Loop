import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/custom_api/custom_api_config.dart';

class CustomApiSettingsScreen extends ConsumerStatefulWidget {
  const CustomApiSettingsScreen({super.key});

  @override
  ConsumerState<CustomApiSettingsScreen> createState() => _CustomApiSettingsScreenState();
}

class _CustomApiSettingsScreenState extends ConsumerState<CustomApiSettingsScreen> {
  late TextEditingController _urlController;
  late TextEditingController _keyController;
  late TextEditingController _modelController;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(customApiConfigNotifierProvider);
    _enabled = cfg.enabled;
    _urlController = TextEditingController(text: cfg.baseUrl);
    _keyController = TextEditingController(text: cfg.apiKey);
    _modelController = TextEditingController(text: cfg.model);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = CustomApiConfig(
      enabled: _enabled,
      baseUrl: _urlController.text.trim(),
      apiKey: _keyController.text.trim(),
      model: _modelController.text.trim(),
    );
    await ref.read(customApiConfigNotifierProvider.notifier).update(config);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
            subtitle: const Text('使用自己的 API 进行翻译和解析'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'API 地址',
              hintText: 'https://your-api.com/v1/chat/completions',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: 'gpt-4o-mini',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
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
            const SizedBox(height: 12),
            DropdownButtonFormField<AiProvider>(
              value: config.provider,
              decoration: const InputDecoration(
                labelText: '提供商',
                border: OutlineInputBorder(),
              ),
              items: AiProvider.values.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.name),
              )).toList(),
              onChanged: (v) {
                if (v != null) notifier.update(provider: v);
              },
            ),
          ],
        ],
      ),
    );
  }
}
