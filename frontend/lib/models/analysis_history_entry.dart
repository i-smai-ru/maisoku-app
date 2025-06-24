// lib/models/analysis_history_entry.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Maisoku AI v1.0: カメラ分析履歴専用モデル
///
/// 機能分離での変更点：
/// - エリア分析は履歴保存なし（揮発的表示）
/// - カメラ分析のみ履歴保存対象
/// - Firebase Storageとの連携によるimage URL管理
/// - Cloud Run API + Vertex AI Gemini対応
class AnalysisHistoryEntry {
  final String id; // Firestore Document ID
  final String userId;
  final Timestamp timestamp;
  final String analysisTextSummary; // AI分析結果の要約
  final String analysisTextFull; // AI分析結果の完全版
  final String imageURL; // Firebase Storageの画像URL
  final String imagePath; // ローカル画像パス（一時的）

  // 個人化関連
  final bool isPersonalized; // 個人化分析かどうか
  final String? preferenceSnapshot; // 分析時の好み設定スナップショット

  // メタデータ
  final String analysisVersion; // アプリバージョン
  final double? processingTimeSeconds; // 分析時間

  AnalysisHistoryEntry({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.analysisTextSummary,
    required this.analysisTextFull,
    required this.imageURL,
    required this.imagePath,
    this.isPersonalized = false,
    this.preferenceSnapshot,
    this.analysisVersion = '1.0',
    this.processingTimeSeconds,
  });

  /// 新規カメラ分析履歴作成用コンストラクタ
  factory AnalysisHistoryEntry.fromCameraAnalysis({
    required String userId,
    required String analysisText,
    required String imageURL,
    String? imagePath,
    bool isPersonalized = false,
    String? preferenceSnapshot,
    double? processingTimeSeconds,
  }) {
    final now = Timestamp.now();
    final summary = _extractSummary(analysisText);

    return AnalysisHistoryEntry(
      id: '', // Firestore保存時に自動生成
      userId: userId,
      timestamp: now,
      analysisTextSummary: summary,
      analysisTextFull: analysisText,
      imageURL: imageURL,
      imagePath: imagePath,
      isPersonalized: isPersonalized,
      preferenceSnapshot: preferenceSnapshot,
      analysisVersion: '1.0',
      processingTimeSeconds: processingTimeSeconds,
    );
  }

