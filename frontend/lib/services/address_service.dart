// lib/services/address_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/address_model.dart';
import '../config/api_config.dart';
import '../utils/address_validator.dart';
import 'api_service.dart';

/// Maisoku AI v1.0: 住所サービス
///
/// 機能分離対応：
/// - GPS位置取得：Flutter側（実機から）
/// - 住所候補・正規化：ApiService経由（Google Maps API統合）
/// - エリア分析：ApiService経由
class AddressService {
  // === GPS位置取得（Flutter側実装） ===

  /// GPS位置を取得
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ 位置情報サービスが無効です');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ 位置情報の許可が拒否されました');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ 位置情報の許可が永続的に拒否されています');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('✅ GPS位置取得成功: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ GPS位置取得エラー: $e');
      return null;
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

  /// 住所候補を取得（ApiService経由）
  Future<List<AddressSuggestion>> getAddressSuggestions(String input) async {
    if (input.length < 2) return [];

    try {
      print('🔍 住所候補取得開始: $input');

      final suggestions = await ApiService.getAddressSuggestions(
        input: input,
        types: 'address',
        country: 'jp',
      );

      final result = suggestions.take(5).map((suggestion) {
        return AddressSuggestion(
          description: suggestion['description'] as String,
          placeId: suggestion['place_id'] as String? ?? '',
        );
      }).toList();

      print('✅ 住所候補取得完了: ${result.length}件');
      return result;
    } catch (e) {
      print('❌ 住所候補取得エラー: $e');
      // フォールバック：基本実装を使用
      return _generateBasicSuggestions(input);
    }
  }

  /// GPS座標から住所を取得（ApiService経由）
  Future<AddressModel?> getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      print('🗺️ GPS→住所変換開始: ($latitude, $longitude)');

      final result = await ApiService.getAddressFromCoordinates(
        latitude: latitude,
        longitude: longitude,
      );

      if (result != null) {
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
        print('⚠️ GPS→住所変換結果なし');
        // フォールバック：基本実装を使用
        return _createFallbackAddressModel(latitude, longitude);
      }
    } catch (e) {
      print('❌ GPS→住所変換エラー: $e');
      // フォールバック：基本実装を使用
      return _createFallbackAddressModel(latitude, longitude);
    }
  }

  /// 住所を正規化（ApiService + 基本処理）
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
        print('⚠️ 住所候補が見つかりませんでした');
        return null;
      }
    } catch (e) {
      print('❌ 住所正規化エラー: $e');
      return null;
    }
  }

  // === プライベートヘルパーメソッド ===

  /// フォールバック用の AddressModel 作成
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

  /// 基本的な住所候補生成（デモ用）
  List<AddressSuggestion> _generateBasicSuggestions(String input) {
    final suggestions = <AddressSuggestion>[];
    final normalizedInput = input.toLowerCase();

    // よく使われる住所パターンを生成
    if (normalizedInput.contains('渋谷')) {
      suggestions.addAll([
        AddressSuggestion(description: '東京都渋谷区渋谷', placeId: 'demo_shibuya_1'),
        AddressSuggestion(description: '渋谷駅', placeId: 'demo_shibuya_station'),
        AddressSuggestion(description: '東京都渋谷区道玄坂', placeId: 'demo_dogenzaka'),
      ]);
    } else if (normalizedInput.contains('新宿')) {
      suggestions.addAll([
        AddressSuggestion(description: '東京都新宿区新宿', placeId: 'demo_shinjuku_1'),
        AddressSuggestion(description: '新宿駅', placeId: 'demo_shinjuku_station'),
        AddressSuggestion(description: '東京都新宿区歌舞伎町', placeId: 'demo_kabukicho'),
      ]);
    } else if (normalizedInput.contains('東京')) {
      suggestions.addAll([
        AddressSuggestion(description: '東京都', placeId: 'demo_tokyo_1'),
        AddressSuggestion(description: '東京駅', placeId: 'demo_tokyo_station'),
        AddressSuggestion(description: '東京都千代田区', placeId: 'demo_chiyoda'),
      ]);
    } else {
      // 汎用的な候補
      suggestions.add(
        AddressSuggestion(description: '$input（住所候補）', placeId: 'demo_generic'),
      );
    }

    return suggestions.take(5).toList();
  }

  /// GPS座標から住所を推定（簡易実装）
  String _estimateAddressFromCoordinates(double latitude, double longitude) {
    // 大まかな地域判定
    if (latitude >= 35.5 &&
        latitude <= 35.8 &&
        longitude >= 139.5 &&
        longitude <= 139.9) {
      return '東京都内';
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

  /// 座標の簡易推定
  Map<String, double> _estimateCoordinates(String address, AddressType type) {
    // デフォルト座標（東京都庁）
    double lat = 35.6762;
    double lng = 139.6503;

    // 簡易的な都道府県判定
    if (address.contains('大阪')) {
      lat = 34.6937;
      lng = 135.5023;
    } else if (address.contains('名古屋')) {
      lat = 35.1815;
      lng = 136.9066;
    } else if (address.contains('福岡')) {
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
    } else if (address.contains('渋谷')) {
      lat = 35.6580;
      lng = 139.7016;
    } else if (address.contains('新宿')) {
      lat = 35.6896;
      lng = 139.6917;
    } else if (address.contains('池袋')) {
      lat = 35.7295;
      lng = 139.7109;
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
      final suggestions = await ApiService.getAddressSuggestions(input: '東京');
      results['api_service_connection'] = suggestions.isNotEmpty;
    } catch (e) {
      results['api_service_connection'] = false;
    }

    return results;
  }

  /// デバッグ情報を表示
  void printDebugInfo() {
    print('''
🔍 AddressService Debug Info (v1.0):
  GPS Provider: Flutter Geolocator
  Address API: ApiService + Google Maps
  Supported Functions:
    - GPS位置取得 ✅
    - 住所候補取得 ✅ (ApiService経由)
    - GPS→住所変換 ✅ (ApiService経由) 
    - 基本住所正規化 ✅
    - フォールバック機能 ✅
  Version: 1.0
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
