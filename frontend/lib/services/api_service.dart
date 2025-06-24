// lib/services/api_service.dart - Google Maps API統合完全版

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // 🔒 認証ヘッダーを取得
  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();
        headers[ApiConfig.authorizationHeader] =
            '${ApiConfig.bearerPrefix} $idToken';
        ApiConfig.debugLog('IDトークン取得成功');
      } else {
        ApiConfig.debugLog('ユーザー未ログイン - 認証ヘッダーなし');
      }
    } catch (e) {
      ApiConfig.errorLog('IDトークン取得エラー', e);
    }

    return headers;
  }

  // 🔒 認証必須ヘッダーを取得（ログイン必須）
  static Future<Map<String, String>> _getRequiredAuthHeaders() async {
    final headers = await _getAuthHeaders();

    if (!headers.containsKey(ApiConfig.authorizationHeader)) {
      throw Exception('認証が必要です。ログインしてください。');
    }

    return headers;
  }

  // 🎯 実分析API機能

  /// 📷 カメラ分析API（認証必須）
  static Future<Map<String, dynamic>?> analyzeCameraImage({
    required File imageFile,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      ApiConfig.debugLog('カメラ分析API開始');

      // 画像サイズチェック
      final imageBytes = await imageFile.readAsBytes();
      if (imageBytes.length > ApiConfig.maxImageSizeBytes) {
        throw Exception(
            '画像サイズが上限（${ApiConfig.maxImageSizeBytes / 1024 / 1024}MB）を超えています');
      }

      // Base64エンコード
      final imageBase64 = base64Encode(imageBytes);

      // 認証ヘッダー取得（必須）
      final headers = await _getRequiredAuthHeaders();

      // リクエストボディ構築
      final requestBody = {
        ApiConfig.imageField: imageBase64,
        ApiConfig.preferencesField: preferences ?? {},
      };

      final response = await http
          .post(
            ApiConfig.buildCameraAnalysisUri(),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(ApiConfig.analysisTimeout);

      ApiConfig.networkLog(
          'POST', ApiConfig.cameraAnalysisEndpoint, response.statusCode);

      if (response.statusCode == ApiConfig.httpOk) {
        final responseData = jsonDecode(response.body);

        if (ApiConfig.isValidResponse(responseData)) {
          ApiConfig.debugLog('カメラ分析成功');
          return responseData;
        } else {
          throw Exception(ApiConfig.extractErrorMessage(responseData));
        }
      } else if (response.statusCode == ApiConfig.httpUnauthorized) {
        throw Exception('認証エラー。再ログインしてください。');
      } else {
        final errorMsg = _extractHttpErrorMessage(response);
        throw Exception('カメラ分析失敗: $errorMsg');
      }
    } catch (e) {
      ApiConfig.errorLog('カメラ分析API エラー', e);
      rethrow;
    }
  }

  /// 🗺️ エリア分析API（段階的認証）
  static Future<Map<String, dynamic>?> analyzeArea({
    required String address,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      ApiConfig.debugLog('エリア分析API開始: $address');

      // 住所検証
      if (address.trim().isEmpty) {
        throw Exception('住所が入力されていません');
      }

      // 認証ヘッダー取得（任意）
      final headers = await _getAuthHeaders();

      // リクエストボディ構築
      final requestBody = {
        ApiConfig.addressField: address.trim(),
        ApiConfig.preferencesField: preferences ?? {},
      };

      final response = await http
          .post(
            ApiConfig.buildAreaAnalysisUri(),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(ApiConfig.analysisTimeout);

      ApiConfig.networkLog(
          'POST', ApiConfig.areaAnalysisEndpoint, response.statusCode);

      if (response.statusCode == ApiConfig.httpOk) {
        final responseData = jsonDecode(response.body);

        if (ApiConfig.isValidResponse(responseData)) {
          final isPersonalized =
              responseData[ApiConfig.isPersonalizedField] ?? false;
          ApiConfig.debugLog(isPersonalized ? '個人化エリア分析完了' : '基本エリア分析完了');
          return responseData;
        } else {
          throw Exception(ApiConfig.extractErrorMessage(responseData));
        }
      } else {
        final errorMsg = _extractHttpErrorMessage(response);
        throw Exception('エリア分析失敗: $errorMsg');
      }
    } catch (e) {
      ApiConfig.errorLog('エリア分析API エラー', e);
      rethrow;
    }
  }

  // 🗺️ Google Maps API統合機能（新規追加）

  /// 📍 住所候補取得API（認証不要）
  static Future<List<Map<String, dynamic>>> getAddressSuggestions({
    required String input,
    String types = 'address',
    String country = 'jp',
  }) async {
    try {
      ApiConfig.debugLog('住所候補取得開始: $input');

      // 入力検証
      if (input.trim().length < 2) {
        ApiConfig.debugLog('入力が短すぎます（2文字未満）');
        return [];
      }

      // ヘッダー取得（認証不要）
      final headers = ApiConfig.defaultHeaders;

      // リクエストボディ構築
      final requestBody = {
        ApiConfig.inputField: input.trim(),
        ApiConfig.typesField: types,
        ApiConfig.countryField: country,
      };

      final response = await http
          .post(
            ApiConfig.buildAddressSuggestionsUri(),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(
              Duration(seconds: ApiConfig.addressSuggestionsTimeoutSeconds));

      ApiConfig.networkLog(
          'POST', ApiConfig.addressSuggestionsEndpoint, response.statusCode);

      if (response.statusCode == ApiConfig.httpOk) {
        final responseData = jsonDecode(response.body);

        if (responseData.containsKey(ApiConfig.predictionsField) &&
            responseData[ApiConfig.statusField] == ApiConfig.successStatus) {
          final predictions = List<Map<String, dynamic>>.from(
              responseData[ApiConfig.predictionsField]);
          ApiConfig.debugLog('住所候補取得成功: ${predictions.length}件');
          return predictions;
        } else {
          throw Exception(ApiConfig.extractErrorMessage(responseData));
        }
      } else if (response.statusCode == ApiConfig.httpServiceUnavailable) {
        throw Exception('Google Maps APIが利用できません');
      } else {
        final errorMsg = _extractHttpErrorMessage(response);
        throw Exception('住所候補取得失敗: $errorMsg');
      }
    } catch (e) {
      ApiConfig.errorLog('住所候補取得API エラー', e);
      return []; // エラー時は空配列を返す
    }
  }

  /// 🌍 GPS座標から住所取得API（リバースジオコーディング・認証不要）
  static Future<Map<String, dynamic>?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      ApiConfig.debugLog('GPS→住所変換開始: ($latitude, $longitude)');

      // 座標検証
      if (latitude < -90 || latitude > 90) {
        throw Exception('緯度の値が正しくありません（-90～90度）');
      }
      if (longitude < -180 || longitude > 180) {
        throw Exception('経度の値が正しくありません（-180～180度）');
      }

      // ヘッダー取得（認証不要）
      final headers = ApiConfig.defaultHeaders;

      // リクエストボディ構築
      final requestBody = {
        ApiConfig.latitudeField: latitude,
        ApiConfig.longitudeField: longitude,
      };

      final response = await http
          .post(
            ApiConfig.buildGeocodingUri(),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: ApiConfig.geocodingTimeoutSeconds));

      ApiConfig.networkLog(
          'POST', ApiConfig.geocodingEndpoint, response.statusCode);

      if (response.statusCode == ApiConfig.httpOk) {
        final responseData = jsonDecode(response.body);

        if (responseData.containsKey(ApiConfig.formattedAddressField)) {
          ApiConfig.debugLog(
              'GPS→住所変換成功: ${responseData[ApiConfig.formattedAddressField]}');
          return responseData;
        } else {
          throw Exception(ApiConfig.extractErrorMessage(responseData));
        }
      } else if (response.statusCode == ApiConfig.httpNotFound) {
        throw Exception('指定された座標に対応する住所が見つかりません');
      } else if (response.statusCode == ApiConfig.httpServiceUnavailable) {
        throw Exception('Google Maps APIが利用できません');
      } else {
        final errorMsg = _extractHttpErrorMessage(response);
        throw Exception('GPS→住所変換失敗: $errorMsg');
      }
    } catch (e) {
      ApiConfig.errorLog('GPS→住所変換API エラー', e);
      return null; // エラー時はnullを返す
    }
  }

  // 📋 履歴管理API機能

  /// 分析履歴取得API（認証必須）
  static Future<List<Map<String, dynamic>>> getAnalysisHistory({
    int limit = 20,
  }) async {
    try {
      ApiConfig.debugLog('分析履歴取得開始 (limit: $limit)');

      // 認証ヘッダー取得（必須）
      final headers = await _getRequiredAuthHeaders();

      final response = await http
          .get(
            ApiConfig.buildHistoryListUri(limit: limit),
            headers: headers,
          )
          .timeout(ApiConfig.defaultTimeout);

      ApiConfig.networkLog(
          'GET', ApiConfig.analysisHistoryEndpoint, response.statusCode);

      if (response.statusCode == ApiConfig.httpOk) {
        final responseData = jsonDecode(response.body);

        if (responseData.containsKey(ApiConfig.historyField)) {
          final historyList = List<Map<String, dynamic>>.from(
              responseData[ApiConfig.historyField]);
          ApiConfig.debugLog('履歴取得成功: ${historyList.length}件');
          return historyList;
        } else {
          throw Exception('履歴データの形式が正しくありません');
        }
      } else if (response.statusCode == ApiConfig.httpUnauthorized) {
        throw Exception('認証エラー。再ログインしてください。');
      } else {
        final errorMsg = _extractHttpErrorMessage(response);
        throw Exception('履歴取得失敗: $errorMsg');
      }
    } catch (e) {
      ApiConfig.errorLog('履歴取得API エラー', e);
      rethrow;
    }
  }

  /// 分析履歴削除API（認証必須）
  static Future<void> deleteAnalysisHistory(String historyId) async {
    try {
      ApiConfig.debugLog('分析履歴削除開始: $historyId');

      if (historyId.trim().isEmpty) {
        throw Exception('履歴IDが指定されていません');
      }

      // 認証ヘッダー取得（必須）
      final headers = await _getRequiredAuthHeaders();

      final response = await http
          .delete(
            ApiConfig.buildHistoryDeleteUri(historyId),
            headers: headers,
          )
          .timeout(ApiConfig.defaultTimeout);

      ApiConfig.networkLog(
          'DELETE', ApiConfig.historyDeleteUrl(historyId), response.statusCode);

      if (response.statusCode == ApiConfig.httpOk) {
        ApiConfig.debugLog('履歴削除成功: $historyId');
      } else if (response.statusCode == ApiConfig.httpUnauthorized) {
        throw Exception('認証エラー。再ログインしてください。');
      } else if (response.statusCode == ApiConfig.httpNotFound) {
        throw Exception('指定された履歴が見つかりません');
      } else {
        final errorMsg = _extractHttpErrorMessage(response);
        throw Exception('履歴削除失敗: $errorMsg');
      }
    } catch (e) {
      ApiConfig.errorLog('履歴削除API エラー', e);
      rethrow;
    }
  }

  // 🌐 ヘルスチェック・デバッグ機能

  /// Cloud Runサービスヘルスチェック
  static Future<Map<String, dynamic>?> checkServiceHealth() async {
    try {
      ApiConfig.debugLog('Cloud Runサービスヘルスチェック開始');

      final response = await http
          .get(
            ApiConfig.buildHealthCheckUri(),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(ApiConfig.quickTimeout);

      ApiConfig.networkLog(
          'GET', ApiConfig.healthEndpoint, response.statusCode);

      if (response.statusCode == ApiConfig.httpOk) {
        final responseData = jsonDecode(response.body);
        ApiConfig.debugLog('ヘルスチェック成功');
        return responseData;
      } else {
        final errorMsg = _extractHttpErrorMessage(response);
        throw Exception('ヘルスチェック失敗: $errorMsg');
      }
    } catch (e) {
      ApiConfig.errorLog('ヘルスチェック エラー', e);
      return null;
    }
  }

  /// デバッグ情報取得
  static Future<Map<String, dynamic>?> getDebugInfo() async {
    try {
      ApiConfig.debugLog('デバッグ情報取得開始');

      final response = await http
          .get(
            Uri.parse(ApiConfig.debugInfoUrl),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(ApiConfig.quickTimeout);

      ApiConfig.networkLog('GET', ApiConfig.debugEndpoint, response.statusCode);

      if (response.statusCode == ApiConfig.httpOk) {
        final responseData = jsonDecode(response.body);
        ApiConfig.debugLog('デバッグ情報取得成功');
        return responseData;
      } else {
        final errorMsg = _extractHttpErrorMessage(response);
        throw Exception('デバッグ情報取得失敗: $errorMsg');
      }
    } catch (e) {
      ApiConfig.errorLog('デバッグ情報取得 エラー', e);
      return null;
    }
  }

  // 🌐 ユーティリティ機能

  /// 接続性テスト（ネットワーク確認）
  static Future<bool> testConnectivity() async {
    try {
      ApiConfig.debugLog('ネットワーク接続テスト開始');

      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'User-Agent': ApiConfig.userAgent},
      ).timeout(const Duration(seconds: 10));

      final isConnected = response.statusCode == ApiConfig.httpOk;
      ApiConfig.debugLog('ネットワーク接続: ${isConnected ? "成功" : "失敗"}');
      return isConnected;
    } catch (e) {
      ApiConfig.errorLog('ネットワーク接続エラー', e);
      return false;
    }
  }

  /// Cloud Runサービス全体の動作確認
  static Future<Map<String, bool>> checkAllEndpoints() async {
    final results = <String, bool>{};

    // ヘルスチェック
    try {
      final health = await checkServiceHealth();
      results['health'] = health != null;
    } catch (e) {
      results['health'] = false;
    }

    // デバッグ情報
    try {
      final debug = await getDebugInfo();
      results['debug'] = debug != null;
    } catch (e) {
      results['debug'] = false;
    }

    // 住所候補取得テスト
    try {
      final suggestions = await getAddressSuggestions(input: '東京');
      results['address_suggestions'] = suggestions.isNotEmpty;
    } catch (e) {
      results['address_suggestions'] = false;
    }

    // ジオコーディングテスト
    try {
      final geocoding = await getAddressFromCoordinates(
          latitude: 35.6762, longitude: 139.6503);
      results['geocoding'] = geocoding != null;
    } catch (e) {
      results['geocoding'] = false;
    }

    return results;
  }

  /// リトライ機能付きHTTPリクエスト
  static Future<http.Response> _retryableRequest({
    required Future<http.Response> Function() request,
    int maxRetries = 3,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        ApiConfig.debugLog('リクエスト試行 $attempt/$maxRetries');
        return await request();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        ApiConfig.debugLog('試行 $attempt 失敗: $e');

        if (attempt < maxRetries) {
          await Future.delayed(ApiConfig.retryDelay);
        }
      }
    }

    throw lastException ?? Exception('リクエストが失敗しました');
  }

  // 🔧 内部ヘルパーメソッド

  /// HTTPエラーメッセージ抽出
  static String _extractHttpErrorMessage(http.Response response) {
    try {
      final responseData = jsonDecode(response.body);
      return ApiConfig.extractErrorMessage(responseData);
    } catch (e) {
      return 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Unknown Error"}';
    }
  }

  /// Base64画像データ検証
  static bool _isValidBase64Image(String base64String) {
    try {
      final bytes = base64Decode(base64String);
      return bytes.isNotEmpty && bytes.length <= ApiConfig.maxImageSizeBytes;
    } catch (e) {
      return false;
    }
  }

  /// レスポンス時間測定
  static Future<T> _measureExecutionTime<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();
      ApiConfig.debugLog(
          '$operationName 実行時間: ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      ApiConfig.errorLog(
          '$operationName 失敗 (${stopwatch.elapsedMilliseconds}ms)', e);
      rethrow;
    }
  }

  // 📊 統計・メトリクス

  /// API呼び出し統計（デバッグ用）
  static final Map<String, int> _apiCallCounts = {};
  static final Map<String, int> _apiErrorCounts = {};

  static void _incrementApiCall(String endpoint) {
    _apiCallCounts[endpoint] = (_apiCallCounts[endpoint] ?? 0) + 1;
  }

  static void _incrementApiError(String endpoint) {
    _apiErrorCounts[endpoint] = (_apiErrorCounts[endpoint] ?? 0) + 1;
  }

  /// API統計表示
  static void printApiStats() {
    print('📊 === API呼び出し統計 ===');
    _apiCallCounts.forEach((endpoint, count) {
      final errors = _apiErrorCounts[endpoint] ?? 0;
      final successRate = count > 0
          ? ((count - errors) / count * 100).toStringAsFixed(1)
          : '0.0';
      print('   $endpoint: $count回 (成功率: $successRate%)');
    });
    print('==============================');
  }

  /// Google Maps API統合統計
  static void printGoogleMapsStats() {
    print('🗺️ === Google Maps API統計 ===');
    final addressSuggestionsCalls =
        _apiCallCounts[ApiConfig.addressSuggestionsEndpoint] ?? 0;
    final geocodingCalls = _apiCallCounts[ApiConfig.geocodingEndpoint] ?? 0;
    final addressSuggestionsErrors =
        _apiErrorCounts[ApiConfig.addressSuggestionsEndpoint] ?? 0;
    final geocodingErrors = _apiErrorCounts[ApiConfig.geocodingEndpoint] ?? 0;

    print(
        '   住所候補取得: $addressSuggestionsCalls回 (エラー: $addressSuggestionsErrors回)');
    print('   GPS→住所変換: $geocodingCalls回 (エラー: $geocodingErrors回)');
    print('   総Google Maps呼び出し: ${addressSuggestionsCalls + geocodingCalls}回');
    print('===============================');
  }
}
