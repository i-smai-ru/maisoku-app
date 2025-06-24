// lib/utils/api_error_handler.dart

import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Maisoku AI v1.0: 統一APIエラーハンドリング
/// Cloud Run API統合・段階的認証・Firebase Crashlytics対応
class ApiErrorHandler {
  // === v1.0 Cloud Run APIエンドポイント定義 ===

  // Cloud Run メインAPI
  static const String CLOUD_RUN_CAMERA_ANALYSIS = 'cloud_run_camera_analysis';
  static const String CLOUD_RUN_AREA_ANALYSIS = 'cloud_run_area_analysis';
  static const String CLOUD_RUN_ANALYSIS_HISTORY = 'cloud_run_analysis_history';

  // Legacy API（フォールバック用）
  static const String GEMINI_VISION = 'gemini_vision';
  static const String GEMINI_TEXT = 'gemini_text';

  // Firebase API
  static const String FIREBASE_AUTH = 'firebase_auth';
  static const String FIRESTORE_READ = 'firestore_read';
  static const String FIRESTORE_WRITE = 'firestore_write';
  static const String FIREBASE_STORAGE = 'firebase_storage';

  // Google Maps API
  static const String GOOGLE_MAPS_GEOCODING = 'google_maps_geocoding';
  static const String GOOGLE_PLACES = 'google_places';

  /// === Cloud Run API統合エラーハンドリング ===