  /// Firestoreから復元
  factory AnalysisHistoryEntry.fromJson(Map<String, dynamic> json, String id) {
    return AnalysisHistoryEntry(
      id: id,
      userId: json['userId'] as String? ?? '',
      timestamp: json['timestamp'] as Timestamp? ?? Timestamp.now(),
      analysisTextSummary: json['analysisTextSummary'] as String? ?? '',
      analysisTextFull: json['analysisTextFull'] as String? ??
          json['analysisTextSummary'] as String? ??
          '',
      imageURL: json['imageURL'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      isPersonalized: json['isPersonalized'] as bool? ?? false,
      preferenceSnapshot: json['preferenceSnapshot'] as String?,
      analysisVersion: json['analysisVersion'] as String? ?? '1.0',
      processingTimeSeconds:
          (json['processingTimeSeconds'] as num?)?.toDouble(),
    );
  }

  /// Firestoreへ保存
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'timestamp': timestamp,
      'analysisTextSummary': analysisTextSummary,
      'analysisTextFull': analysisTextFull,
      'imageURL': imageURL,
      'isPersonalized': isPersonalized,
      'preferenceSnapshot': preferenceSnapshot,
      'analysisVersion': analysisVersion,
      'processingTimeSeconds': processingTimeSeconds,
      'ocrText': ocrText, // 互換性のため保持
      // imagePathはローカル用のため保存しない
    };
  }

  /// コピーコンストラクタ
  AnalysisHistoryEntry copyWith({
    String? id,
    String? userId,
    Timestamp? timestamp,
    String? analysisTextSummary,
    String? analysisTextFull,
    String? imageURL,
    String? imagePath,
    bool? isPersonalized,
    String? preferenceSnapshot,
    String? analysisVersion,
    double? processingTimeSeconds,
  }) {
    return AnalysisHistoryEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      analysisTextSummary: analysisTextSummary ?? this.analysisTextSummary,
      analysisTextFull: analysisTextFull ?? this.analysisTextFull,
      imageURL: imageURL ?? this.imageURL,
      imagePath: imagePath ?? this.imagePath,
      isPersonalized: isPersonalized ?? this.isPersonalized,
      preferenceSnapshot: preferenceSnapshot ?? this.preferenceSnapshot,
      analysisVersion: analysisVersion ?? this.analysisVersion,
      processingTimeSeconds:
          processingTimeSeconds ?? this.processingTimeSeconds,
    );
  }

  // === 表示用ユーティリティ ===

  /// 履歴一覧表示用のサマリーテキスト
  String get displaySummary {
    if (analysisTextSummary.isNotEmpty) {
      // 最初の80文字で切り詰め
      return analysisTextSummary.length > 80
          ? '${analysisTextSummary.substring(0, 80)}...'
          : analysisTextSummary;
    }

    // フォールバック
    return analysisTextFull.length > 80
        ? '${analysisTextFull.substring(0, 80)}...'
        : analysisTextFull;
  }

  /// 日時の表示用フォーマット
  String get formattedDate {
    final dateTime = timestamp.toDate();
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 詳細な日時フォーマット
  String get detailedFormattedDate {
    final dateTime = timestamp.toDate();
    final weekdays = ['日', '月', '火', '水', '木', '金', '土'];
    final weekday = weekdays[dateTime.weekday % 7];

    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日(${weekday}) '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 分析タイプの表示文字列
  String get analysisTypeDisplay {
    if (isPersonalized) {
      return '🔐 個人化分析';
    } else {
      return '🔓 基本分析';
    }
  }

  /// 処理時間の表示文字列
  String get processingTimeDisplay {
    if (processingTimeSeconds == null) return '';

    if (processingTimeSeconds! < 1.0) {
      return '${(processingTimeSeconds! * 1000).round()}ms';
    } else {
      return '${processingTimeSeconds!.toStringAsFixed(1)}秒';
    }
  }

  // === バリデーション ===

  /// エントリが有効かどうかを判定
  bool get isValid {
    return userId.isNotEmpty &&
        (analysisTextSummary.isNotEmpty || analysisTextFull.isNotEmpty) &&
        imageURL.isNotEmpty;
  }

  /// 画像が利用可能かどうか
  bool get hasValidImage {
    return imageURL.isNotEmpty && imageURL.startsWith('http');
  }

  /// 再分析可能かどうか
  bool get canReanalyze {
    return hasValidImage;
  }

  // === デバッグ・開発用 ===

  /// デバッグ情報の表示
  String get debugInfo {
    return '''
AnalysisHistoryEntry Debug Info:
  ID: $id
  User ID: $userId
  Timestamp: $formattedDate
  Analysis Version: $analysisVersion
  Is Personalized: $isPersonalized
  Processing Time: ${processingTimeDisplay}
  Image URL: ${imageURL.isNotEmpty ? '✓' : '✗'}
  Summary Length: ${analysisTextSummary.length}
  Full Text Length: ${analysisTextFull.length}
  Has Preference Snapshot: ${preferenceSnapshot != null ? '✓' : '✗'}
  Is Valid: ${isValid ? '✓' : '✗'}
  Can Reanalyze: ${canReanalyze ? '✓' : '✗'}
''';
  }

  @override
  String toString() {
    return 'AnalysisHistoryEntry(id: $id, userId: $userId, timestamp: $formattedDate, isPersonalized: $isPersonalized)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnalysisHistoryEntry &&
        other.id == id &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(id, userId);

  // === プライベートヘルパー ===

  /// 分析テキストから要約を抽出
  static String _extractSummary(String fullText) {
    if (fullText.isEmpty) return '';

    // 最初の段落または80文字以内で要約作成
    final lines = fullText.split('\n');
    String summary = lines.first.trim();

    // 空行の場合は次の行を取得
    if (summary.isEmpty && lines.length > 1) {
      summary = lines[1].trim();
    }

    // 長すぎる場合は切り詰め
    if (summary.length > 80) {
      summary = '${summary.substring(0, 77)}...';
    }

    return summary;
  }
}
