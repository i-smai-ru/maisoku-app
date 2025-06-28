// lib/services/address_service.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/address_model.dart';
import '../config/api_config.dart';
import '../utils/address_validator.dart';
import 'api_service.dart';

/// Maisoku AI v1.0: 住所サービス
class AddressService {
  // === GPS位置取得（Flutter側実装） ===

  /// GPS位置を取得（エラーハンドリング強化版）
  Future<Position?> getCurrentLocation() async {
    try {
      print('📍 GPS位置取得開始...');

      // 位置情報サービスの確認
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ 位置情報サービスが無効です');
        throw LocationServiceDisabledException('位置情報サービスが無効です。設定から有効にしてください。');
      }

      // 権限チェック・要求
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('🔐 位置情報権限を要求中...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ 位置情報の許可が拒否されました');
          throw LocationPermissionDeniedException('位置情報の許可が必要です。設定から許可してください。');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ 位置情報の許可が永続的に拒否されています');
        throw LocationPermissionDeniedForeverException(
            '位置情報の許可が永続的に拒否されています。設定から手動で許可してください。');
      }

      // GPS位置取得（タイムアウト設定）
      print('🛰️ GPS位置取得中...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30), // タイムアウト設定
      );

      print('✅ GPS位置取得成功: ${position.latitude}, ${position.longitude}');
      print('   精度: ${position.accuracy}m, 取得時刻: ${position.timestamp}');

