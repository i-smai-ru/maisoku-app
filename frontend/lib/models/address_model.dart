// lib/models/address_model.dart

/// Maisoku AI v1.0: 住所・GPS情報モデル
///
/// エリア分析機能で使用する住所データを管理
/// - 住所正規化・GPS座標・分析精度の管理
/// - Google Maps API・Gemini AIレスポンス対応
/// - 段階的認証システム対応
class AddressModel {
  /// ユーザーが入力した元の住所文字列
  final String originalInput;

  /// AI正規化後の標準住所形式
  final String normalizedAddress;

  /// 緯度（-90.0 ～ 90.0）
  final double latitude;

  /// 経度（-180.0 ～ 180.0）
  final double longitude;

  /// 位置精度レベル
  /// - "exact": ピンポイント（建物レベル）
  /// - "district": 地区レベル（駅周辺等）
  /// - "approximate": 近似（曖昧な入力）
  final String precisionLevel;

  /// AI解析の信頼度（0.0 ～ 1.0）
  final double confidence;

  /// 分析対象範囲（メートル）
  /// 精度により自動調整: exact=300m, district=800m, approximate=1500m
  final int analysisRadius;

  /// 住所解析実行日時
  final DateTime timestamp;

  const AddressModel({
    required this.originalInput,
    required this.normalizedAddress,
    required this.latitude,
    required this.longitude,
    required this.precisionLevel,
    required this.confidence,
    required this.analysisRadius,
    required this.timestamp,
  });

  /// Cloud Run APIレスポンスからモデルを生成
  factory AddressModel.fromApi(Map<String, dynamic> json) {
    return AddressModel(
      originalInput: json['originalInput'] as String? ?? '',
      normalizedAddress: json['normalizedAddress'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      precisionLevel: json['precisionLevel'] as String? ?? 'approximate',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
      analysisRadius: json['analysisRadius'] as int? ?? 800,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Firestoreドキュメントからモデルを生成
  factory AddressModel.fromFirestore(Map<String, dynamic> data) {
    return AddressModel(
      originalInput: data['originalInput'] as String? ?? '',
      normalizedAddress: data['normalizedAddress'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      precisionLevel: data['precisionLevel'] as String? ?? 'approximate',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.7,
      analysisRadius: data['analysisRadius'] as int? ?? 800,
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// GPS座標から直接生成（現在地取得用）
  factory AddressModel.fromGPS({
    required double latitude,
    required double longitude,
    String? detectedAddress,
  }) {
    return AddressModel(
      originalInput: 'GPS取得',
      normalizedAddress: detectedAddress ?? '位置情報から取得',
      latitude: latitude,
      longitude: longitude,
      precisionLevel: 'exact',
      confidence: 1.0,
      analysisRadius: 300, // GPS取得は高精度なので狭い範囲
      timestamp: DateTime.now(),
    );
  }

  /// API送信用JSON変換
  Map<String, dynamic> toApiJson() {
    return {
      'originalInput': originalInput,
      'normalizedAddress': normalizedAddress,
      'latitude': latitude,
      'longitude': longitude,
      'precisionLevel': precisionLevel,
      'confidence': confidence,
      'analysisRadius': analysisRadius,
    };
  }

  /// Firestore保存用JSON変換
  Map<String, dynamic> toFirestoreJson() {
    return {
      'originalInput': originalInput,
      'normalizedAddress': normalizedAddress,
      'latitude': latitude,
      'longitude': longitude,
      'precisionLevel': precisionLevel,
      'confidence': confidence,
      'analysisRadius': analysisRadius,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// エリア分析画面表示用の短縮住所
  String get displayAddress {
    if (normalizedAddress.length <= 30) {
      return normalizedAddress;
    }
    return '${normalizedAddress.substring(0, 27)}...';
  }

  /// 位置精度の日本語表示
  String get precisionDisplay {
    switch (precisionLevel) {
      case 'exact':
        return '高精度';
      case 'district':
        return '地区レベル';
      case 'approximate':
        return '近似';
      default:
        return '不明';
    }
  }

  /// 信頼度の日本語表示
  String get confidenceDisplay {
    if (confidence >= 0.9) return '非常に高い';
    if (confidence >= 0.7) return '高い';
    if (confidence >= 0.5) return '普通';
    return '低い';
  }

  /// 分析範囲の説明文
  String get analysisRadiusDisplay {
    if (analysisRadius <= 300) return '徒歩3-4分圏内';
    if (analysisRadius <= 800) return '徒歩8-10分圏内';
    return '徒歩15分圏内';
  }

  /// GPS座標が有効かチェック
  bool get hasValidCoordinates {
    return latitude.abs() <= 90.0 &&
        longitude.abs() <= 180.0 &&
        latitude != 0.0 &&
        longitude != 0.0;
  }

  /// 高精度な位置情報かチェック
  bool get isHighPrecision {
    return precisionLevel == 'exact' && confidence >= 0.8;
  }

  /// エリア分析に適した精度かチェック
  bool get isSuitableForAnalysis {
    return hasValidCoordinates && confidence >= 0.5;
  }

  /// 不変オブジェクトのコピー作成
  AddressModel copyWith({
    String? originalInput,
    String? normalizedAddress,
    double? latitude,
    double? longitude,
    String? precisionLevel,
    double? confidence,
    int? analysisRadius,
    DateTime? timestamp,
  }) {
    return AddressModel(
      originalInput: originalInput ?? this.originalInput,
      normalizedAddress: normalizedAddress ?? this.normalizedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      precisionLevel: precisionLevel ?? this.precisionLevel,
      confidence: confidence ?? this.confidence,
      analysisRadius: analysisRadius ?? this.analysisRadius,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// オブジェクト比較
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddressModel &&
        other.normalizedAddress == normalizedAddress &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return Object.hash(normalizedAddress, latitude, longitude);
  }

  /// デバッグ用文字列表現
  @override
  String toString() {
    return 'AddressModel('
        'input: "$originalInput", '
        'normalized: "$normalizedAddress", '
        'lat: $latitude, lng: $longitude, '
        'precision: $precisionLevel, '
        'confidence: $confidence, '
        'radius: ${analysisRadius}m'
        ')';
  }
}

/// 住所入力タイプの列挙
enum AddressInputType {
  /// 手動入力
  manual,

  /// GPS取得
  gps,

  /// Google Places選択
  places,
}

/// 住所の有効性チェック結果
class AddressValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> suggestions;

  const AddressValidationResult({
    required this.isValid,
    this.errorMessage,
    this.suggestions = const [],
  });

  factory AddressValidationResult.valid() {
    return const AddressValidationResult(isValid: true);
  }

  factory AddressValidationResult.invalid(
    String errorMessage, {
    List<String> suggestions = const [],
  }) {
    return AddressValidationResult(
      isValid: false,
      errorMessage: errorMessage,
      suggestions: suggestions,
    );
  }
}
