// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// v1.0: ユーザー情報モデル
///
/// v1.0での用途：
/// - カメラ分析：履歴保存・個人化分析に使用
/// - エリア分析：個人化分析時のみ使用（基本分析時は不要）
/// - 好み設定：両機能共通で使用
class UserModel {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime updatedAt;

  // v1.0: 音声読み上げ設定
  final bool audioEnabled;

  // v1.0: 機能別利用統計
  final int cameraAnalysisCount;
  final int areaAnalysisCount;

  // v1.0: 最終活動日時
  final DateTime? lastCameraAnalysisAt;
  final DateTime? lastAreaAnalysisAt;

  UserModel({
    required this.id,
    this.email,
    this.displayName,
    this.photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.audioEnabled = true,
    this.cameraAnalysisCount = 0,
    this.areaAnalysisCount = 0,
    this.lastCameraAnalysisAt,
    this.lastAreaAnalysisAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Firebase Authからの基本情報で作成
  factory UserModel.fromFirebaseAuth({
    required String uid,
    String? email,
    String? displayName,
    String? photoURL,
  }) {
    return UserModel(
      id: uid,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
    );
  }

  /// Firestoreから復元
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      audioEnabled: json['audioEnabled'] as bool? ?? true,
      cameraAnalysisCount: json['cameraAnalysisCount'] as int? ?? 0,
      areaAnalysisCount: json['areaAnalysisCount'] as int? ?? 0,
      lastCameraAnalysisAt: _parseDateTime(json['lastCameraAnalysisAt']),
      lastAreaAnalysisAt: _parseDateTime(json['lastAreaAnalysisAt']),
    );
  }

  /// Firestoreへ保存
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'audioEnabled': audioEnabled,
      'cameraAnalysisCount': cameraAnalysisCount,
      'areaAnalysisCount': areaAnalysisCount,
      'lastCameraAnalysisAt': lastCameraAnalysisAt != null
          ? Timestamp.fromDate(lastCameraAnalysisAt!)
          : null,
      'lastAreaAnalysisAt': lastAreaAnalysisAt != null
          ? Timestamp.fromDate(lastAreaAnalysisAt!)
          : null,
    };
  }

  /// v1.0: カメラ分析実行時の統計更新
  UserModel incrementCameraAnalysis() {
    return copyWith(
      cameraAnalysisCount: cameraAnalysisCount + 1,
      lastCameraAnalysisAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// v1.0: エリア分析実行時の統計更新
  UserModel incrementAreaAnalysis() {
    return copyWith(
      areaAnalysisCount: areaAnalysisCount + 1,
      lastAreaAnalysisAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 音声設定の更新
  UserModel updateAudioSetting(bool enabled) {
    return copyWith(
      audioEnabled: enabled,
      updatedAt: DateTime.now(),
    );
  }

  /// プロフィール情報の更新
  UserModel updateProfile({
    String? displayName,
    String? photoURL,
  }) {
    return copyWith(
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      updatedAt: DateTime.now(),
    );
  }

  /// コピーコンストラクタ
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? audioEnabled,
    int? cameraAnalysisCount,
    int? areaAnalysisCount,
    DateTime? lastCameraAnalysisAt,
    DateTime? lastAreaAnalysisAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      audioEnabled: audioEnabled ?? this.audioEnabled,
      cameraAnalysisCount: cameraAnalysisCount ?? this.cameraAnalysisCount,
      areaAnalysisCount: areaAnalysisCount ?? this.areaAnalysisCount,
      lastCameraAnalysisAt: lastCameraAnalysisAt ?? this.lastCameraAnalysisAt,
      lastAreaAnalysisAt: lastAreaAnalysisAt ?? this.lastAreaAnalysisAt,
    );
  }

  // === ユーティリティメソッド ===

  /// 表示名を取得（フォールバック付き）
  String get displayNameOrEmail {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    if (email != null && email!.isNotEmpty) {
      return email!;
    }
    return 'ユーザー';
  }

  /// v1.0: 機能別利用状況サマリー
  String get usageSummary {
    final total = cameraAnalysisCount + areaAnalysisCount;
    if (total == 0) {
      return '新規ユーザー';
    }

    return 'カメラ分析: ${cameraAnalysisCount}回、エリア分析: ${areaAnalysisCount}回';
  }

  /// v1.0: 最終活動からの経過日数
  int? get daysSinceLastActivity {
    DateTime? lastActivity;

    if (lastCameraAnalysisAt != null && lastAreaAnalysisAt != null) {
      lastActivity = lastCameraAnalysisAt!.isAfter(lastAreaAnalysisAt!)
          ? lastCameraAnalysisAt
          : lastAreaAnalysisAt;
    } else if (lastCameraAnalysisAt != null) {
      lastActivity = lastCameraAnalysisAt;
    } else if (lastAreaAnalysisAt != null) {
      lastActivity = lastAreaAnalysisAt;
    }

    if (lastActivity == null) return null;

    return DateTime.now().difference(lastActivity).inDays;
  }

  /// デバッグ用文字列
  String get debugInfo {
    return '''
UserModel Debug Info:
  ID: $id
  Email: $email
  Display Name: $displayName
  Created: $createdAt
  Updated: $updatedAt
  Audio Enabled: $audioEnabled
  Camera Analysis: $cameraAnalysisCount times
  Area Analysis: $areaAnalysisCount times
  Last Camera: $lastCameraAnalysisAt
  Last Area: $lastAreaAnalysisAt
  Usage Summary: $usageSummary
  Days Since Activity: ${daysSinceLastActivity ?? 'N/A'}
''';
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // === プライベートヘルパー ===

  /// Firestoreの日時フィールドをパース
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('日時パースエラー: $value');
        return null;
      }
    }

    return null;
  }
}
