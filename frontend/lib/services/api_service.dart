import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

class ApiService {
  // 認証ヘッダーを取得
  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Maisoku-Flutter-App/1.0',
    };

    // IDトークンを取得して Authorization ヘッダーに追加
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final idToken = await user.getIdToken();
        headers['Authorization'] = 'Bearer $idToken';
        print('✅ IDトークン取得成功');
      } catch (e) {
        print('⚠️ IDトークン取得エラー: $e');
      }
    } else {
      print('ℹ️ ユーザー未ログイン - 認証ヘッダーなし');
    }

    return headers;
  }

  // ヘルスチェック（認証不要）
  static Future<Map<String, dynamic>?> healthCheck() async {
    try {
      print('🔍 API接続テスト開始: ${ApiConfig.healthEndpoint}');

      final response = await http.get(
        Uri.parse(ApiConfig.healthEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Maisoku-Flutter-App/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      print('📡 ヘルスチェック レスポンス: ${response.statusCode}');
      print('📄 ボディ: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ ヘルスチェック エラー: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🚨 ヘルスチェック 接続エラー: $e');
      return null;
    }
  }

  // Hello World API（認証不要）
  static Future<String?> getHelloWorld() async {
    try {
      print('🔍 Hello World API呼び出し: ${ApiConfig.helloEndpoint}');

      final response = await http.get(
        Uri.parse(ApiConfig.helloEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Maisoku-Flutter-App/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      print('📡 Hello World レスポンス: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'];
      } else {
        print('❌ Hello World エラー: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🚨 Hello World API エラー: $e');
      return null;
    }
  }

  // 🔐 認証必須API（カメラ分析想定）
  static Future<Map<String, dynamic>?> testAuthRequired() async {
    try {
      print('🔐 認証必須API呼び出し開始...');

      final headers = await _getAuthHeaders();

      // Authorization ヘッダーがない場合はエラー
      if (!headers.containsKey('Authorization')) {
        throw Exception('認証が必要です。ログインしてください。');
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.authRequiredEndpoint),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      print('📡 認証必須API レスポンス: ${response.statusCode}');
      print('📄 レスポンス内容: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('認証エラー。再ログインしてください。');
      } else {
        print('❌ 認証必須API エラー: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🚨 認証必須API エラー: $e');
      rethrow;
    }
  }

  // 🔓 段階的認証API（エリア分析想定）
  static Future<Map<String, dynamic>?> testOptionalAuth() async {
    try {
      print('🔓 段階的認証API呼び出し開始...');

      final headers = await _getAuthHeaders();

      final response = await http
          .post(
            Uri.parse(ApiConfig.optionalAuthEndpoint),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      print('📡 段階的認証API レスポンス: ${response.statusCode}');
      print('📄 レスポンス内容: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final isPersonalized = result['is_personalized'] ?? false;

        print(isPersonalized ? '✅ 個人化エリア分析完了' : '✅ 基本エリア分析完了');

        return result;
      } else {
        print('❌ 段階的認証API エラー: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🚨 段階的認証API エラー: $e');
      return null;
    }
  }

  // 接続性テスト（ネットワーク確認）
  static Future<bool> testConnectivity() async {
    try {
      print('🌐 ネットワーク接続テスト開始');

      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'User-Agent': 'Maisoku-Flutter-App/1.0'},
      ).timeout(const Duration(seconds: 10));

      bool isConnected = response.statusCode == 200;
      print('🌐 ネットワーク接続: ${isConnected ? "成功" : "失敗"}');
      return isConnected;
    } catch (e) {
      print('🚨 ネットワーク接続エラー: $e');
      return false;
    }
  }
}
