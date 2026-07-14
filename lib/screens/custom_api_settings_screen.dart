import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/custom_api/custom_api_config.dart';

class CustomApiSettingsScreen extends ConsumerStatefulWidget {
  const CustomApiSettingsScreen({super.key});

  @override
  ConsumerState<CustomApiSettingsScreen> createState() => _CustomApiSettingsScreenState();
}

class _CustomApiSettingsScreenState extends ConsumerState<CustomApiSettingsScreen> {
  late TextEditingController _urlCtl;
  late TextEditingController _keyCtl;
  late TextEditingController _modelCtl;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    final c = ref.read(customApiConfigNotifierProvider);
    _enabled = c.enabled;
    _urlCtl = TextEditingController(text: c.baseUrl);
    _keyCtl = TextEditingController(text: c.apiKey);
    _modelCtl = TextEditingController(text: c.model);
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    _keyCtl.dispose();
    _modelCtl.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(customApiConfigNotifierProvider.notifier).update(CustomApiConfig(
      enabled: _enabled,
      baseUrl: _urlCtl.text.trim(),
      apiKey: _keyCtl.text.trim(),
      model: _modelCtl.text.trim(),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自定义 API')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('启用自定义 API'),
            subtitle: const Text('开启后可免登录使用翻译、分析、意群功能'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtl,
            decoration: const InputDecoration(
              labelText: 'API 地址',
              hintText: 'https://your-api.com/v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyCtl,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtl,
            decoration: const InputDecoration(
              labelText: '模型',
              hintText: 'gpt-4o-mini 或 deepseek-chat',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
