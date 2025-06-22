import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  // ヘルスチェック
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

      print('📡 レスポンス: ${response.statusCode}');
      print('📄 ボディ: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ エラー: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🚨 API接続エラー: $e');
      return null;
    }
  }

  // Hello World API
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
