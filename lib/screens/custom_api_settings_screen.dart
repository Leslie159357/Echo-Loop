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
  bool _isRefreshing = false;

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

  Future<void> _refreshModels() async {
    setState(() => _isRefreshing = true);
    final models = await ref
        .read(customApiConfigNotifierProvider.notifier)
        .refreshModels();
    setState(() => _isRefreshing = false);
    if (models.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取模型列表，请检查 API 地址和 Key')),
        );
      }
      return;
    }
    // 如果当前模型不在列表中，自动选择第一个
    final currentModel = _mdlCtrl.text.trim();
    if (currentModel.isEmpty || !models.contains(currentModel)) {
      _mdlCtrl.text = models.first;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已获取 ${models.length} 个模型')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(customApiConfigNotifierProvider);

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
            // 模型选择行：下拉 + 刷新按钮
            Row(
              children: [
                Expanded(
                  child: cfg.modelList.isNotEmpty
                      ? Autocomplete<String>(
                          optionsBuilder: (textEditingValue) =>
                              cfg.modelList.where((model) => model
                                  .toLowerCase()
                                  .contains(
                                      textEditingValue.text.toLowerCase())),
                          initialValue: TextEditingValue(
                            text: _mdlCtrl.text,
                          ),
                          fieldViewBuilder: (context, textEditingController,
                              focusNode, onSubmitted) {
                            // 同步外部 controller
                            _mdlCtrl.text = textEditingController.text;
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: "模型",
                                hintText: "gpt-4o-mini",
                                border: OutlineInputBorder(),
                              ),
                            );
                          },
                          onSelected: (selection) {
                            _mdlCtrl.text = selection;
                          },
                        )
                      : TextField(
                          controller: _mdlCtrl,
                          decoration: const InputDecoration(
                            labelText: "模型",
                            hintText: "gpt-4o-mini",
                            border: OutlineInputBorder(),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isRefreshing ? null : _refreshModels,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: "刷新模型列表",
                ),
              ],
            ),
            if (cfg.modelList.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "共 ${cfg.modelList.length} 个模型可用",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            if (cfg.lastRefreshedAtMs > 0) ...[
              const SizedBox(height: 2),
              Text(
                "上次刷新: ${DateTime.fromMillisecondsSinceEpoch(cfg.lastRefreshedAtMs).toString().substring(0, 19)}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
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
