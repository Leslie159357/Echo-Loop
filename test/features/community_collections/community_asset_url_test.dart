import 'package:echo_loop/features/community_collections/models/community_asset_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const globalUrl = 'https://global.example/media.mp3';
  const chinaUrl = 'https://china.example/media.mp3';

  test('中国地区有镜像时选择中国 URL', () {
    expect(
      communityAssetUrlForRegion(
        globalUrl: globalUrl,
        chinaUrl: chinaUrl,
        isChinaUser: true,
      ),
      chinaUrl,
    );
  });

  test('中国地区没有镜像时回退到全球 URL', () {
    expect(
      communityAssetUrlForRegion(
        globalUrl: globalUrl,
        chinaUrl: null,
        isChinaUser: true,
      ),
      globalUrl,
    );
    expect(
      communityAssetUrlForRegion(
        globalUrl: null,
        chinaUrl: chinaUrl,
        isChinaUser: true,
      ),
      chinaUrl,
    );
    expect(
      communityAssetUrlForRegion(
        globalUrl: globalUrl,
        chinaUrl: '  ',
        isChinaUser: true,
      ),
      globalUrl,
    );
  });

  test('其他地区始终选择全球 URL', () {
    expect(
      communityAssetUrlForRegion(
        globalUrl: globalUrl,
        chinaUrl: chinaUrl,
        isChinaUser: false,
      ),
      globalUrl,
    );
  });
}
