// lib/models/user_preference_model.dart

import '../utils/constants.dart';

/// ユーザー好み設定モデル
/// カメラ分析・エリア分析両対応の統一設定
class UserPreferenceModel {
  // === 交通・アクセス重視項目（主にエリア分析で活用） ===
  final bool prioritizeStationAccess; // 駅近重視
  final bool prioritizeMultipleLines; // 複数路線重視
  final bool prioritizeCarAccess; // 車アクセス重視

  // === 周辺施設重視項目（主にエリア分析で活用） ===
  final bool prioritizeMedical; // 医療施設重視
  final bool prioritizeShopping; // 商業施設重視
  final bool prioritizeEducation; // 教育施設重視
  final bool prioritizeParks; // 公園・緑地重視

  // === ライフスタイル（カメラ・エリア分析共通） ===
  final String lifestyleType; // single/couple/family/senior

  // === 予算感（カメラ・エリア分析共通） ===
  final String budgetPriority; // cost/balance/convenience

  // === メタデータ ===
  final DateTime updatedAt;

  UserPreferenceModel({
    this.prioritizeStationAccess = false,
    this.prioritizeMultipleLines = false,
    this.prioritizeCarAccess = false,
    this.prioritizeMedical = false,
    this.prioritizeShopping = false,
    this.prioritizeEducation = false,
    this.prioritizeParks = false,
    this.lifestyleType = '',
    this.budgetPriority = '',
    required this.updatedAt,
  });

  // === JSON変換 ===

  factory UserPreferenceModel.fromJson(Map<String, dynamic> json) {
    return UserPreferenceModel(
      prioritizeStationAccess:
          json['prioritizeStationAccess'] as bool? ?? false,
      prioritizeMultipleLines:
          json['prioritizeMultipleLines'] as bool? ?? false,
      prioritizeCarAccess: json['prioritizeCarAccess'] as bool? ?? false,
      prioritizeMedical: json['prioritizeMedical'] as bool? ?? false,
      prioritizeShopping: json['prioritizeShopping'] as bool? ?? false,
      prioritizeEducation: json['prioritizeEducation'] as bool? ?? false,
      prioritizeParks: json['prioritizeParks'] as bool? ?? false,
      lifestyleType: json['lifestyleType'] as String? ?? '',
      budgetPriority: json['budgetPriority'] as String? ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prioritizeStationAccess': prioritizeStationAccess,
      'prioritizeMultipleLines': prioritizeMultipleLines,
      'prioritizeCarAccess': prioritizeCarAccess,
      'prioritizeMedical': prioritizeMedical,
      'prioritizeShopping': prioritizeShopping,
      'prioritizeEducation': prioritizeEducation,
      'prioritizeParks': prioritizeParks,
      'lifestyleType': lifestyleType,
      'budgetPriority': budgetPriority,
      'updatedAt': updatedAt.toIso8601String(),
      'version': 'v3.0',
    };
  }

  // === コピー・変更 ===