      return position;
    } on LocationServiceDisabledException catch (e) {
      print('❌ LocationServiceDisabledException: $e');
      rethrow;
    } on LocationPermissionDeniedException catch (e) {
      print('❌ LocationPermissionDeniedException: $e');
      rethrow;
    } on LocationPermissionDeniedForeverException catch (e) {
      print('❌ LocationPermissionDeniedForeverException: $e');
      rethrow;
    } on TimeoutException catch (e) {
      print('❌ GPS取得タイムアウト: $e');
      throw GPSTimeoutException('GPS取得がタイムアウトしました。しばらく待ってから再度お試しください。');
    } catch (e) {
      print('❌ GPS位置取得エラー: $e');
      if (e.toString().contains('timeout')) {
        throw GPSTimeoutException('GPS取得がタイムアウトしました。');
      } else if (e.toString().contains('permission')) {
        throw LocationPermissionDeniedException('位置情報の許可が必要です。');
      } else {
        throw GPSException('GPS取得に失敗しました: ${e.toString()}');
      }
    }
  }

  /// 位置情報の権限状況を確認
  Future<LocationPermissionStatus> checkLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      final permission = await Geolocator.checkPermission();
      switch (permission) {
        case LocationPermission.denied:
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return LocationPermissionStatus.deniedForever;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return LocationPermissionStatus.granted;
        default:
          return LocationPermissionStatus.denied;
      }
    } catch (e) {
      print('❌ 位置情報権限チェックエラー: $e');
      return LocationPermissionStatus.error;
    }
  }

  // === ApiService経由での住所処理 ===

  /// 住所候補を取得（ApiService経由・エラーハンドリング強化）
  Future<List<AddressSuggestion>> getAddressSuggestions(String input) async {
    if (input.length < 2) return [];

    try {
      print('🔍 住所候補取得開始: $input');

      final result = await ApiService.getAddressSuggestions(
        input: input,
        types: 'address',
        country: 'jp',
      );

      if (result != null && result.containsKey('predictions')) {
        final predictions = result['predictions'] as List<dynamic>;

        final suggestions = predictions.take(5).map((suggestion) {
          return AddressSuggestion(
            description: suggestion['description'] as String? ?? '',
            placeId: suggestion['place_id'] as String? ?? '',
          );
        }).toList();

        print('✅ 住所候補取得完了: ${suggestions.length}件');
        return suggestions;
      } else {
        print('⚠️ 住所候補の形式が不正です');
        // フォールバックは呼び出し元で判断（API失敗時は入力継続可能）
        return [];
      }
    } catch (e) {
      print('❌ 住所候補取得エラー: $e');
      // フォールバック処理を削除：API失敗時は空リストを返し、入力継続を可能にする
      return [];
    }
  }

  /// GPS座標から住所を取得（ApiService経由・フォールバック強化）
  Future<AddressModel?> getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      print('🗺️ GPS→住所変換開始: ($latitude, $longitude)');

      // API呼び出し
      final result = await ApiService.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );

      if (result != null && result.containsKey('formatted_address')) {
        final addressModel = AddressModel(
          originalInput: 'GPS位置',
          normalizedAddress: result['formatted_address'] as String,
          latitude: latitude,
          longitude: longitude,
          precisionLevel: 'exact',
          confidence: result['confidence'] as double? ?? 1.0,
          analysisRadius: 300, // GPS取得なので狭い範囲
          timestamp: DateTime.now(),
        );

        print('✅ GPS→住所変換成功: ${addressModel.normalizedAddress}');
        return addressModel;
      } else {
        print('⚠️ GPS→住所変換結果なし、フォールバック実行');
        return _createFallbackAddressModel(latitude, longitude);
      }
    } catch (e) {
      print('❌ GPS→住所変換エラー: $e、フォールバック実行');
      return _createFallbackAddressModel(latitude, longitude);
    }
  }

  /// 住所を正規化（ApiService + 基本処理・フォールバック強化）
  Future<AddressModel?> normalizeAddress(String input) async {
    try {
      print('📝 住所正規化開始: $input');

      // 入力タイプを判別
      final AddressType addressType = AddressValidator.detectAddressType(input);
      print('🔍 検出された入力タイプ: ${addressType.name}');

      // 基本的な正規化処理
      String normalizedInput = _basicNormalization(input);

      // まずApiServiceで住所候補を取得
      final suggestions = await getAddressSuggestions(normalizedInput);

      if (suggestions.isNotEmpty) {
        final bestSuggestion = suggestions.first;

        // 座標推定（将来的にはPlace IDから正確な座標を取得）
        final coordinates =
            _estimateCoordinates(bestSuggestion.description, addressType);

        final addressModel = AddressModel(
          originalInput: input,
          normalizedAddress: bestSuggestion.description,
          latitude: coordinates['lat']!,
          longitude: coordinates['lng']!,
          precisionLevel:
              _determinePrecisionLevel(addressType, normalizedInput),
          confidence: _calculateConfidence(input, bestSuggestion.description),
          analysisRadius: _determineAnalysisRadius(addressType),
          timestamp: DateTime.now(),
        );

        print('✅ 住所正規化成功: ${addressModel.normalizedAddress}');
        return addressModel;
      } else {
        print('⚠️ 住所候補が見つかりませんでした、フォールバック実行');
        return _createFallbackAddressModelFromInput(input, addressType);
      }
    } catch (e) {
      print('❌ 住所正規化エラー: $e、フォールバック実行');
      final addressType = AddressValidator.detectAddressType(input);
      return _createFallbackAddressModelFromInput(input, addressType);
    }
  }

  // === プライベートヘルパーメソッド ===

  /// フォールバック用の AddressModel 作成（GPS座標から）
  AddressModel _createFallbackAddressModel(double latitude, double longitude) {
    final estimatedAddress =
        _estimateAddressFromCoordinates(latitude, longitude);

    return AddressModel(
      originalInput: 'GPS位置',
      normalizedAddress: estimatedAddress,
      latitude: latitude,
      longitude: longitude,
      precisionLevel: 'approximate',
      confidence: 0.7,
      analysisRadius: 500,
      timestamp: DateTime.now(),
    );
  }

  /// フォールバック用の AddressModel 作成（手動入力から）
  AddressModel? _createFallbackAddressModelFromInput(
      String input, AddressType addressType) {
    // 基本的な日本の住所であることを確認
    if (!_isLikelyJapaneseAddress(input)) {
      print('⚠️ 日本の住所ではない可能性があります: $input');
      return null;
    }

    // 座標推定
    final coordinates = _estimateCoordinates(input, addressType);

    // 信頼度計算
    final confidence = _calculateFallbackConfidence(input, addressType);

    if (confidence < 0.3) {
      print('⚠️ 信頼度が低すぎます: $confidence');
      return null;
    }

    return AddressModel(
      originalInput: input,
      normalizedAddress: _basicNormalization(input),
      latitude: coordinates['lat']!,
      longitude: coordinates['lng']!,
      precisionLevel: _determinePrecisionLevel(addressType, input),
      confidence: confidence,
      analysisRadius: _determineAnalysisRadius(addressType),
      timestamp: DateTime.now(),
    );
  }

  /// 日本の住所らしさを判定
  bool _isLikelyJapaneseAddress(String input) {
    final japaneseKeywords = [
      '都',
      '道',
      '府',
      '県',
      '市',
      '区',
      '町',
      '村',
      '駅',
      '丁目',
      '番地',
      '番',
      '号',
      '東京',
      '大阪',
      '名古屋',
      '横浜',
      '神戸',
      '京都',
      '福岡',
      '札幌',
      '仙台',
    ];

    final hasJapaneseKeyword =
        japaneseKeywords.any((keyword) => input.contains(keyword));
    final hasHiraganaKatakana =
        RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(input);
    final hasKanji = RegExp(r'[\u4E00-\u9FAF]').hasMatch(input);

    return hasJapaneseKeyword || hasHiraganaKatakana || hasKanji;
  }

  /// フォールバック時の信頼度計算
  double _calculateFallbackConfidence(String input, AddressType addressType) {
    double confidence = 0.3; // ベース信頼度

    // 入力タイプによる調整
    switch (addressType) {
      case AddressType.station:
        if (input.contains('駅')) confidence += 0.3;
        if (input.contains('JR') || input.contains('線')) confidence += 0.1;
        break;
      case AddressType.exact:
        if (input.contains('丁目') || input.contains('番地')) confidence += 0.2;
        if (RegExp(r'\d').hasMatch(input)) confidence += 0.1;
        break;
      case AddressType.district:
        if (input.contains('市') || input.contains('区')) confidence += 0.2;
        if (input.contains('都') || input.contains('県')) confidence += 0.1;
        break;
      case AddressType.landmark:
        confidence += 0.1;
        break;
      case AddressType.unclear:
        confidence = 0.2;
        break;
    }

    // 長さによる調整
    if (input.length >= 5 && input.length <= 30) {
      confidence += 0.1;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// GPS座標から住所を推定（簡易実装）
  String _estimateAddressFromCoordinates(double latitude, double longitude) {
    // 大まかな地域判定（改良版）
    if (latitude >= 35.5 &&
        latitude <= 35.8 &&
        longitude >= 139.5 &&
        longitude <= 139.9) {
      // 東京都内の細分化
      if (latitude >= 35.65 &&
          latitude <= 35.70 &&
          longitude >= 139.68 &&
          longitude <= 139.72) {
        return '東京都渋谷区周辺';
      } else if (latitude >= 35.68 &&
          latitude <= 35.71 &&
          longitude >= 139.69 &&
          longitude <= 139.73) {
        return '東京都新宿区周辺';
      } else {
        return '東京都内';
      }
    } else if (latitude >= 34.5 &&
        latitude <= 34.8 &&
        longitude >= 135.3 &&
        longitude <= 135.7) {
      return '大阪府内';
    } else if (latitude >= 35.0 &&
        latitude <= 35.3 &&
        longitude >= 136.7 &&
        longitude <= 137.0) {
      return '愛知県内';
    } else if (latitude >= 33.5 &&
        latitude <= 33.7 &&
        longitude >= 130.3 &&
        longitude <= 130.5) {
      return '福岡県内';
    } else if (latitude >= 43.0 &&
        latitude <= 43.1 &&
        longitude >= 141.3 &&
        longitude <= 141.4) {
      return '北海道札幌市周辺';
    } else {
      return '日本国内（緯度: ${latitude.toStringAsFixed(4)}, 経度: ${longitude.toStringAsFixed(4)}）';
    }
  }

  /// 基本的な住所正規化処理
  String _basicNormalization(String input) {
    String result = input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // 複数の空白を1つに
        .replaceAll('　', ' '); // 全角空白を半角に

    // 全角数字を半角に変換
    const fullWidthDigits = '０１２３４５６７８９';
    const halfWidthDigits = '0123456789';

    for (int i = 0; i < fullWidthDigits.length; i++) {
      result = result.replaceAll(fullWidthDigits[i], halfWidthDigits[i]);
    }

    return result;
  }

  /// 座標の簡易推定（改良版）
  Map<String, double> _estimateCoordinates(String address, AddressType type) {
    // デフォルト座標（東京都庁）
    double lat = 35.6762;
    double lng = 139.6503;

    // より詳細な地域判定
    final addressLower = address.toLowerCase();

    // 東京都内の詳細判定
    if (address.contains('渋谷')) {
      lat = 35.6580;
      lng = 139.7016;
    } else if (address.contains('新宿')) {
      lat = 35.6896;
      lng = 139.6917;
    } else if (address.contains('池袋')) {
      lat = 35.7295;
      lng = 139.7109;
    } else if (address.contains('品川')) {
      lat = 35.6284;
      lng = 139.7387;
    } else if (address.contains('上野')) {
      lat = 35.7141;
      lng = 139.7774;
    } else if (address.contains('銀座')) {
      lat = 35.6717;
      lng = 139.7648;
    } else if (address.contains('六本木')) {
      lat = 35.6654;
      lng = 139.7314;
    } else if (address.contains('秋葉原')) {
      lat = 35.7022;
      lng = 139.7744;
    }
    // 他の主要都市
    else if (address.contains('大阪') || address.contains('梅田')) {
      lat = 34.6937;
      lng = 135.5023;
    } else if (address.contains('名古屋')) {
      lat = 35.1815;
      lng = 136.9066;
    } else if (address.contains('福岡') || address.contains('天神')) {
      lat = 33.5904;
      lng = 130.4017;
    } else if (address.contains('札幌')) {
      lat = 43.0642;
      lng = 141.3469;
    } else if (address.contains('仙台')) {
      lat = 38.2682;
      lng = 140.8694;
    } else if (address.contains('広島')) {
      lat = 34.3853;
      lng = 132.4553;
    } else if (address.contains('京都')) {
      lat = 35.0116;
      lng = 135.7681;
    } else if (address.contains('神戸')) {
      lat = 34.6901;
      lng = 135.1956;
    } else if (address.contains('横浜')) {
      lat = 35.4437;
      lng = 139.6380;
    }

    return {'lat': lat, 'lng': lng};
  }

  /// 精度レベルを決定
  String _determinePrecisionLevel(AddressType type, String input) {
    switch (type) {
      case AddressType.exact:
        return 'exact';
      case AddressType.district:
        return 'district';
      case AddressType.station:
        return 'approximate';
      case AddressType.landmark:
        return 'approximate';
      default:
        return 'district';
    }
  }

  /// 信頼度を計算
  double _calculateConfidence(String original, String normalized) {
    if (original.toLowerCase() == normalized.toLowerCase()) {
      return 1.0;
    }

    // 簡易的な類似度計算
    final originalWords = original.split(' ');
    final normalizedWords = normalized.split(' ');

    int matchCount = 0;
    for (final word in originalWords) {
      if (normalizedWords.any((nWord) => nWord.contains(word))) {
        matchCount++;
      }
    }

    return originalWords.isNotEmpty ? matchCount / originalWords.length : 0.5;
  }

  /// 分析範囲を決定
  int _determineAnalysisRadius(AddressType type) {
    switch (type) {
      case AddressType.exact:
        return 300;
      case AddressType.district:
        return 500;
      case AddressType.station:
        return 800;
      case AddressType.landmark:
        return 600;
      default:
        return 500;
    }
  }

  // === デバッグ・開発用機能 ===

  /// サービス状態をテスト
  Future<Map<String, bool>> testServiceHealth() async {
    final results = <String, bool>{};

    // GPS機能テスト
    try {
      final permission = await checkLocationPermission();
      results['gps_permission'] =
          permission == LocationPermissionStatus.granted;
    } catch (e) {
      results['gps_permission'] = false;
    }

    // ApiService接続テスト
    try {
      final result = await ApiService.getAddressSuggestions(input: '東京');
      results['api_service_connection'] = result != null && result.isNotEmpty;
    } catch (e) {
      results['api_service_connection'] = false;
    }

    return results;
  }

  /// デバッグ情報を表示
  void printDebugInfo() {
    print('''
🔍 AddressService Debug Info (v1.0 強化版):
  GPS Provider: Flutter Geolocator + エラーハンドリング強化
  Address API: ApiService + Google Maps
  Supported Functions:
    - GPS位置取得 ✅ (タイムアウト・例外処理強化)
    - 住所候補取得 ✅ (ApiService経由・フォールバック削除)
    - GPS→住所変換 ✅ (ApiService経由・フォールバック強化)
    - 住所正規化 ✅ (フォールバック処理改善)
    - エラーハンドリング ✅ (カスタム例外・詳細メッセージ)
  Version: 1.0-enhanced
''');
  }
}

// === データクラス ===

/// 住所候補
class AddressSuggestion {
  final String description;
  final String placeId;

  AddressSuggestion({
    required this.description,
    required this.placeId,
  });

  @override
  String toString() =>
      'AddressSuggestion(description: $description, placeId: $placeId)';
}

/// 位置情報権限の状態
enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  error,
}

