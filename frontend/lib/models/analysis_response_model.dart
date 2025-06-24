// lib/models/analysis_response_model.dart

import '../config/api_config.dart';

/// Cloud Run APIからのレスポンスを統一的に扱うモデル
class AnalysisResponse {
  final String analysis;
  final double processingTime;
  final bool isPersonalized;
  final String timestamp;
  final Map<String, dynamic>? metadata;
  final String? analysisType;
  final String? version;

  AnalysisResponse({
    required this.analysis,
    required this.processingTime,
    required this.isPersonalized,
    required this.timestamp,
    this.metadata,
    this.analysisType,
    this.version,
  });

  factory AnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AnalysisResponse(
      analysis: json[ApiConfig.analysisField] as String? ?? '',
      processingTime:
          (json[ApiConfig.processingTimeField] as num?)?.toDouble() ?? 0.0,
      isPersonalized: json[ApiConfig.isPersonalizedField] as bool? ?? false,
      timestamp: json[ApiConfig.timestampField] as String? ??
          DateTime.now().toIso8601String(),
      metadata: json[ApiConfig.metadataField] as Map<String, dynamic>?,
      analysisType: json['analysis_type'] as String?,
      version: json['version'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ApiConfig.analysisField: analysis,
      ApiConfig.processingTimeField: processingTime,
      ApiConfig.isPersonalizedField: isPersonalized,
      ApiConfig.timestampField: timestamp,
      ApiConfig.metadataField: metadata,
      'analysis_type': analysisType,
      'version': version,
    };
  }

  // バリデーション
  bool get isValid => analysis.isNotEmpty && processingTime >= 0;

  // 分析結果の文字数
  int get analysisLength => analysis.length;

  // 処理時間（秒）を読みやすい形式で取得
  String get formattedProcessingTime {
    if (processingTime < 1.0) {
      return '${(processingTime * 1000).toInt()}ms';
    } else {
      return '${processingTime.toStringAsFixed(1)}秒';
    }
  }

  // タイムスタンプをDateTimeオブジェクトに変換
  DateTime get parsedTimestamp {
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return DateTime.now();
    }
  }

  // 分析タイプの日本語表示
  String get analysisTypeDisplay {
    switch (analysisType) {
      case 'camera_analysis':
        return 'カメラ分析';
      case 'area_analysis':
        return 'エリア分析';
      default:
        return '不明';
    }
  }

  // 個人化分析の説明
  String get personalizationDescription {
    return isPersonalized ? '🔐 あなたの好み設定を反映した個人化分析です' : '🔓 一般的な観点からの基本分析です';
  }
}

/// カメラ分析専用レスポンスモデル
class CameraAnalysisResponse extends AnalysisResponse {
  final String? imageUrl;
  final Map<String, dynamic>? imageMetadata;
  final String? extractedText;

  CameraAnalysisResponse({
    required String analysis,
    required double processingTime,
    required bool isPersonalized,
    required String timestamp,
    Map<String, dynamic>? metadata,
    this.imageUrl,
    this.imageMetadata,
    this.extractedText,
  }) : super(
          analysis: analysis,
          processingTime: processingTime,
          isPersonalized: isPersonalized,
          timestamp: timestamp,
          metadata: metadata,
          analysisType: 'camera_analysis',
        );

  factory CameraAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return CameraAnalysisResponse(
      analysis: json[ApiConfig.analysisField] as String? ?? '',
      processingTime:
          (json[ApiConfig.processingTimeField] as num?)?.toDouble() ?? 0.0,
      isPersonalized: json[ApiConfig.isPersonalizedField] as bool? ?? false,
      timestamp: json[ApiConfig.timestampField] as String? ??
          DateTime.now().toIso8601String(),
      metadata: json[ApiConfig.metadataField] as Map<String, dynamic>?,
      imageUrl: json['image_url'] as String?,
      imageMetadata: json['image_metadata'] as Map<String, dynamic>?,
      extractedText: json['extracted_text'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'image_url': imageUrl,
      'image_metadata': imageMetadata,
      'extracted_text': extractedText,
    });
    return json;
  }

  // 画像の有効性チェック
  bool get hasValidImage => imageUrl != null && imageUrl!.isNotEmpty;

  // OCRテキストの有効性チェック
  bool get hasExtractedText =>
      extractedText != null && extractedText!.isNotEmpty;
}

/// エリア分析専用レスポンスモデル
class AreaAnalysisResponse extends AnalysisResponse {
  final String? address;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? locationData;
  final int? facilityCount;
  final int? transportCount;

