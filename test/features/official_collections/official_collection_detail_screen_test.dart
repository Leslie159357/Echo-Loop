import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/official_collections/data/official_catalog_service.dart';
import 'package:echo_loop/features/official_collections/models/catalog.dart';
import 'package:echo_loop/features/official_collections/screens/official_collection_detail_screen.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';
import 'fixtures/catalog_fixtures.dart';

class _FakeCatalogService extends OfficialCatalogService {
  final CatalogSnapshot? snapshot;

  _FakeCatalogService(this.snapshot)
    : super.withDio(dio: Dio(), resolveDir: () async => Directory.systemTemp);

  @override
  CatalogSnapshot? get cached => snapshot;

  @override
  bool get hasInitialized => true;
}

void main() {
  testWidgets('未加入官方空合集详情页仍保留可下拉刷新的滚动区域', (tester) async {
    final snapshot = makeSnapshot(
      collections: [
        makeCatalogCollection(
          id: 'empty-official',
          name: 'Empty Official',
          audios: const [],
        ),
      ],
    );

    await tester.pumpWidget(
      createTestApp(
        const OfficialCollectionDetailScreen(remoteId: 'empty-official'),
        overrides: [
          appSettingsProvider.overrideWith(
            () => TestAppSettings(const AppSettingsState()),
          ),
          officialCatalogServiceProvider.overrideWithValue(
            _FakeCatalogService(snapshot),
          ),
          audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          tagListProvider.overrideWith(() => TestTagList()),
          listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('This collection has no audios yet'), findsOneWidget);

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());
  });
}
