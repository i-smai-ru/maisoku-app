// lib/models/area_analysis_model.dart

/// Maisoku AI v1.0: エリア分析結果モデル
///
/// エリア分析機能の分析結果データを管理
/// - 交通アクセス・施設密度の包括的データ
/// - Cloud Run API対応・段階的認証対応
/// - 揮発的表示（履歴保存なし）・再分析対応
class AreaAnalysisModel {
  /// 交通アクセス分析結果
  final TrafficAccessData? trafficAccess;

  /// 施設密度分析結果
  final FacilityDensityData? facilityDensity;

  /// 分析実行日時
  final DateTime timestamp;

  /// 分析処理時間（秒）
  final double? processingTimeSeconds;

  /// 段階的認証対応: 個人化分析フラグ
  final bool isPersonalized;

  /// エラーメッセージ（部分失敗時）
  final String? errorMessage;

  const AreaAnalysisModel({
    this.trafficAccess,
    this.facilityDensity,
    required this.timestamp,
    this.processingTimeSeconds,
    this.isPersonalized = false,
    this.errorMessage,
  });

  /// Cloud Run APIレスポンスからモデルを生成
  factory AreaAnalysisModel.fromApi(Map<String, dynamic> json) {
    return AreaAnalysisModel(
      trafficAccess: json['trafficAccess'] != null
          ? TrafficAccessData.fromApi(json['trafficAccess'])
          : null,
      facilityDensity: json['facilityDensity'] != null
          ? FacilityDensityData.fromApi(json['facilityDensity'])
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      processingTimeSeconds:
          (json['processingTimeSeconds'] as num?)?.toDouble(),
      isPersonalized: json['isPersonalized'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// API送信用JSON変換（再分析時用）
  Map<String, dynamic> toApiJson() {
    return {
      'trafficAccess': trafficAccess?.toJson(),
      'facilityDensity': facilityDensity?.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'isPersonalized': isPersonalized,
    };
  }

  /// 分析完了度チェック
  bool get isComplete {
    return trafficAccess != null && facilityDensity != null;
  }

  /// 完了した分析数
  int get completedCount {
    int count = 0;
    if (trafficAccess != null) count++;
    if (facilityDensity != null) count++;
    return count;
  }

  /// 総分析数（固定値）
  static const int totalAnalysisCount = 2;

  /// 分析成功率
  double get successRate {
    return completedCount / totalAnalysisCount;
  }

  /// 分析状況表示用文字列
  String get completionStatus {
    if (isComplete) return '完了';
    if (completedCount > 0) return '部分完了 ($completedCount/$totalAnalysisCount)';
    return '分析中';
  }

  /// 処理時間表示用文字列
  String get processingTimeDisplay {
    if (processingTimeSeconds == null) return '計測中';
    if (processingTimeSeconds! < 1.0) {
      return '${(processingTimeSeconds! * 1000).round()}ms';
    }
    return '${processingTimeSeconds!.toStringAsFixed(1)}秒';
  }

  /// 分析品質の評価
  String get qualityAssessment {
    if (!isComplete) return '分析中';

    final trafficQuality = trafficAccess?.qualityScore ?? 0.0;
    final facilityQuality = facilityDensity?.qualityScore ?? 0.0;
    final overallQuality = (trafficQuality + facilityQuality) / 2;

    if (overallQuality >= 0.8) return '高品質';
    if (overallQuality >= 0.6) return '標準';
    return '要改善';
  }

  /// エリア分析サマリー（一行）
  String get summaryText {
    if (!isComplete) return '分析実行中...';

    final stationCount = trafficAccess?.stations.length ?? 0;
    final facilityCount = facilityDensity?.totalFacilityCount ?? 0;

    return '駅${stationCount}件・施設${facilityCount}件を検出';
  }

  /// 不変オブジェクトのコピー作成
  AreaAnalysisModel copyWith({
    TrafficAccessData? trafficAccess,
    FacilityDensityData? facilityDensity,
    DateTime? timestamp,
    double? processingTimeSeconds,
    bool? isPersonalized,
    String? errorMessage,
  }) {
    return AreaAnalysisModel(
      trafficAccess: trafficAccess ?? this.trafficAccess,
      facilityDensity: facilityDensity ?? this.facilityDensity,
      timestamp: timestamp ?? this.timestamp,
      processingTimeSeconds:
          processingTimeSeconds ?? this.processingTimeSeconds,
      isPersonalized: isPersonalized ?? this.isPersonalized,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'AreaAnalysisModel('
        'traffic: ${trafficAccess != null}, '
        'facility: ${facilityDensity != null}, '
        'personalized: $isPersonalized, '
        'time: ${processingTimeDisplay}'
        ')';
  }
}

/// 交通アクセス分析データ
class TrafficAccessData {
  /// 最寄り駅リスト（距離順）
  final List<NearestStation> stations;

  /// 最寄りバス停リスト
  final List<BusStop> busStops;

  /// 高速道路アクセス
  final List<HighwayAccess> highways;

  /// API成功フラグ
  final bool isSuccess;

  /// エラーメッセージ
  final String? error;

  const TrafficAccessData({
    required this.stations,
    required this.busStops,
    required this.highways,
    this.isSuccess = true,
    this.error,
  });

  factory TrafficAccessData.fromApi(Map<String, dynamic> json) {
    return TrafficAccessData(
      stations: (json['stations'] as List<dynamic>?)
              ?.map((e) => NearestStation.fromApi(e))
              .toList() ??
          [],
      busStops: (json['busStops'] as List<dynamic>?)
              ?.map((e) => BusStop.fromApi(e))
              .toList() ??
          [],
      highways: (json['highways'] as List<dynamic>?)
              ?.map((e) => HighwayAccess.fromApi(e))
              .toList() ??
          [],
      isSuccess: json['isSuccess'] as bool? ?? true,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stations': stations.map((e) => e.toJson()).toList(),
      'busStops': busStops.map((e) => e.toJson()).toList(),
      'highways': highways.map((e) => e.toJson()).toList(),
      'isSuccess': isSuccess,
      'error': error,
    };
  }

  /// エラー状態で生成
  factory TrafficAccessData.error(String errorMessage) {
    return TrafficAccessData(
      stations: [],
      busStops: [],
      highways: [],
      isSuccess: false,
      error: errorMessage,
    );
  }

  /// 交通アクセス品質スコア（0.0-1.0）
  double get qualityScore {
    if (!isSuccess) return 0.0;

    double score = 0.0;

    // 駅アクセス評価（最大0.6）
    if (stations.isNotEmpty) {
      final bestStation = stations.first;
      if (bestStation.walkingMinutes <= 5)
        score += 0.6;
      else if (bestStation.walkingMinutes <= 10)
        score += 0.4;
      else if (bestStation.walkingMinutes <= 15) score += 0.2;
    }

    // バス停評価（最大0.2）
    if (busStops.isNotEmpty) {
      score += 0.2;
    }

    // 高速道路評価（最大0.2）
    if (highways.isNotEmpty) {
      score += 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  /// 交通評価サマリー
  String get summary {
    if (!isSuccess) return 'データ取得失敗';
    if (stations.isEmpty && busStops.isEmpty && highways.isEmpty) {
      return '交通情報なし';
    }

    String result = '';
    if (stations.isNotEmpty) {
      result += '駅${stations.length}件';
    }
    if (busStops.isNotEmpty) {
      if (result.isNotEmpty) result += '・';
      result += 'バス${busStops.length}件';
    }
    if (highways.isNotEmpty) {
      if (result.isNotEmpty) result += '・';
      result += '高速${highways.length}件';
    }

    return result;
  }
}

/// 最寄り駅情報
class NearestStation {
  /// 駅名
  final String name;

  /// 路線リスト
  final List<String> lines;

  /// 徒歩時間（分）
  final int walkingMinutes;

  /// 直線距離（メートル）
  final double distance;

  /// 主要駅フラグ
  final bool isMajorStation;

  const NearestStation({
    required this.name,
    required this.lines,
    required this.walkingMinutes,
    required this.distance,
    this.isMajorStation = false,
  });

  factory NearestStation.fromApi(Map<String, dynamic> json) {
    return NearestStation(
      name: json['name'] as String,
      lines: List<String>.from(json['lines'] as List? ?? []),
      walkingMinutes: json['walkingMinutes'] as int? ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      isMajorStation: json['isMajorStation'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lines': lines,
      'walkingMinutes': walkingMinutes,
      'distance': distance,
      'isMajorStation': isMajorStation,
    };
  }

  /// 路線表示用文字列
  String get linesDisplay {
    if (lines.isEmpty) return '路線情報取得中';
    if (lines.length == 1) return lines.first;
    if (lines.length <= 3) return lines.join('・');
    return '${lines.take(2).join('・')}他${lines.length - 2}路線';
  }

  /// アクセス評価
  String get accessRating {
    if (walkingMinutes <= 5) return '優秀';
    if (walkingMinutes <= 10) return '良好';
    if (walkingMinutes <= 15) return '普通';
    return '遠い';
  }

  /// 距離カテゴリ
  String get distanceCategory {
    if (walkingMinutes <= 5) return '近距離';
    if (walkingMinutes <= 10) return '中距離';
    if (walkingMinutes <= 15) return '中距離';
    return '遠距離';
  }

  /// 表示用距離文字列
  String get distanceDisplay {
    return '徒歩${walkingMinutes}分 (${(distance / 1000).toStringAsFixed(1)}km)';
  }
}

/// バス停情報
class BusStop {
  /// バス停名
  final String name;

  /// 運行路線リスト
  final List<String> routes;

  /// 徒歩時間（分）
  final int walkingMinutes;

  /// 直線距離（メートル）
  final double distance;

  const BusStop({
    required this.name,
    required this.routes,
    required this.walkingMinutes,
    required this.distance,
  });

  factory BusStop.fromApi(Map<String, dynamic> json) {
    return BusStop(
      name: json['name'] as String,
      routes: List<String>.from(json['routes'] as List? ?? []),
      walkingMinutes: json['walkingMinutes'] as int? ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'routes': routes,
      'walkingMinutes': walkingMinutes,
      'distance': distance,
    };
  }

  /// 路線表示用文字列
  String get routesDisplay {
    if (routes.isEmpty) return '路線情報取得中';
    if (routes.length <= 2) return routes.join('・');
    return '${routes.take(2).join('・')}他${routes.length - 2}路線';
  }

  /// 表示用距離文字列
  String get distanceDisplay {
    return '徒歩${walkingMinutes}分';
  }
}

/// 高速道路アクセス情報
class HighwayAccess {
  /// インターチェンジ名
  final String name;

  /// 距離（キロメートル）
  final double distanceKm;

  /// 車での所要時間（分）
  final int drivingMinutes;

  /// 高速道路名
  final String? highwayName;

  const HighwayAccess({
    required this.name,
    required this.distanceKm,
    required this.drivingMinutes,
    this.highwayName,
  });

  factory HighwayAccess.fromApi(Map<String, dynamic> json) {
    return HighwayAccess(
      name: json['name'] as String,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      drivingMinutes: json['drivingMinutes'] as int? ?? 0,
      highwayName: json['highwayName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'distanceKm': distanceKm,
      'drivingMinutes': drivingMinutes,
      'highwayName': highwayName,
    };
  }

  /// 距離カテゴリ
  String get distanceCategory {
    if (distanceKm <= 3) return '近距離';
    if (distanceKm <= 10) return '中距離';
    return '遠距離';
  }

  /// 表示用距離文字列
  String get distanceDisplay {
    return '${distanceKm.toStringAsFixed(1)}km (車${drivingMinutes}分)';
  }

  /// 表示用名称（高速道路名含む）
  String get displayName {
    if (highwayName != null && !name.contains(highwayName!)) {
      return '$name ($highwayName)';
    }
    return name;
  }
}

/// 施設密度分析データ
class FacilityDensityData {
  /// カテゴリ別施設数
  final Map<String, int> facilityCounts;

  /// カテゴリ別上位施設リスト
  final Map<String, List<FacilityInfo>> topFacilities;

  /// API成功フラグ
  final bool isSuccess;

  /// エラーメッセージ
  final String? error;

  const FacilityDensityData({
    required this.facilityCounts,
    required this.topFacilities,
    this.isSuccess = true,
    this.error,
  });

  factory FacilityDensityData.fromApi(Map<String, dynamic> json) {
    Map<String, List<FacilityInfo>> topFacilities = {};
    if (json['topFacilities'] != null) {
      (json['topFacilities'] as Map<String, dynamic>).forEach((key, value) {
        topFacilities[key] = (value as List<dynamic>?)
                ?.map((e) => FacilityInfo.fromApi(e))
                .toList() ??
            [];
      });
    }

    return FacilityDensityData(
      facilityCounts: Map<String, int>.from(json['facilityCounts'] ?? {}),
      topFacilities: topFacilities,
      isSuccess: json['isSuccess'] as bool? ?? true,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> topFacilitiesJson = {};
    topFacilities.forEach((key, value) {
      topFacilitiesJson[key] = value.map((e) => e.toJson()).toList();
    });

    return {
      'facilityCounts': facilityCounts,
      'topFacilities': topFacilitiesJson,
      'isSuccess': isSuccess,
      'error': error,
    };
  }

  /// エラー状態で生成
  factory FacilityDensityData.error(String errorMessage) {
    return FacilityDensityData(
      facilityCounts: {},
      topFacilities: {},
      isSuccess: false,
      error: errorMessage,
    );
  }

  /// 総施設数
  int get totalFacilityCount {
    return facilityCounts.values.fold(0, (sum, count) => sum + count);
  }

  /// 最も充実しているカテゴリ
  String? get topCategory {
    if (facilityCounts.isEmpty) return null;

    var sortedEntries = facilityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.first.key;
  }

  /// 施設密度品質スコア（0.0-1.0）
  double get qualityScore {
    if (!isSuccess) return 0.0;

    final total = totalFacilityCount;
    if (total >= 50) return 1.0;
    if (total >= 30) return 0.8;
    if (total >= 15) return 0.6;
    if (total >= 5) return 0.4;
    if (total > 0) return 0.2;
    return 0.0;
  }

  /// 施設密度サマリー
  String get summary {
    if (!isSuccess) return 'データ取得失敗';

    int total = totalFacilityCount;
    if (total == 0) return '周辺施設情報なし';

    String topCat = topCategory ?? '';
    if (topCat.isNotEmpty) {
      return '計${total}件 (${topCat}が最多)';
    }

    return '計${total}件の施設';
  }

  /// カテゴリ別充実度評価
  Map<String, String> get categoryRatings {
    Map<String, String> ratings = {};

    facilityCounts.forEach((category, count) {
      if (count >= 10) {
        ratings[category] = '充実';
      } else if (count >= 5) {
        ratings[category] = '普通';
      } else if (count > 0) {
        ratings[category] = '少ない';
      } else {
        ratings[category] = 'なし';
      }
    });

    return ratings;
  }
}

/// 施設情報
class FacilityInfo {
  /// 施設名
  final String name;

  /// 住所
  final String address;

  /// 評価（0.0-5.0）
  final double rating;

  /// レビュー数
  final int reviewCount;

  /// 距離（メートル）
  final double distance;

  /// 徒歩時間（分）
  final int walkingMinutes;

  /// 写真URL
  final String? photoUrl;

  /// 営業中フラグ
  final bool isOpen;

  /// 営業時間
  final String? businessHours;

  /// 電話番号
  final String? phoneNumber;

  const FacilityInfo({
    required this.name,
    required this.address,
    required this.rating,
    required this.reviewCount,
    required this.distance,
    required this.walkingMinutes,
    this.photoUrl,
    this.isOpen = true,
    this.businessHours,
    this.phoneNumber,
  });

  factory FacilityInfo.fromApi(Map<String, dynamic> json) {
    return FacilityInfo(
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      walkingMinutes: json['walkingMinutes'] as int? ?? 0,
      photoUrl: json['photoUrl'] as String?,
      isOpen: json['isOpen'] as bool? ?? true,
      businessHours: json['businessHours'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'rating': rating,
      'reviewCount': reviewCount,
      'distance': distance,
      'walkingMinutes': walkingMinutes,
      'photoUrl': photoUrl,
      'isOpen': isOpen,
      'businessHours': businessHours,
      'phoneNumber': phoneNumber,
    };
  }

  /// 評価表示用文字列
  String get ratingDisplay {
    if (rating <= 0) return '評価なし';
    return '★${rating.toStringAsFixed(1)} (${reviewCount}件)';
  }

  /// 距離表示用文字列
  String get distanceDisplay {
    if (walkingMinutes <= 0) return '距離計算中';
    return '徒歩${walkingMinutes}分';
  }

  /// 営業状況表示
  String get statusDisplay {
    return isOpen ? '営業中' : '営業時間外';
  }

  /// 短縮住所（表示用）
  String get shortAddress {
    if (address.length <= 20) return address;
    return '${address.substring(0, 17)}...';
  }
}