  AreaAnalysisResponse({
    required String analysis,
    required double processingTime,
    required bool isPersonalized,
    required String timestamp,
    Map<String, dynamic>? metadata,
    this.address,
    this.latitude,
    this.longitude,
    this.locationData,
    this.facilityCount,
    this.transportCount,
  }) : super(
          analysis: analysis,
          processingTime: processingTime,
          isPersonalized: isPersonalized,
          timestamp: timestamp,
          metadata: metadata,
          analysisType: 'area_analysis',
        );

  factory AreaAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AreaAnalysisResponse(
      analysis: json[ApiConfig.analysisField] as String? ?? '',
      processingTime:
          (json[ApiConfig.processingTimeField] as num?)?.toDouble() ?? 0.0,
      isPersonalized: json[ApiConfig.isPersonalizedField] as bool? ?? false,
      timestamp: json[ApiConfig.timestampField] as String? ??
          DateTime.now().toIso8601String(),
      metadata: json[ApiConfig.metadataField] as Map<String, dynamic>?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationData: json['location_data'] as Map<String, dynamic>?,
      facilityCount: json['facility_count'] as int?,
      transportCount: json['transport_count'] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'location_data': locationData,
      'facility_count': facilityCount,
      'transport_count': transportCount,
    });
    return json;
  }

  // 位置情報の有効性チェック
  bool get hasValidLocation => latitude != null && longitude != null;

  // 住所の有効性チェック
  bool get hasValidAddress => address != null && address!.isNotEmpty;

  // 施設・交通データの充実度
  String get dataRichness {
    final total = (facilityCount ?? 0) + (transportCount ?? 0);
    if (total >= 20) return '充実';
    if (total >= 10) return '標準';
    if (total >= 5) return '基本';
    return '限定的';
  }
}

/// 履歴取得レスポンスモデル
class AnalysisHistoryResponse {
  final List<AnalysisHistoryItem> history;
  final int total;
  final int limit;
  final String timestamp;

  AnalysisHistoryResponse({
    required this.history,
    required this.total,
    required this.limit,
    required this.timestamp,
  });

  factory AnalysisHistoryResponse.fromJson(Map<String, dynamic> json) {
    return AnalysisHistoryResponse(
      history: (json[ApiConfig.historyField] as List<dynamic>? ?? [])
          .map((item) => AnalysisHistoryItem.fromJson(item))
          .toList(),
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      timestamp: json[ApiConfig.timestampField] as String? ??
          DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ApiConfig.historyField: history.map((item) => item.toJson()).toList(),
      'total': total,
      'limit': limit,
      ApiConfig.timestampField: timestamp,
    };
  }

  bool get hasHistory => history.isNotEmpty;
  int get count => history.length;
}

/// 履歴アイテムモデル
class AnalysisHistoryItem {
  final String id;
  final String analysisType;
  final String summary;
  final String timestamp;
  final String? imageUrl;
  final String? address;
  final bool isPersonalized;
  final Map<String, dynamic>? metadata;

  AnalysisHistoryItem({
    required this.id,
    required this.analysisType,
    required this.summary,
    required this.timestamp,
    this.imageUrl,
    this.address,
    required this.isPersonalized,
    this.metadata,
  });

  factory AnalysisHistoryItem.fromJson(Map<String, dynamic> json) {
    return AnalysisHistoryItem(
      id: json['id'] as String,
      analysisType: json['analysis_type'] as String,
      summary: json['summary'] as String,
      timestamp: json[ApiConfig.timestampField] as String,
      imageUrl: json['image_url'] as String?,
      address: json['address'] as String?,
      isPersonalized: json[ApiConfig.isPersonalizedField] as bool? ?? false,
      metadata: json[ApiConfig.metadataField] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'analysis_type': analysisType,
      'summary': summary,
      ApiConfig.timestampField: timestamp,
      'image_url': imageUrl,
      'address': address,
      ApiConfig.isPersonalizedField: isPersonalized,
      ApiConfig.metadataField: metadata,
    };
  }

