// lib/services/user_preference_service.dart

import 'package:flutter/material.dart';
import '../models/user_preference_model.dart';
import '../services/firestore_service.dart';

/// Maisoku AI v1.0: ユーザー好み設定サービス
///
/// 機能分離対応：
/// - カメラ分析：物件写真の評価・分析結果の個人化
/// - エリア分析：交通・施設情報の重み付け・優先度設定
/// - 両機能で共通の好み設定を使用し、それぞれに最適化
class UserPreferenceService {
  final FirestoreService _firestoreService;

  UserPreferenceService({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  // === 基本CRUD操作 ===

  /// ユーザー好み設定を取得
  Future<UserPreferenceModel?> getUserPreferences(String userId) async {
    if (userId.isEmpty) {
      print('⚠️ ユーザーIDが空です');
      return null;
    }

    try {
      final preferences = await _firestoreService.getUserPreferences(userId);

      if (preferences != null) {
        print('✅ ユーザー好み設定取得完了: $userId');
        return preferences;
      } else {
        print('📝 好み設定が未設定: $userId');
        return null;
      }
    } catch (e) {
      print('❌ ユーザー好み設定取得エラー: $e');
      return null;
    }
  }

  /// 簡易版の好み設定取得（互換性用）
  Future<UserPreferenceModel?> getPreferences() async {
    // この実装では、Firebase Authから現在のユーザーIDを取得する必要があります
    // 一時的にnullを返す（実際の実装では認証サービスと連携）
    return null;
  }

  /// ユーザー好み設定を保存
  Future<bool> saveUserPreferences(
    String userId,
    UserPreferenceModel preferences,
  ) async {
    if (userId.isEmpty) {
      print('⚠️ ユーザーIDが空です');
      return false;
    }

    try {
      // バリデーション
      final validationResult = validatePreferences(preferences);
      if (!validationResult.isValid) {
        print('⚠️ 好み設定バリデーションエラー: ${validationResult.errors}');
        return false;
      }

      // 保存実行
      await _firestoreService.saveUserPreferences(userId, preferences);

      print('✅ ユーザー好み設定保存完了: $userId');

      return true;
    } catch (e) {
      print('❌ ユーザー好み設定保存エラー: $e');
      return false;
    }
  }

  /// ユーザー好み設定を削除
  Future<bool> deleteUserPreferences(String userId) async {
    if (userId.isEmpty) {
      print('⚠️ ユーザーIDが空です');
      return false;
    }

    try {
      await _firestoreService.deleteUserPreferences(userId);
      print('✅ ユーザー好み設定削除完了: $userId');
      return true;
    } catch (e) {
      print('❌ ユーザー好み設定削除エラー: $e');
      return false;
    }
  }

  // === バリデーション機能 ===

  /// 好み設定のバリデーション
  PreferenceValidationResult validatePreferences(
      UserPreferenceModel preferences) {
    final errors = <String>[];
    final warnings = <String>[];

    // 交通設定の検証
    final transportSettings = [
      preferences.prioritizeStationAccess,
      preferences.prioritizeMultipleLines,
      preferences.prioritizeCarAccess,
    ];

    if (!transportSettings.any((setting) => setting)) {
      warnings.add('交通手段の優先度が設定されていません');
    }

    // 施設設定の検証
    final facilitySettings = [
      preferences.prioritizeMedical,
      preferences.prioritizeShopping,
      preferences.prioritizeEducation,
      preferences.prioritizeParks,
    ];

    if (!facilitySettings.any((setting) => setting)) {
      warnings.add('周辺施設の優先度が設定されていません');
    }

    // ライフスタイル・予算設定の検証
    if (preferences.lifestyleType.isEmpty) {
      warnings.add('ライフスタイルが設定されていません');
    }

    if (preferences.budgetPriority.isEmpty) {
      warnings.add('予算優先度が設定されていません');
    }

    // 矛盾設定の検証
    if (preferences.prioritizeCarAccess &&
        preferences.prioritizeStationAccess) {
      warnings.add('車重視と駅近重視が同時に設定されています');
    }

    return PreferenceValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// 設定の完成度をチェック
  PreferenceCompleteness checkCompleteness(UserPreferenceModel preferences) {
    int totalItems = 8; // 全設定項目数（prioritizeBusAccessを除く）
    int configuredItems = 0;

    // 交通設定
    if (preferences.prioritizeStationAccess) configuredItems++;
    if (preferences.prioritizeMultipleLines) configuredItems++;
    if (preferences.prioritizeCarAccess) configuredItems++;

    // 施設設定
    if (preferences.prioritizeMedical) configuredItems++;
    if (preferences.prioritizeShopping) configuredItems++;
    if (preferences.prioritizeEducation) configuredItems++;
    if (preferences.prioritizeParks) configuredItems++;

    // その他設定
    if (preferences.lifestyleType.isNotEmpty) configuredItems++;

    final completenessRatio = configuredItems / totalItems;

    return PreferenceCompleteness(
      totalItems: totalItems,
      configuredItems: configuredItems,
      completenessRatio: completenessRatio,
      isMinimallyConfigured: configuredItems >= 3, // 最低3項目
      isWellConfigured: configuredItems >= 5, // 推奨5項目以上（バス設定削除により調整）
      isFullyConfigured: configuredItems == totalItems,
    );
  }

  // === 分析向け機能 ===

  /// カメラ分析用のプロンプト文字列を生成
  String generateCameraAnalysisPrompt(UserPreferenceModel preferences) {
    final promptParts = <String>[];

    // ライフスタイル重視
    if (preferences.lifestyleType.isNotEmpty) {
      promptParts.add('ライフスタイル: ${preferences.lifestyleType}');
    }

    // 予算重視
    if (preferences.budgetPriority.isNotEmpty) {
      promptParts.add('予算重視: ${preferences.budgetPriority}');
    }

    // 施設重視（物件選びへの影響を考慮）
    final facilities = <String>[];
    if (preferences.prioritizeMedical) facilities.add('医療施設');
    if (preferences.prioritizeShopping) facilities.add('買い物施設');
    if (preferences.prioritizeEducation) facilities.add('教育施設');
    if (preferences.prioritizeParks) facilities.add('公園・緑地');

    if (facilities.isNotEmpty) {
      promptParts.add('重視施設: ${facilities.join('・')}');
    }

    return promptParts.join('、');
  }

  /// エリア分析用のプロンプト文字列を生成
  String generateAreaAnalysisPrompt(UserPreferenceModel preferences) {
    final promptParts = <String>[];

    // 交通重視
    final transport = <String>[];
    if (preferences.prioritizeStationAccess) transport.add('駅近重視');
    if (preferences.prioritizeMultipleLines) transport.add('複数路線重視');
    if (preferences.prioritizeCarAccess) transport.add('車利用重視');

    if (transport.isNotEmpty) {
      promptParts.add('交通: ${transport.join('・')}');
    }

    // 施設重視
    final facilities = <String>[];
    if (preferences.prioritizeMedical) facilities.add('医療施設重視');
    if (preferences.prioritizeShopping) facilities.add('商業施設重視');
    if (preferences.prioritizeEducation) facilities.add('教育施設重視');
    if (preferences.prioritizeParks) facilities.add('公園重視');

    if (facilities.isNotEmpty) {
      promptParts.add('施設: ${facilities.join('・')}');
    }

    // ライフスタイル
    if (preferences.lifestyleType.isNotEmpty) {
      promptParts.add('ライフスタイル: ${preferences.lifestyleType}');
    }

    return promptParts.join('、');
  }

  /// 設定内容の分析レポートを生成
  String generatePreferenceReport(UserPreferenceModel preferences) {
    final completeness = checkCompleteness(preferences);
    final validation = validatePreferences(preferences);

    final report = StringBuffer();

    report.writeln('📊 好み設定レポート');
    report.writeln('');

    // 完成度
    report.writeln(
        '🎯 設定完成度: ${(completeness.completenessRatio * 100).round()}%');
    report.writeln(
        '   設定項目: ${completeness.configuredItems}/${completeness.totalItems}');

    if (completeness.isFullyConfigured) {
      report.writeln('   ✅ 全項目設定完了');
    } else if (completeness.isWellConfigured) {
      report.writeln('   ✅ 十分に設定済み');
    } else if (completeness.isMinimallyConfigured) {
      report.writeln('   ⚠️ 最低限の設定');
    } else {
      report.writeln('   ❌ 設定不足');
    }

    report.writeln('');

    // 警告・エラー
    if (validation.warnings.isNotEmpty) {
      report.writeln('⚠️ 注意事項:');
      for (final warning in validation.warnings) {
        report.writeln('   - $warning');
      }
      report.writeln('');
    }

    if (validation.errors.isNotEmpty) {
      report.writeln('❌ エラー:');
      for (final error in validation.errors) {
        report.writeln('   - $error');
      }
    }

    return report.toString();
  }

  // === デバッグ・開発用機能 ===

  /// デバッグ情報を表示
  void printDebugInfo() {
    print('''
🔍 UserPreferenceService Debug Info:
  Firestore Integration: ✅
  Validation: ✅
  Camera Analysis Support: ✅
  Area Analysis Support: ✅
  Prompt Generation: ✅
  Version: 1.0
''');
  }

  /// 設定項目の使用状況を分析
  Future<Map<String, dynamic>> analyzeUsageStatistics(
      List<String> userIds) async {
    final stats = <String, int>{};
    int totalUsers = 0;

    for (final userId in userIds) {
      final preferences = await getUserPreferences(userId);
      if (preferences != null) {
        totalUsers++;

        // 各設定項目の使用率を集計
        if (preferences.prioritizeStationAccess) {
          stats['prioritizeStationAccess'] =
              (stats['prioritizeStationAccess'] ?? 0) + 1;
        }
        if (preferences.prioritizeMultipleLines) {
          stats['prioritizeMultipleLines'] =
              (stats['prioritizeMultipleLines'] ?? 0) + 1;
        }
        if (preferences.prioritizeCarAccess) {
          stats['prioritizeCarAccess'] =
              (stats['prioritizeCarAccess'] ?? 0) + 1;
        }
        if (preferences.prioritizeMedical) {
          stats['prioritizeMedical'] = (stats['prioritizeMedical'] ?? 0) + 1;
        }
        if (preferences.prioritizeShopping) {
          stats['prioritizeShopping'] = (stats['prioritizeShopping'] ?? 0) + 1;
        }
        if (preferences.prioritizeEducation) {
          stats['prioritizeEducation'] =
              (stats['prioritizeEducation'] ?? 0) + 1;
        }
        if (preferences.prioritizeParks) {
          stats['prioritizeParks'] = (stats['prioritizeParks'] ?? 0) + 1;
        }
      }
    }

    // 使用率を計算
    final usageRates = <String, double>{};
    for (final entry in stats.entries) {
      usageRates[entry.key] = totalUsers > 0 ? entry.value / totalUsers : 0.0;
    }

    return {
      'totalUsers': totalUsers,
      'usageCounts': stats,
      'usageRates': usageRates,
    };
  }
}

// === データクラス ===

/// バリデーション結果
class PreferenceValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  PreferenceValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}

/// 設定完成度
class PreferenceCompleteness {
  final int totalItems;
  final int configuredItems;
  final double completenessRatio;
  final bool isMinimallyConfigured;
  final bool isWellConfigured;
  final bool isFullyConfigured;

  PreferenceCompleteness({
    required this.totalItems,
    required this.configuredItems,
    required this.completenessRatio,
    required this.isMinimallyConfigured,
    required this.isWellConfigured,
    required this.isFullyConfigured,
  });

  String get statusText {
    if (isFullyConfigured) return '完璧';
    if (isWellConfigured) return '良好';
    if (isMinimallyConfigured) return '最低限';
    return '不足';
  }

  Color get statusColor {
    if (isFullyConfigured) return const Color(0xFF4CAF50);
    if (isWellConfigured) return const Color(0xFF8BC34A);
    if (isMinimallyConfigured) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}