  /// Cloud Run APIエラーの統一処理
  static String handleCloudRunError(
      String endpoint, int? statusCode, dynamic error,
      {Map<String, dynamic>? requestData}) {
    String userMessage = 'サービスに接続できませんでした';
    String apiType = _getApiTypeFromEndpoint(endpoint);

    // ステータスコード別エラー処理
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          userMessage = 'リクエストの形式に問題があります';
          break;
        case 401:
          userMessage = '認証に失敗しました。ログインし直してください';
          break;
        case 403:
          userMessage = 'このサービスを利用する権限がありません';
          break;
        case 404:
          userMessage = 'サービスが見つかりません';
          break;
        case 429:
          userMessage = 'アクセス制限中です。しばらくお待ちください';
          break;
        case 500:
        case 502:
        case 503:
          userMessage = 'サーバーで問題が発生しています';
          break;
        case 504:
          userMessage = '処理がタイムアウトしました';
          break;
        default:
          userMessage = 'ネットワークエラーが発生しました（$statusCode）';
      }
    }

    // エラー詳細をCrashlyticsに記録
    recordError(apiType, userMessage, {
      'cloud_run_endpoint': endpoint,
      'status_code': statusCode,
      'error_message': error.toString(),
      'request_data_size': requestData?.length ?? 0,
      'api_version': 'v1.0',
      'error_type': 'cloud_run_api',
    });

    return userMessage;
  }

  /// エンドポイントからAPIタイプを判定
  static String _getApiTypeFromEndpoint(String endpoint) {
    if (endpoint.contains('camera-analysis')) return CLOUD_RUN_CAMERA_ANALYSIS;
    if (endpoint.contains('area-analysis')) return CLOUD_RUN_AREA_ANALYSIS;
    if (endpoint.contains('analysis-history'))
      return CLOUD_RUN_ANALYSIS_HISTORY;
    return 'cloud_run_unknown';
  }

  /// === 段階的認証エラーハンドリング ===

  /// 認証エラーの段階的処理
  static String handleAuthError(dynamic error,
      {bool isPersonalizedFeature = false}) {
    String errorMessage = error.toString().toLowerCase();
    String userMessage;

    if (errorMessage.contains('network')) {
      userMessage = 'ネットワーク接続を確認してください';
    } else if (errorMessage.contains('user-disabled')) {
      userMessage = 'アカウントが無効になっています';
    } else if (errorMessage.contains('too-many-requests')) {
      userMessage = 'ログイン試行回数が多すぎます。しばらくお待ちください';
    } else if (errorMessage.contains('popup-closed')) {
      userMessage = 'ログインがキャンセルされました';
    } else {
      userMessage =
          isPersonalizedFeature ? '個人化機能の利用にはログインが必要です' : 'ログインに失敗しました';
    }

    // 認証エラーを記録
    recordError(FIREBASE_AUTH, userMessage, {
      'error_type': 'authentication',
      'is_personalized_feature': isPersonalizedFeature,
      'original_error': error.toString(),
    });

    return userMessage;
  }

  /// === ネットワークエラーハンドリング ===

  /// ネットワークエラーの統一処理
  static String handleNetworkError(String apiType, dynamic error) {
    String errorString = error.toString().toLowerCase();
    String userMessage = 'ネットワークエラーが発生しました';

    // エラー種別による分類
    if (errorString.contains('timeout') || errorString.contains('deadline')) {
      userMessage = 'タイムアウトが発生しました。もう一度お試しください';
    } else if (errorString.contains('no internet') ||
        errorString.contains('network unreachable')) {
      userMessage = 'インターネット接続を確認してください';
    } else if (errorString.contains('host') ||
        errorString.contains('connection')) {
      userMessage = 'サーバーに接続できませんでした';
    } else if (errorString.contains('certificate') ||
        errorString.contains('ssl')) {
      userMessage = 'セキュリティ証明書の問題が発生しました';
    }

    // プラットフォーム固有のエラー処理
    if (Platform.isIOS && errorString.contains('nsurlerror')) {
      userMessage = 'ネットワーク設定を確認してください';
    } else if (Platform.isAndroid && errorString.contains('socketexception')) {
      userMessage = 'Wi-Fiまたはモバイルデータ接続を確認してください';
    }

    recordError(apiType, userMessage, {
      'error_type': 'network',
      'platform': Platform.operatingSystem,
      'original_error': error.toString(),
    });

    return userMessage;
  }

  /// === Firebase Crashlytics統合 ===

  /// エラーをCrashlyticsに記録
  static void recordError(
      String apiType, String errorMessage, Map<String, dynamic> context) {
    try {
      // エラー情報をCrashlyticsに送信
      FirebaseCrashlytics.instance.recordError(
        Exception('Maisoku AI v1.0 Error: $apiType'),
        StackTrace.current,
        information: [
          'API Type: $apiType',
          'Error: $errorMessage',
          'Context: ${context.toString()}',
          'Timestamp: ${DateTime.now().toIso8601String()}',
          'App Version: v1.0',
        ],
      );

      // カスタムキーでエラーをカテゴリ分け
      FirebaseCrashlytics.instance.setCustomKey('api_error_type', apiType);
      FirebaseCrashlytics.instance.setCustomKey('app_version', 'v1.0');
      FirebaseCrashlytics.instance
          .setCustomKey('feature_category', _getFeatureCategory(apiType));
      FirebaseCrashlytics.instance.setCustomKey(
          'error_timestamp', DateTime.now().millisecondsSinceEpoch);

      _debugPrint('✅ Crashlytics記録完了: $apiType - $errorMessage');
    } catch (e) {
      _debugPrint('❌ Crashlytics記録失敗: $e');
    }
  }

  /// 重要エラーの記録（即座対応が必要）
  static void recordCriticalError(
      String apiType, String errorMessage, Map<String, dynamic> context) {
    try {
      // 重要度マーク
      context['error_severity'] = 'critical';
      context['requires_immediate_attention'] = true;

      recordError(apiType, errorMessage, context);

      // 追加のカスタムキー
      FirebaseCrashlytics.instance.setCustomKey('error_severity', 'critical');

      _debugPrint('🚨 Critical Error記録: $apiType - $errorMessage');
    } catch (e) {
      _debugPrint('❌ Critical Error記録失敗: $e');
    }
  }

  /// API成功時のメトリクス記録
  static void recordSuccess(
      String apiType, Duration duration, Map<String, dynamic> context) {
    try {
      FirebaseCrashlytics.instance.setCustomKey(
          '${apiType}_last_success', DateTime.now().millisecondsSinceEpoch);
      FirebaseCrashlytics.instance
          .setCustomKey('${apiType}_duration_ms', duration.inMilliseconds);

      _debugPrint('📊 API成功記録: $apiType (${duration.inMilliseconds}ms)');
    } catch (e) {
      _debugPrint('❌ 成功メトリクス記録失敗: $e');
    }
  }

  /// === ユーザーフレンドリーなエラーメッセージ ===

  /// 機能別のユーザー向けメッセージ生成
  static String getFeatureFriendlyMessage(String apiType, String baseMessage) {
    Map<String, String> featureNames = {
      // Cloud Run API
      CLOUD_RUN_CAMERA_ANALYSIS: '写真分析',
      CLOUD_RUN_AREA_ANALYSIS: 'エリア分析',
      CLOUD_RUN_ANALYSIS_HISTORY: '分析履歴',

      // Legacy API
      GEMINI_VISION: 'AI画像分析',
      GEMINI_TEXT: 'AI分析',

      // Firebase API
      FIREBASE_AUTH: 'ログイン',
      FIRESTORE_READ: 'データ読み込み',
      FIRESTORE_WRITE: 'データ保存',
      FIREBASE_STORAGE: '画像保存',

      // Google Maps API
      GOOGLE_MAPS_GEOCODING: '住所検索',
      GOOGLE_PLACES: '施設検索',
    };

    String featureName = featureNames[apiType] ?? 'サービス';
    return '$featureNameで$baseMessage';
  }

  /// === 再試行可能性の判定 ===

  /// エラーが再試行可能かどうかを判定
  static bool isRetryable(
      String apiType, int? statusCode, String? errorMessage) {
    // 再試行不可能なエラー
    if (statusCode != null) {
      switch (statusCode) {
        case 400: // Bad Request
        case 401: // Unauthorized
        case 403: // Forbidden
        case 404: // Not Found
          return false;
        case 429: // Too Many Requests
        case 500: // Internal Server Error
        case 502: // Bad Gateway
        case 503: // Service Unavailable
        case 504: // Gateway Timeout
          return true;
      }
    }

    // エラーメッセージによる判定
    if (errorMessage != null) {
      String lowerError = errorMessage.toLowerCase();
      if (lowerError.contains('timeout') ||
          lowerError.contains('network') ||
          lowerError.contains('connection')) {
        return true;
      }
      if (lowerError.contains('invalid') || lowerError.contains('forbidden')) {
        return false;
      }
    }

    // API種別による判定
    switch (apiType) {
      case CLOUD_RUN_CAMERA_ANALYSIS:
      case CLOUD_RUN_AREA_ANALYSIS:
      case CLOUD_RUN_ANALYSIS_HISTORY:
        return statusCode == null || statusCode >= 500 || statusCode == 429;
      case FIREBASE_AUTH:
        return false; // 認証エラーは基本的に再試行不可
      default:
        return statusCode == null || statusCode >= 500;
    }
  }

  /// === デバッグ・開発支援 ===

  /// 開発環境での詳細エラー情報生成
  static Map<String, dynamic> generateDebugInfo(String apiType, dynamic error) {
    return {
      'api_type': apiType,
      'feature_category': _getFeatureCategory(apiType),
      'error_message': error.toString(),
      'error_type': error.runtimeType.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'app_version': 'v1.0',
      'error_hash': error.hashCode,
      'stack_trace_available': StackTrace.current.toString().isNotEmpty,
    };
  }

  /// 機能カテゴリの取得
  static String _getFeatureCategory(String apiType) {
    if (apiType.startsWith('cloud_run_')) return 'cloud_run_api';
    if (apiType.startsWith('firebase_')) return 'firebase_api';
    if (apiType.startsWith('google_')) return 'google_api';
    if (apiType.contains('gemini')) return 'ai_api';
    return 'other';
  }

  /// エラー頻度の監視
  static void trackErrorFrequency(String apiType) {
    try {
      int currentCount = _getErrorCount(apiType) + 1;
      _errorCounts[apiType] = currentCount;

      FirebaseCrashlytics.instance
          .setCustomKey('${apiType}_error_count', currentCount);

      // 閾値チェック（エラーが多すぎる場合）
      if (currentCount >= 5) {
        recordCriticalError(apiType, 'High error frequency detected', {
          'error_count': currentCount,
          'threshold_exceeded': true,
        });
      }
    } catch (e) {
      _debugPrint('❌ エラー頻度追跡失敗: $e');
    }
  }

  /// エラーカウント管理（メモリ内）
  static final Map<String, int> _errorCounts = {};

  static int _getErrorCount(String apiType) {
    return _errorCounts[apiType] ?? 0;
  }

  /// デバッグ印刷（開発環境のみ）
  static void _debugPrint(String message) {
    assert(() {
      print('[Maisoku AI v1.0 ErrorHandler] $message');
      return true;
    }());
  }

  /// === ユーティリティメソッド ===

  /// エラーサマリーの生成（ダッシュボード用）
  static Map<String, dynamic> generateErrorSummary() {
    return {
      'error_counts': Map.from(_errorCounts),
      'total_errors': _errorCounts.values.fold(0, (sum, count) => sum + count),
      'timestamp': DateTime.now().toIso8601String(),
      'app_version': 'v1.0',
    };
  }

  /// エラーカウントのリセット
  static void resetErrorCounts() {
    _errorCounts.clear();
    _debugPrint('🔄 エラーカウントをリセットしました');
  }
}
