import 'package:flutter_dotenv/flutter_dotenv.dart';

// Google Maps API設定
// .envファイルにAPIキーを設定してください
// 詳細は GOOGLE_MAPS_SETUP.md を参照

class ApiKeys {
  // .envファイルからGoogle Places APIキーを取得
  static String get googlePlacesApiKey {
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'Google Places APIキーが設定されていません。\n'
        '.envファイルにGOOGLE_PLACES_API_KEYを設定してください。\n'
        '詳細はGOOGLE_MAPS_SETUP.mdを参照してください。'
      );
    }
    return apiKey;
  }
}