  // タイムスタンプをDateTimeオブジェクトに変換
  DateTime get parsedTimestamp {
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return DateTime.now();
    }
  }

  // 分析タイプの日本語表示
  String get analysisTypeDisplay {
    switch (analysisType) {
      case 'camera_analysis':
        return 'カメラ分析';
      case 'area_analysis':
        return 'エリア分析';
      default:
        return '不明';
    }
  }

  // アイコン取得
  String get icon {
    switch (analysisType) {
      case 'camera_analysis':
        return '📷';
      case 'area_analysis':
        return '🗺️';
      default:
        return '📄';
    }
  }

  // 表示用タイトル生成
  String get displayTitle {
    if (analysisType == 'camera_analysis') {
      return '物件写真の分析';
    } else if (analysisType == 'area_analysis' && address != null) {
      return address!;
    } else {
      return analysisTypeDisplay;
    }
  }

  // サマリーの短縮版（プレビュー用）
  String get shortSummary {
    if (summary.length <= 100) return summary;
    return '${summary.substring(0, 97)}...';
  }

  // 個人化分析の表示
  String get personalizationBadge {
    return isPersonalized ? '🔐 個人化' : '🔓 基本';
  }
}

/// APIエラーレスポンスモデル
class ApiErrorResponse {
  final String error;
  final String? message;
  final int? statusCode;
  final String timestamp;
  final Map<String, dynamic>? details;

  ApiErrorResponse({
    required this.error,
    this.message,
    this.statusCode,
    required this.timestamp,
    this.details,
  });

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) {
    return ApiErrorResponse(
      error: json[ApiConfig.errorField] as String? ?? 'Unknown Error',
      message: json[ApiConfig.messageField] as String?,
      statusCode: json['status_code'] as int?,
      timestamp: json[ApiConfig.timestampField] as String? ??
          DateTime.now().toIso8601String(),
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ApiConfig.errorField: error,
      ApiConfig.messageField: message,
      'status_code': statusCode,
      ApiConfig.timestampField: timestamp,
      'details': details,
    };
  }

  // ユーザーフレンドリーなエラーメッセージ
  String get userFriendlyMessage {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }

    switch (statusCode) {
      case 400:
        return 'リクエストに問題があります。入力内容を確認してください。';
      case 401:
        return 'ログインが必要です。';
      case 403:
        return 'この機能を利用する権限がありません。';
      case 404:
        return '要求されたデータが見つかりません。';
      case 429:
        return 'リクエストが多すぎます。しばらく待ってから再試行してください。';
      case 500:
        return 'サーバーエラーが発生しました。しばらく待ってから再試行してください。';
      case 503:
        return 'サービスが一時的に利用できません。';
      default:
        return 'エラーが発生しました。しばらく待ってから再試行してください。';
    }
  }

  // エラーの深刻度
  String get severity {
    if (statusCode == null) return 'unknown';
    if (statusCode! >= 500) return 'critical';
    if (statusCode! >= 400) return 'error';
    return 'warning';
  }
}

/// レスポンス共通ユーティリティ
class ResponseUtils {
  /// JSON が有効なAnalysisResponseかチェック
  static bool isValidAnalysisResponse(Map<String, dynamic>? json) {
    if (json == null) return false;
    return json.containsKey(ApiConfig.analysisField) &&
        json[ApiConfig.analysisField] is String &&
        json[ApiConfig.analysisField].toString().isNotEmpty;
  }

  /// JSON が有効なErrorResponseかチェック
  static bool isValidErrorResponse(Map<String, dynamic>? json) {
    if (json == null) return false;
    return json.containsKey(ApiConfig.errorField);
  }

  /// レスポンスタイプを判定
  static String getResponseType(Map<String, dynamic>? json) {
    if (json == null) return 'invalid';

    if (isValidErrorResponse(json)) return 'error';
    if (isValidAnalysisResponse(json)) {
      final analysisType = json['analysis_type'] as String?;
      if (analysisType == 'camera_analysis') return 'camera_analysis';
      if (analysisType == 'area_analysis') return 'area_analysis';
      return 'analysis';
    }
    if (json.containsKey(ApiConfig.historyField)) return 'history';

    return 'unknown';
  }

  /// 適切なレスポンスモデルを生成
  static dynamic parseResponse(Map<String, dynamic> json) {
    final type = getResponseType(json);

    switch (type) {
      case 'error':
        return ApiErrorResponse.fromJson(json);
      case 'camera_analysis':
        return CameraAnalysisResponse.fromJson(json);
      case 'area_analysis':
        return AreaAnalysisResponse.fromJson(json);
      case 'analysis':
        return AnalysisResponse.fromJson(json);
      case 'history':
        return AnalysisHistoryResponse.fromJson(json);
      default:
        throw Exception('Unknown response type: $type');
    }
  }
}