extension LocationPermissionStatusExtension on LocationPermissionStatus {
  String get message {
    switch (this) {
      case LocationPermissionStatus.granted:
        return '位置情報の利用が許可されています';
      case LocationPermissionStatus.denied:
        return '位置情報の許可が必要です';
      case LocationPermissionStatus.deniedForever:
        return '設定から位置情報を許可してください';
      case LocationPermissionStatus.serviceDisabled:
        return '位置情報サービスを有効にしてください';
      case LocationPermissionStatus.error:
        return '位置情報の確認でエラーが発生しました';
    }
  }

  bool get isUsable => this == LocationPermissionStatus.granted;
}

// === カスタム例外クラス ===

/// 位置情報サービス無効例外
class LocationServiceDisabledException implements Exception {
  final String message;
  LocationServiceDisabledException(this.message);
  @override
  String toString() => 'LocationServiceDisabledException: $message';
}

/// 位置情報権限拒否例外
class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException(this.message);
  @override
  String toString() => 'LocationPermissionDeniedException: $message';
}

/// 位置情報権限永続拒否例外
class LocationPermissionDeniedForeverException implements Exception {
  final String message;
  LocationPermissionDeniedForeverException(this.message);
  @override
  String toString() => 'LocationPermissionDeniedForeverException: $message';
}

/// GPS取得タイムアウト例外
class GPSTimeoutException implements Exception {
  final String message;
  GPSTimeoutException(this.message);
  @override
  String toString() => 'GPSTimeoutException: $message';
}

/// GPS一般例外
class GPSException implements Exception {
  final String message;
  GPSException(this.message);
  @override
  String toString() => 'GPSException: $message';
}
