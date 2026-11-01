// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'featured_podcasts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$featuredPodcastsHash() => r'93c70d9d3663e239bfa51a5357d82a5e337eec07';

/// 管理精选 Podcast 的缓存恢复、页面刷新和游标分页。
///
/// Copied from [FeaturedPodcasts].
@ProviderFor(FeaturedPodcasts)
final featuredPodcastsProvider =
    AsyncNotifierProvider<
      FeaturedPodcasts,
      FeaturedPodcastDiscoveryState
    >.internal(
      FeaturedPodcasts.new,
      name: r'featuredPodcastsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$featuredPodcastsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FeaturedPodcasts = AsyncNotifier<FeaturedPodcastDiscoveryState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
