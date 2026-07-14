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
        ],
      ),
    );
  }
}
