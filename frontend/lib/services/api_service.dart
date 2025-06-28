// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../config/api_config.dart';
import '../utils/api_error_handler.dart';
import '../models/analysis_response_model.dart';

/// APIサービスクラス（履歴機能削除版）
class ApiService {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _analysisTimeout = Duration(seconds: 90);
  static const Duration _quickTimeout = Duration(seconds: 10); // 住所候補・GPS用

  /// 🔐 認証必須のHTTPヘッダーを取得
  static Future<Map<String, String>> _getAuthHeaders() async {
    ApiConfig.debugLog('🔒 認証必須ヘッダー取得開始');

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw DetailedApiException(
        message: 'ログインが必要です',
        errorType: 'AuthenticationRequired',
        statusCode: 401,
      );
    }

    try {
      final String? token = await user.getIdToken();
      ApiConfig.debugLog('認証必須ヘッダー取得成功: ${user.uid}');

      return ApiConfig.getAuthHeaders(token);
    } catch (e) {
      ApiConfig.errorLog('認証トークン取得エラー', e);
      throw DetailedApiException(
        message: '認証トークンの取得に失敗しました',
        errorType: 'TokenRetrievalError',
        statusCode: 401,
        originalError: e.toString(),
      );
    }
  }

  /// 🔍 レスポンス詳細解析
  static DetailedApiException _parseErrorResponse(http.Response response) {
    try {
      // JSON形式のエラーレスポンスを解析
      final Map<String, dynamic> errorJson = jsonDecode(response.body);
      return DetailedApiException.fromJson(errorJson, response.statusCode);
    } catch (jsonError) {
      // JSONでない場合（HTMLエラーページなど）
      ApiConfig.errorLog('レスポンス解析エラー', jsonError);

      String errorMessage;
      String errorType;

      // レスポンスボディの内容を確認
      final String responseBody = response.body;

      if (responseBody.contains('<!DOCTYPE html>')) {
        errorMessage = 'サーバーがHTMLエラーページを返しました';
        errorType = 'HTMLErrorResponse';
      } else if (responseBody.isEmpty) {
        errorMessage = 'サーバーから空のレスポンスが返されました';
        errorType = 'EmptyResponse';
      } else {
        errorMessage = 'レスポンスの解析に失敗しました';
        errorType = 'ResponseParseError';
      }

      return DetailedApiException(
        message: errorMessage,
        errorType: errorType,
        statusCode: response.statusCode,
        debugInfo: {
          'response_body_length': responseBody.length,
          'response_body_preview': responseBody.length > 200
              ? responseBody.substring(0, 200) + '...'
              : responseBody,
          'content_type': response.headers['content-type'] ?? 'unknown',
          'json_parse_error': jsonError.toString(),
        },
        originalError: jsonError.toString(),
      );
    }
  }

  /// 🎯 HTTP レスポンス統一処理
  static Map<String, dynamic> _handleResponse(
      http.Response response, String operation) {
    final int statusCode = response.statusCode;

    ApiConfig.networkLog(
        'POST', response.request?.url.toString() ?? 'unknown', statusCode);

    // デバッグ情報をログ出力
    ApiConfig.debugLog('🔍 レスポンス詳細:');
    ApiConfig.debugLog('  ステータスコード: $statusCode');
    ApiConfig.debugLog(
        '  Content-Type: ${response.headers['content-type'] ?? 'unknown'}');
    ApiConfig.debugLog('  レスポンスサイズ: ${response.body.length} bytes');

    if (response.body.isNotEmpty && response.body.length <= 1000) {
      ApiConfig.debugLog('  レスポンスボディ: ${response.body}');
    } else if (response.body.length > 1000) {
      ApiConfig.debugLog(
          '  レスポンスボディ(プレビュー): ${response.body.substring(0, 500)}...');
    }

    if (statusCode >= 200 && statusCode < 300) {
      // 成功レスポンス
      try {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        ApiConfig.debugLog('✅ $operation 成功');
        return responseData;
      } catch (e) {
        ApiConfig.errorLog('成功レスポンスのJSON解析エラー', e);
        throw DetailedApiException(
          message: '成功レスポンスの解析に失敗しました',
          errorType: 'SuccessResponseParseError',
          statusCode: statusCode,
          debugInfo: {
            'response_body': response.body,
            'parse_error': e.toString(),
          },
        );
      }
    } else {
      // エラーレスポンス
      ApiConfig.errorLog('$operation エラー', 'Status Code: $statusCode');
      final exception = _parseErrorResponse(response);

      // 詳細ログ出力
      ApiConfig.errorLog('詳細エラー情報', exception.toString());

      throw exception;
    }
  }

  /// 📸 カメラ分析API（ファイルから・認証必須）
  static Future<Map<String, dynamic>?> analyzeCameraImage({
    required File imageFile,
    Map<String, dynamic>? preferences,
  }) async {
    ApiConfig.debugLog('🔒 カメラ分析API開始（ファイルから・認証必須）');

    try {
      // 認証ヘッダー取得
      final Map<String, String> headers = await _getAuthHeaders();

      // Base64エンコード
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      ApiConfig.debugLog('📸 画像エンコード完了: ${base64Image.length} 文字');

      // リクエストボディ作成
      final Map<String, dynamic> requestBody = {
        ApiConfig.imageField: base64Image,
      };

      if (preferences != null) {
        requestBody[ApiConfig.preferencesField] = preferences;
        ApiConfig.debugLog('⚙️ ユーザー設定を含む');
      }

      ApiConfig.debugLog('📡 リクエスト送信開始...');

      // HTTP リクエスト
      final http.Response response = await http
          .post(
            ApiConfig.buildCameraAnalysisUri(),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(_analysisTimeout);

      return _handleResponse(response, 'カメラ分析API（ファイル）');
    } on DetailedApiException {
      // 既に詳細エラーの場合はそのまま再発生
      rethrow;
    } on http.ClientException catch (e) {
      ApiConfig.errorLog('HTTP Client エラー', e);
      throw DetailedApiException(
        message: 'ネットワーク接続に失敗しました',
        errorType: 'NetworkError',
        statusCode: 0,
        originalError: e.toString(),
      );
    } on SocketException catch (e) {
      ApiConfig.errorLog('Socket エラー', e);
      throw DetailedApiException(
        message: 'インターネット接続を確認してください',
        errorType: 'SocketError',
        statusCode: 0,
        originalError: e.toString(),
      );
    } on FormatException catch (e) {
      ApiConfig.errorLog('Format エラー', e);
      throw DetailedApiException(
        message: 'データ形式エラーが発生しました',
        errorType: 'FormatError',
        statusCode: 0,
        originalError: e.toString(),
      );
    } catch (e) {
      ApiConfig.errorLog('予期しないエラー', e);
      throw DetailedApiException(
        message: 'カメラ分析失敗: ${e.toString()}',
        errorType: 'UnknownError',
        statusCode: 0,
        originalError: e.toString(),
      );
    }
  }

  /// 🗺️ エリア分析API（段階的認証）
  static Future<Map<String, dynamic>?> analyzeArea({
    required String address,
    Map<String, dynamic>? preferences,
  }) async {
    ApiConfig.debugLog('🗺️ エリア分析API開始');

    try {
      Map<String, String> headers = ApiConfig.defaultHeaders;

      // 段階的認証：ログイン時は認証ヘッダーを追加
      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final String? token = await user.getIdToken();
          headers = ApiConfig.getAuthHeaders(token);
          ApiConfig.debugLog('🔐 認証ヘッダー追加完了');
        } else {
          ApiConfig.debugLog('🔓 未認証でアクセス');
        }
      } catch (e) {
        ApiConfig.debugLog('⚠️ 認証ヘッダー取得失敗、未認証として続行: $e');
      }

      // リクエストボディ作成
      final Map<String, dynamic> requestBody = {
        ApiConfig.addressField: address,
      };

      if (preferences != null) {
        requestBody[ApiConfig.preferencesField] = preferences;
      }

      // HTTP リクエスト
      final http.Response response = await http
          .post(
            ApiConfig.buildAreaAnalysisUri(),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(_defaultTimeout);

      return _handleResponse(response, 'エリア分析API');
    } on DetailedApiException {
      rethrow;
    } on http.ClientException catch (e) {
      throw DetailedApiException(
        message: 'ネットワーク接続に失敗しました',
        errorType: 'NetworkError',
        statusCode: 0,
        originalError: e.toString(),
      );
    } catch (e) {
      throw DetailedApiException(
        message: 'エリア分析失敗: ${e.toString()}',
        errorType: 'UnknownError',
        statusCode: 0,
        originalError: e.toString(),
      );
    }
  }

  /// 🏠 住所候補取得API（エラーハンドリング強化版）
  static Future<Map<String, dynamic>?> getAddressSuggestions({
    required String input,
    String types = 'address',
    String country = 'jp',
  }) async {
    ApiConfig.debugLog('🏠 住所候補取得API開始: $input');

    // 入力バリデーション
    if (input.trim().isEmpty) {
      ApiConfig.debugLog('⚠️ 空の入力のため候補取得をスキップ');
      return {'predictions': [], 'status': 'ZERO_RESULTS'};
    }

    if (input.trim().length < 2) {
      ApiConfig.debugLog('⚠️ 入力が短すぎるため候補取得をスキップ');
      return {'predictions': [], 'status': 'ZERO_RESULTS'};
    }

    try {
      final Map<String, dynamic> requestBody = {
        ApiConfig.inputField: input.trim(),
        ApiConfig.typesField: types,
        ApiConfig.countryField: country,
      };

      ApiConfig.debugLog('🔍 住所候補リクエスト送信:');
      ApiConfig.debugLog('  入力: ${input.trim()}');
      ApiConfig.debugLog('  タイプ: $types');
      ApiConfig.debugLog('  国: $country');

      final http.Response response = await http
          .post(
            ApiConfig.buildAddressSuggestionsUri(),
            headers: ApiConfig.defaultHeaders,
            body: jsonEncode(requestBody),
          )
          .timeout(_quickTimeout);

      final result = _handleResponse(response, '住所候補取得API');

      // レスポンス内容の確認
      if (result.containsKey('predictions')) {
        final predictions = result['predictions'] as List<dynamic>;
        ApiConfig.debugLog('✅ 住所候補取得成功: ${predictions.length}件');

        // デバッグ用：候補の詳細ログ
        for (int i = 0; i < predictions.length && i < 3; i++) {
          final prediction = predictions[i];
          ApiConfig.debugLog(
              '  候補${i + 1}: ${prediction['description'] ?? 'N/A'}');
        }
      } else {
        ApiConfig.debugLog('⚠️ predictionsフィールドが見つかりません');
      }

      return result;
    } on DetailedApiException catch (e) {
      // 詳細エラーログ
      ApiConfig.errorLog('住所候補取得API詳細エラー', e.toString());

      // 特定のエラータイプに応じた処理
      if (e.statusCode == 429) {
        // レート制限
        throw DetailedApiException(
          message: '住所検索の利用制限に達しました。しばらく待ってから再試行してください。',
          errorType: 'RateLimitExceeded',
          statusCode: e.statusCode,
          originalError: e.message,
        );
      } else if (e.statusCode >= 500) {
        // サーバーエラー
        throw DetailedApiException(
          message: '住所検索サービスが一時的に利用できません。',
          errorType: 'ServerError',
          statusCode: e.statusCode,
          originalError: e.message,
        );
      } else {
        // その他のエラー
        throw DetailedApiException(
          message: '住所候補の取得に失敗しました。',
          errorType: 'AddressSuggestionsError',
          statusCode: e.statusCode,
          debugInfo: {
            'input': input,
            'types': types,
            'country': country,
          },
          originalError: e.message,
        );
      }
    } on SocketException catch (e) {
      ApiConfig.errorLog('Socket エラー（住所候補）', e);
      throw DetailedApiException(
        message: 'インターネット接続を確認してください',
        errorType: 'NetworkError',
        statusCode: 0,
        debugInfo: {'input': input},
        originalError: e.toString(),
      );
    } on http.ClientException catch (e) {
      ApiConfig.errorLog('HTTP Client エラー（住所候補）', e);
      throw DetailedApiException(
        message: 'ネットワーク接続に失敗しました',
        errorType: 'NetworkError',
        statusCode: 0,
        debugInfo: {'input': input},
        originalError: e.toString(),
      );
    } catch (e) {
      ApiConfig.errorLog('予期しないエラー（住所候補）', e);
      throw DetailedApiException(
        message: '住所候補取得失敗: ${e.toString()}',
        errorType: 'UnknownError',
        statusCode: 0,
        debugInfo: {
          'input': input,
          'types': types,
          'country': country,
        },
        originalError: e.toString(),
      );
    }
  }

  /// 📍 ジオコーディングAPI（GPS→住所変換・エラーハンドリング強化）
  static Future<Map<String, dynamic>?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    ApiConfig.debugLog('📍 ジオコーディングAPI開始: ($latitude, $longitude)');

    // 座標バリデーション
    if (!_isValidCoordinates(latitude, longitude)) {
      ApiConfig.debugLog('⚠️ 無効な座標のためジオコーディングをスキップ');
      throw DetailedApiException(
        message: '無効な座標です',
        errorType: 'InvalidCoordinates',
        statusCode: 400,
        debugInfo: {'latitude': latitude, 'longitude': longitude},
      );
    }

    try {
      final Map<String, dynamic> requestBody = {
        ApiConfig.latitudeField: latitude,
        ApiConfig.longitudeField: longitude,
      };

      ApiConfig.debugLog('🗺️ ジオコーディングリクエスト送信');

      final http.Response response = await http
          .post(
            ApiConfig.buildGeocodingUri(),
            headers: ApiConfig.defaultHeaders,
            body: jsonEncode(requestBody),
          )
          .timeout(_quickTimeout);

      final result = _handleResponse(response, 'ジオコーディングAPI');

      if (result.containsKey('formatted_address')) {
        ApiConfig.debugLog('✅ ジオコーディング成功: ${result['formatted_address']}');
      } else {
        ApiConfig.debugLog('⚠️ formatted_addressフィールドが見つかりません');
      }

      return result;
    } on DetailedApiException catch (e) {
      ApiConfig.errorLog('ジオコーディングAPI詳細エラー', e.toString());

      if (e.statusCode == 404) {
        throw DetailedApiException(
          message: 'この位置の住所が見つかりませんでした',
          errorType: 'AddressNotFound',
          statusCode: e.statusCode,
          debugInfo: {'latitude': latitude, 'longitude': longitude},
          originalError: e.message,
        );
      } else {
        throw DetailedApiException(
          message: 'GPS位置から住所の取得に失敗しました',
          errorType: 'ReverseGeocodingError',
          statusCode: e.statusCode,
          debugInfo: {'latitude': latitude, 'longitude': longitude},
          originalError: e.message,
        );
      }
    } on SocketException catch (e) {
      throw DetailedApiException(
        message: 'インターネット接続を確認してください',
        errorType: 'NetworkError',
        statusCode: 0,
        debugInfo: {'latitude': latitude, 'longitude': longitude},
        originalError: e.toString(),
      );
    } catch (e) {
      throw DetailedApiException(
        message: 'ジオコーディング失敗: ${e.toString()}',
        errorType: 'UnknownError',
        statusCode: 0,
        debugInfo: {'latitude': latitude, 'longitude': longitude},
        originalError: e.toString(),
      );
    }
  }

  /// 座標の妥当性をチェック
  static bool _isValidCoordinates(double latitude, double longitude) {
    // 日本の大まかな座標範囲でチェック
    const double minLat = 20.0; // 沖縄
    const double maxLat = 46.0; // 北海道
    const double minLng = 122.0; // 西端
    const double maxLng = 154.0; // 東端

    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLng &&
        longitude <= maxLng;
  }

  /// ⚕️ ヘルスチェックAPI
  static Future<Map<String, dynamic>?> healthCheck() async {
    ApiConfig.debugLog('⚕️ ヘルスチェックAPI開始');

    try {
      final http.Response response = await http
          .get(
            ApiConfig.buildHealthCheckUri(),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response, 'ヘルスチェックAPI');
    } on DetailedApiException {
      rethrow;
    } catch (e) {
      throw DetailedApiException(
        message: 'ヘルスチェック失敗: ${e.toString()}',
        errorType: 'UnknownError',
        statusCode: 0,
        originalError: e.toString(),
      );
    }
  }

  /// 🔍 デバッグ情報取得API
  static Future<Map<String, dynamic>?> getDebugInfo() async {
    ApiConfig.debugLog('🔍 デバッグ情報取得API開始');

    try {
      final http.Response response = await http
          .get(
            Uri.parse(ApiConfig.debugInfoUrl),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response, 'デバッグ情報取得API');
    } on DetailedApiException {
      rethrow;
    } catch (e) {
      throw DetailedApiException(
        message: 'デバッグ情報取得失敗: ${e.toString()}',
        errorType: 'UnknownError',
        statusCode: 0,
        originalError: e.toString(),
      );
    }
  }

  /// 🧪 住所候補API動作テスト
  static Future<bool> testAddressSuggestionsAPI() async {
    try {
      ApiConfig.debugLog('🧪 住所候補APIテスト開始');

      // テスト入力
      final testInputs = ['東京', '渋谷駅', '大阪市'];

      for (final input in testInputs) {
        ApiConfig.debugLog('  テスト入力: $input');

        final result = await getAddressSuggestions(input: input);

        if (result != null && result.containsKey('predictions')) {
          final predictions = result['predictions'] as List<dynamic>;
          ApiConfig.debugLog('  結果: ${predictions.length}件の候補');

          if (predictions.isNotEmpty) {
            ApiConfig.debugLog(
                '  最初の候補: ${predictions[0]['description'] ?? 'N/A'}');
          }
        } else {
          ApiConfig.debugLog('  結果: 予期しない形式');
          return false;
        }

        // テスト間隔
        await Future.delayed(const Duration(milliseconds: 500));
      }

      ApiConfig.debugLog('✅ 住所候補APIテスト完了');
      return true;
    } catch (e) {
      ApiConfig.errorLog('❌ 住所候補APIテスト失敗', e);
      return false;
    }
  }

  /// 🧪 ジオコーディングAPI動作テスト
  static Future<bool> testGeocodingAPI() async {
    try {
      ApiConfig.debugLog('🧪 ジオコーディングAPIテスト開始');

      // テスト座標（東京駅周辺）
      final testCoordinates = [
        {'lat': 35.6812, 'lng': 139.7671}, // 東京駅
        {'lat': 35.6580, 'lng': 139.7016}, // 渋谷駅
      ];

      for (final coord in testCoordinates) {
        final lat = coord['lat']!;
        final lng = coord['lng']!;

        ApiConfig.debugLog('  テスト座標: ($lat, $lng)');

        final result = await reverseGeocode(
          latitude: lat,
          longitude: lng,
        );

        if (result != null && result.containsKey('formatted_address')) {
          ApiConfig.debugLog('  結果: ${result['formatted_address']}');
        } else {
          ApiConfig.debugLog('  結果: 予期しない形式');
          return false;
        }

        // テスト間隔
        await Future.delayed(const Duration(milliseconds: 500));
      }

      ApiConfig.debugLog('✅ ジオコーディングAPIテスト完了');
      return true;
    } catch (e) {
      ApiConfig.errorLog('❌ ジオコーディングAPIテスト失敗', e);
      return false;
    }
  }

  /// 🔬 API統合テスト
  static Future<Map<String, bool>> runIntegrationTests() async {
    ApiConfig.debugLog('🔬 API統合テスト開始');

    final results = <String, bool>{};

    // ヘルスチェック
    try {
      await healthCheck();
      results['health_check'] = true;
    } catch (e) {
      results['health_check'] = false;
    }

    // 住所候補API
    results['address_suggestions'] = await testAddressSuggestionsAPI();

    // ジオコーディングAPI
    results['geocoding'] = await testGeocodingAPI();

    ApiConfig.debugLog('🔬 API統合テスト結果:');
    results.forEach((test, passed) {
      ApiConfig.debugLog('  ${passed ? "✅" : "❌"} $test');
    });

    return results;
  }
}