  UserPreferenceModel copyWith({
    bool? prioritizeStationAccess,
    bool? prioritizeMultipleLines,
    bool? prioritizeCarAccess,
    bool? prioritizeMedical,
    bool? prioritizeShopping,
    bool? prioritizeEducation,
    bool? prioritizeParks,
    String? lifestyleType,
    String? budgetPriority,
    DateTime? updatedAt,
  }) {
    return UserPreferenceModel(
      prioritizeStationAccess:
          prioritizeStationAccess ?? this.prioritizeStationAccess,
      prioritizeMultipleLines:
          prioritizeMultipleLines ?? this.prioritizeMultipleLines,
      prioritizeCarAccess: prioritizeCarAccess ?? this.prioritizeCarAccess,
      prioritizeMedical: prioritizeMedical ?? this.prioritizeMedical,
      prioritizeShopping: prioritizeShopping ?? this.prioritizeShopping,
      prioritizeEducation: prioritizeEducation ?? this.prioritizeEducation,
      prioritizeParks: prioritizeParks ?? this.prioritizeParks,
      lifestyleType: lifestyleType ?? this.lifestyleType,
      budgetPriority: budgetPriority ?? this.budgetPriority,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // === バリデーション・チェック ===

  /// 設定が空かどうかをチェック
  bool get isEmpty {
    return !prioritizeStationAccess &&
        !prioritizeMultipleLines &&
        !prioritizeCarAccess &&
        !prioritizeMedical &&
        !prioritizeShopping &&
        !prioritizeEducation &&
        !prioritizeParks &&
        lifestyleType.isEmpty &&
        budgetPriority.isEmpty;
  }

  /// 有効な設定があるかチェック
  bool get isConfigured => !isEmpty;

  /// 交通関連の設定があるか
  bool get hasTransportPreferences {
    return prioritizeStationAccess ||
        prioritizeMultipleLines ||
        prioritizeCarAccess;
  }

  /// 施設関連の設定があるか
  bool get hasFacilityPreferences {
    return prioritizeMedical ||
        prioritizeShopping ||
        prioritizeEducation ||
        prioritizeParks;
  }

  /// ライフスタイル・予算設定があるか
  bool get hasGeneralPreferences {
    return lifestyleType.isNotEmpty || budgetPriority.isNotEmpty;
  }

  // === Cloud Run API用の文字列生成 ===

  /// Cloud Run APIのpreferencesフィールド用のプロンプト文字列
  String toPromptString() {
    if (isEmpty) return '';

    List<String> preferences = [];

    // 交通手段の好み
    List<String> transport = [];
    if (prioritizeStationAccess) transport.add('駅近重視');
    if (prioritizeMultipleLines) transport.add('複数路線アクセス重視');
    if (prioritizeCarAccess) transport.add('車移動重視');
    if (transport.isNotEmpty) {
      preferences.add('交通: ${transport.join('、')}');
    }

    // 周辺施設の好み
    List<String> facilities = [];
    if (prioritizeMedical) facilities.add('医療施設');
    if (prioritizeShopping) facilities.add('商業施設');
    if (prioritizeEducation) facilities.add('教育施設');
    if (prioritizeParks) facilities.add('公園・緑地');
    if (facilities.isNotEmpty) {
      preferences.add('施設: ${facilities.join('、')}重視');
    }

    // ライフスタイル
    if (lifestyleType.isNotEmpty) {
      final lifestyle = _getLifestyleDisplayName(lifestyleType);
      preferences.add('ライフスタイル: $lifestyle');
    }

    // 予算感
    if (budgetPriority.isNotEmpty) {
      final budget = _getBudgetDisplayName(budgetPriority);
      preferences.add('予算感: $budget');
    }

    return preferences.join('、');
  }

  // === 表示用ヘルパー ===

  /// カメラ分析での活用可能性
  bool get isApplicableForCamera {
    return lifestyleType.isNotEmpty || budgetPriority.isNotEmpty;
  }

  /// エリア分析での活用可能性
  bool get isApplicableForArea {
    return hasTransportPreferences ||
        hasFacilityPreferences ||
        hasGeneralPreferences;
  }

  /// 機能別の適用可能設定数
  Map<String, int> get applicabilityStats {
    return {
      'camera': isApplicableForCamera ? 1 : 0,
      'area': (hasTransportPreferences ? 1 : 0) +
          (hasFacilityPreferences ? 1 : 0) +
          (hasGeneralPreferences ? 1 : 0),
      'total': _getTotalConfiguredCount(),
    };
  }

  /// 設定済み項目の合計数
  int _getTotalConfiguredCount() {
    int count = 0;

    // 交通関連
    if (prioritizeStationAccess) count++;
    if (prioritizeMultipleLines) count++;
    if (prioritizeCarAccess) count++;

    // 施設関連
    if (prioritizeMedical) count++;
    if (prioritizeShopping) count++;
    if (prioritizeEducation) count++;
    if (prioritizeParks) count++;

    // 一般設定
    if (lifestyleType.isNotEmpty) count++;
    if (budgetPriority.isNotEmpty) count++;

    return count;
  }

  /// カテゴリ別設定状況
  Map<String, dynamic> get categoryStatus {
    return {
      'transport': {
        'count': [
          prioritizeStationAccess,
          prioritizeMultipleLines,
          prioritizeCarAccess
        ].where((x) => x).length,
        'items': _getTransportItems(),
      },
      'facility': {
        'count': [
          prioritizeMedical,
          prioritizeShopping,
          prioritizeEducation,
          prioritizeParks
        ].where((x) => x).length,
        'items': _getFacilityItems(),
      },
      'general': {
        'count': [lifestyleType.isNotEmpty, budgetPriority.isNotEmpty]
            .where((x) => x)
            .length,
        'items': _getGeneralItems(),
      },
    };
  }

  List<String> _getTransportItems() {
    List<String> items = [];
    if (prioritizeStationAccess) items.add('駅近重視');
    if (prioritizeMultipleLines) items.add('複数路線');
    if (prioritizeCarAccess) items.add('車アクセス');
    return items;
  }

  List<String> _getFacilityItems() {
    List<String> items = [];
    if (prioritizeMedical) items.add('医療施設');
    if (prioritizeShopping) items.add('商業施設');
    if (prioritizeEducation) items.add('教育施設');
    if (prioritizeParks) items.add('公園・緑地');
    return items;
  }

  List<String> _getGeneralItems() {
    List<String> items = [];
    if (lifestyleType.isNotEmpty) {
      items.add(_getLifestyleDisplayName(lifestyleType));
    }
    if (budgetPriority.isNotEmpty) {
      items.add(_getBudgetDisplayName(budgetPriority));
    }
    return items;
  }

  // === プライベートヘルパー ===

  String _getLifestyleDisplayName(String type) {
    switch (type) {
      case PreferenceConstants.lifestyleSingle:
        return '単身者';
      case PreferenceConstants.lifestyleCouple:
        return '夫婦・カップル';
      case PreferenceConstants.lifestyleFamily:
        return '子育て世帯';
      case PreferenceConstants.lifestyleSenior:
        return 'シニア世帯';
      default:
        return type;
    }
  }

  String _getBudgetDisplayName(String priority) {
    switch (priority) {
      case PreferenceConstants.budgetCost:
        return 'コスト重視';
      case PreferenceConstants.budgetBalance:
        return 'バランス重視';
      case PreferenceConstants.budgetConvenience:
        return '利便性重視';
      default:
        return priority;
    }
  }

  // === 分析タイプ判定 ===

  /// 分析タイプを返す（基本 or 個人化）
  String get analysisType {
    return isEmpty
        ? AnalysisConstants.basicAnalysis
        : AnalysisConstants.personalizedAnalysis;
  }

  /// 個人化分析が可能か
  bool get canPersonalize => !isEmpty;

  // === 統計・デバッグ情報 ===

  /// デバッグ用の設定概要
  String get debugSummary {
    if (isEmpty) return 'すべて未設定';

    final stats = applicabilityStats;
    return '設定数: ${stats['total']}, カメラ適用: ${isApplicableForCamera}, エリア適用: ${isApplicableForArea}';
  }

  /// 詳細レポート（開発・デバッグ用）
  Map<String, dynamic> get detailedReport {
    return {
      'is_configured': isConfigured,
      'is_empty': isEmpty,
      'categories': categoryStatus,
      'applicability': {
        'camera': isApplicableForCamera,
        'area': isApplicableForArea,
      },
      'prompt_string': toPromptString(),
      'analysis_type': analysisType,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'UserPreferenceModel(configured: $isConfigured, camera: $isApplicableForCamera, area: $isApplicableForArea)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserPreferenceModel &&
        other.prioritizeStationAccess == prioritizeStationAccess &&
        other.prioritizeMultipleLines == prioritizeMultipleLines &&
        other.prioritizeCarAccess == prioritizeCarAccess &&
        other.prioritizeMedical == prioritizeMedical &&
        other.prioritizeShopping == prioritizeShopping &&
        other.prioritizeEducation == prioritizeEducation &&
        other.prioritizeParks == prioritizeParks &&
        other.lifestyleType == lifestyleType &&
        other.budgetPriority == budgetPriority;
  }

  @override
  int get hashCode {
    return Object.hash(
      prioritizeStationAccess,
      prioritizeMultipleLines,
      prioritizeCarAccess,
      prioritizeMedical,
      prioritizeShopping,
      prioritizeEducation,
      prioritizeParks,
      lifestyleType,
      budgetPriority,
    );
  }
}

/// 設定オプションのデータクラス（UI用）
class PreferenceOption {
  final String key;
  final String title;
  final String description;
  final String? applicableFeature; // どの機能で主に使われるか

  const PreferenceOption(
    this.key,
    this.title,
    this.description, {
    this.applicableFeature,
  });
}

/// 好み設定のカテゴリ定義
class PreferenceCategory {
  static const String transport = 'transport';
  static const String facility = 'facility';
  static const String lifestyle = 'lifestyle';
  static const String budget = 'budget';

  static const List<String> all = [transport, facility, lifestyle, budget];

  static String getDisplayName(String category) {
    switch (category) {
      case transport:
        return '交通・アクセス';
      case facility:
        return '周辺施設';
      case lifestyle:
        return 'ライフスタイル';
      case budget:
        return '予算感';
      default:
        return category;
    }
  }

  static String getDescription(String category) {
    switch (category) {
      case transport:
        return 'エリア分析で交通利便性の評価に影響します';
      case facility:
        return 'エリア分析で周辺施設の重要度評価に影響します';
      case lifestyle:
        return 'カメラ・エリア分析両方で生活スタイルに合わせた評価を行います';
      case budget:
        return 'カメラ・エリア分析両方でコストパフォーマンスの視点を調整します';
      default:
        return '';
    }
  }
}
