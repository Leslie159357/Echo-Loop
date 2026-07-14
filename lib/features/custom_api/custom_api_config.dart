import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { openAI, anthropic, gemini, openRouter, custom }

class CustomApiConfig {
  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;
  final AiProvider provider;

  const CustomApiConfig({this.enabled=false, this.baseUrl='', this.apiKey='', this.model='', this.provider=AiProvider.custom});

  Map<String,dynamic> toJson() => {'enabled':enabled,'baseUrl':baseUrl,'apiKey':apiKey,'model':model,'provider':provider.name};
  factory CustomApiConfig.fromJson(Map<String,dynamic> j) => CustomApiConfig(
    enabled:j['enabled']??false,baseUrl:j['baseUrl']??'',apiKey:j['apiKey']??'',model:j['model']??'',provider:AiProvider.values.firstWhere((p)=>p.name==j['provider'],orElse:()=>AiProvider.custom));
  CustomApiConfig copyWith({bool? enabled,String? baseUrl,String? apiKey,String? model,AiProvider? provider}) => CustomApiConfig(
    enabled:enabled??this.enabled,baseUrl:baseUrl??this.baseUrl,apiKey:apiKey??this.model,model:model??this.model,provider:provider??this.provider);
}

class CustomApiConfigNotifier extends StateNotifier<CustomApiConfig> {
  CustomApiConfigNotifier() : super(const CustomApiConfig()) { _load(); }
  Future<void> _load() async {
    final j=(await SharedPreferences.getInstance()).getString('custom_api_config');
    if (j!=null) try{state=CustomApiConfig.fromJson(Map<String,dynamic>.from(jsonDecode(j) as Map));}catch(_){}
  }
  Future<void> update(CustomApiConfig c) async {state=c;await (await SharedPreferences.getInstance()).setString('custom_api_config',jsonEncode(c.toJson()));}
  Future<void> toggle(bool e) async => await update(state.copyWith(enabled: e));
}

final customApiConfigNotifierProvider = StateNotifierProvider<CustomApiConfigNotifier, CustomApiConfig>((ref) => CustomApiConfigNotifier());
