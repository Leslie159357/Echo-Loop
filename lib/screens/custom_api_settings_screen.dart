import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/custom_api/custom_api_config.dart';
import '../features/custom_api/custom_cloud_transcription_service.dart';

class CustomApiSettingsScreen extends ConsumerStatefulWidget {
  const CustomApiSettingsScreen({super.key});

  @override
  ConsumerState<CustomApiSettingsScreen> createState() =>
      _CustomApiSettingsScreenState();
}

class _CustomApiSettingsScreenState
    extends ConsumerState<CustomApiSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _textModelController = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _refreshingModels = false;
  bool _showApiKey = false;
  String _transcriptionModel = defaultCloudTranscriptionModel;

  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';

  String _text(String zh, String en) => _isChinese ? zh : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notifier = ref.read(customApiConfigNotifierProvider.notifier);
    await notifier.ready;
    if (!mounted) return;
    final config = ref.read(customApiConfigNotifierProvider);
    setState(() {
      _enabled = config.enabled;
      _baseUrlController.text = config.baseUrl;
      _textModelController.text = config.textModel;
      _transcriptionModel =
          config.transcriptionModel == wordTimestampTranscriptionModel
          ? wordTimestampTranscriptionModel
          : diarizedTranscriptionModel;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _textModelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final current = ref.read(customApiConfigNotifierProvider);
    final apiKey = _apiKeyController.text.trim();
    final textModel = _textModelController.text.trim();
    await ref
        .read(customApiConfigNotifierProvider.notifier)
        .update(
          current.copyWith(
            enabled: _enabled,
            baseUrl: _baseUrlController.text.trim(),
            textModel: textModel.isEmpty ? defaultTextAiModel : textModel,
            transcriptionModel: _transcriptionModel,
          ),
          apiKey: apiKey.isEmpty ? null : apiKey,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  Future<void> _clearApiKey() async {
    await ref.read(customApiConfigNotifierProvider.notifier).clearApiKey();
    _apiKeyController.clear();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refreshModels() async {
    final current = ref.read(customApiConfigNotifierProvider);
    final apiKey = _apiKeyController.text.trim();
    final textModel = _textModelController.text.trim();
    await ref
        .read(customApiConfigNotifierProvider.notifier)
        .update(
          current.copyWith(
            enabled: _enabled,
            baseUrl: _baseUrlController.text.trim(),
            textModel: textModel.isEmpty ? defaultTextAiModel : textModel,
            transcriptionModel: _transcriptionModel,
          ),
          apiKey: apiKey.isEmpty ? null : apiKey,
        );
    if (!mounted) return;
    setState(() => _refreshingModels = true);
    final models = await ref
        .read(customApiConfigNotifierProvider.notifier)
        .refreshModels();
    if (!mounted) return;
    setState(() => _refreshingModels = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          models.isEmpty
              ? _text('连接失败，请检查地址、Key 与网络', 'Connection failed')
              : _text(
                  '连接成功，发现 ${models.length} 个模型',
                  'Connected. ${models.length} models found',
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(customApiConfigNotifierProvider);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_text('AI 服务', 'AI service'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_text('AI 服务', 'AI service'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('启用云端 AI', 'Enable cloud AI')),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _text('API 地址', 'Base URL'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: !_showApiKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: config.hasApiKey
                  ? _text('已安全保存，留空则保留', 'Saved securely')
                  : null,
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _text('显示或隐藏', 'Show or hide'),
                    onPressed: () =>
                        setState(() => _showApiKey = !_showApiKey),
                    icon: Icon(
                      _showApiKey ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                  if (config.hasApiKey)
                    IconButton(
                      tooltip: _text('清除 Key', 'Clear key'),
                      onPressed: _clearApiKey,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textModelController,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _text('文本模型', 'Text model'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _transcriptionModel,
            decoration: InputDecoration(
              labelText: _text('云端转录模型', 'Cloud transcription model'),
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: diarizedTranscriptionModel,
                child: Text(diarizedTranscriptionModel),
              ),
              DropdownMenuItem(
                value: wordTimestampTranscriptionModel,
                child: Text(wordTimestampTranscriptionModel),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _transcriptionModel = value);
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _refreshingModels ? null : _refreshModels,
            icon: _refreshingModels
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_text('测试连接', 'Test connection')),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_text('保存', 'Save')),
          ),
        ],
      ),
    );
  }
}
