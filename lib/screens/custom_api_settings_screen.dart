import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/custom_api/custom_api_config.dart';

class CustomApiSettingsScreen extends ConsumerStatefulWidget {
  const CustomApiSettingsScreen({super.key});

  @override
  ConsumerState<CustomApiSettingsScreen> createState() => _State();
}

class _State extends ConsumerState<CustomApiSettingsScreen> {
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _keyCtrl = TextEditingController();
  final TextEditingController _mdlCtrl = TextEditingController();
  bool _on = false;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(customApiConfigNotifierProvider);
    _on = cfg.enabled;
    _urlCtrl.text = cfg.baseUrl;
    _keyCtrl.text = cfg.apiKey;
    _mdlCtrl.text = cfg.model;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _mdlCtrl.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(customApiConfigNotifierProvider.notifier).update(CustomApiConfig(
      enabled: _on,
      baseUrl: _urlCtrl.text.trim(),
      apiKey: _keyCtrl.text.trim(),
      model: _mdlCtrl.text.trim(),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("自定义 API")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text("启用自定义 API"),
            subtitle: const Text("开启后可免登录使用翻译、分析、意群"),
            value: _on,
            onChanged: (v) => setState(() => _on = v),
          ),
          if (_on) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: "API 地址",
                  hintText: "https://your-api.com/v1",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: "API Key",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mdlCtrl,
              decoration: const InputDecoration(
                labelText: "模型",
                hintText: "gpt-4o-mini",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text("保存"),
            ),
          ],
        ],
      ),
    );
  }
}