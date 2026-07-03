import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/widgets/common/shimmer_placeholder.dart';
import 'package:echo_loop/widgets/dictionary/ai_dict_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 例句行内含发音按钮（消费 ttsControllerProvider），需 ProviderScope 包裹。
Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

DictionaryEntry _entry({
  List<WordMeaning>? meanings,
  List<CommonExpression>? commonExpressions,
  List<WordFamilyItem>? wordFamily,
  List<WordForm>? forms,
  List<String>? learnerTips,
}) => DictionaryEntry(
  headword: 'run',
  pronunciation: const Pronunciation(uk: 'rʌn', us: 'rʌn'),
  meanings:
      meanings ??
      const [
        WordMeaning(
          partOfSpeech: 'v.',
          translation: ['奔跑'],
          definition: 'to move fast on foot',
          usageNote: '',
          examples: [
            ExampleSentence(sentence: 'I run fast.', translation: '我跑得快。'),
          ],
          synonyms: ['sprint'],
          antonyms: [],
        ),
      ],
  commonExpressions: commonExpressions ?? const [],
  wordFamily: wordFamily ?? const [],
  forms: forms ?? const [],
  etymology: '',
  learnerTips: learnerTips ?? const [],
);

void main() {
  AiDictResultView view(SourceLookupState state) =>
      AiDictResultView(state: state, onRetry: () {}, onSignIn: () {});

  testWidgets('Loaded 渲染词性/对应词/英文释义/例句/近义词 chip', (tester) async {
    await tester.pumpWidget(_wrap(view(LookupLoaded(AiDictResult(_entry())))));
    // 对应词作主标题，英文单语释义作辅助行
    expect(find.text('奔跑'), findsOneWidget);
    expect(find.text('to move fast on foot'), findsOneWidget);
    expect(find.text('v.'), findsOneWidget);
    expect(find.text('I run fast.'), findsOneWidget);
    // 近义词改为 chip，按词文本查找
    expect(find.text('sprint'), findsOneWidget);
  });

  testWidgets('对应词缺失时回退英文释义作主标题', (tester) async {
    await tester.pumpWidget(
      _wrap(
        view(
          LookupLoaded(
            AiDictResult(
              _entry(
                meanings: const [
                  WordMeaning(
                    partOfSpeech: 'v.',
                    translation: [],
                    definition: 'to move fast on foot',
                    usageNote: '',
                    examples: [],
                    synonyms: [],
                    antonyms: [],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // 仅出现一次（作主标题），不重复成辅助行
    expect(find.text('to move fast on foot'), findsOneWidget);
  });

  testWidgets('多个对应词以「；」连接', (tester) async {
    await tester.pumpWidget(
      _wrap(
        view(
          LookupLoaded(
            AiDictResult(
              _entry(
                meanings: const [
                  WordMeaning(
                    partOfSpeech: 'v.',
                    translation: ['奔跑', '运行'],
                    definition: '',
                    usageNote: '',
                    examples: [],
                    synonyms: [],
                    antonyms: [],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('奔跑；运行'), findsOneWidget);
  });

  testWidgets('单义项不显示序号，多义项显示序号', (tester) async {
    // 单义项：无序号
    await tester.pumpWidget(_wrap(view(LookupLoaded(AiDictResult(_entry())))));
    expect(find.text('1'), findsNothing);

    // 多义项：显示 1 / 2
    await tester.pumpWidget(
      _wrap(
        view(
          LookupLoaded(
            AiDictResult(
              _entry(
                meanings: const [
                  WordMeaning(
                    partOfSpeech: 'v.',
                    translation: ['奔跑'],
                    definition: 'to move fast on foot',
                    usageNote: '',
                    examples: [],
                    synonyms: [],
                    antonyms: [],
                  ),
                  WordMeaning(
                    partOfSpeech: 'n.',
                    translation: ['一段路程'],
                    definition: 'an act of running',
                    usageNote: '',
                    examples: [],
                    synonyms: [],
                    antonyms: [],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('常见搭配显示 type tag', (tester) async {
    await tester.pumpWidget(
      _wrap(
        view(
          LookupLoaded(
            AiDictResult(
              _entry(
                commonExpressions: const [
                  CommonExpression(
                    expression: 'run out',
                    type: '短语动词',
                    meaning: '用完',
                    example: ExampleSentence(sentence: '', translation: ''),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('run out'), findsOneWidget);
    expect(find.text('短语动词'), findsOneWidget);
  });

  testWidgets('词族显示 meaning', (tester) async {
    await tester.pumpWidget(
      _wrap(
        view(
          LookupLoaded(
            AiDictResult(
              _entry(
                wordFamily: const [
                  WordFamilyItem(
                    word: 'runner',
                    partOfSpeech: 'n.',
                    meaning: '跑步者',
                    example: ExampleSentence(sentence: '', translation: ''),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('runner'), findsOneWidget);
    expect(find.text('跑步者'), findsOneWidget);
  });

  testWidgets('词形变化显示形式与标签', (tester) async {
    await tester.pumpWidget(
      _wrap(
        view(
          LookupLoaded(
            AiDictResult(
              _entry(
                forms: const [
                  WordForm(form: 'ran', label: '过去式'),
                  WordForm(form: 'running', label: '现在分词'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('ran'), findsOneWidget);
    expect(find.text('过去式'), findsOneWidget);
    expect(find.text('running'), findsOneWidget);
    expect(find.text('现在分词'), findsOneWidget);
  });

  testWidgets('学习提示逐条渲染', (tester) async {
    await tester.pumpWidget(
      _wrap(
        view(
          LookupLoaded(AiDictResult(_entry(learnerTips: const ['提示一', '提示二']))),
        ),
      ),
    );
    expect(find.text('提示一'), findsOneWidget);
    expect(find.text('提示二'), findsOneWidget);
  });

  testWidgets('空结果显示 aiNoAnalysis', (tester) async {
    const empty = DictionaryEntry(
      headword: 'run',
      pronunciation: Pronunciation(uk: '', us: ''),
      meanings: [],
      commonExpressions: [],
      wordFamily: [],
      forms: [],
      etymology: '',
      learnerTips: [],
    );
    await tester.pumpWidget(_wrap(view(LookupLoaded(AiDictResult(empty)))));
    expect(find.text('No AI analysis available'), findsOneWidget);
  });

  testWidgets('加载中显示 Shimmer', (tester) async {
    await tester.pumpWidget(_wrap(view(const LookupLoading())));
    expect(find.byType(ShimmerPlaceholder), findsOneWidget);
  });

  testWidgets('需登录显示提示与登录按钮', (tester) async {
    await tester.pumpWidget(_wrap(view(const LookupAuthRequired())));
    expect(find.text('Sign in to use the AI dictionary'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('失败显示重试', (tester) async {
    await tester.pumpWidget(_wrap(view(LookupError(Exception('x')))));
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('词组过长显示提示且无重试按钮', (tester) async {
    await tester.pumpWidget(_wrap(view(const LookupPhraseTooLong())));
    expect(find.text('The phrase is too long. Select up to 8 words.'),
        findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
