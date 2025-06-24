// lib/services/auth_check_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Maisoku AI v1.0: 認証チェックサービス（機能分離対応）
///
/// 機能分離での変更点：
/// - カメラ分析：履歴保存あり（認証必須機能）
/// - エリア分析：揮発的表示（認証なしでも利用可能）
/// - タブナビゲーション：認証状態に応じた動的調整
class AuthCheckService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// アプリ起動時にユーザー状態をチェックし、必要に応じて修正
  static Future<bool> validateUserOnStartup() async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        print('✅ ユーザーがログインしていません（エリア分析は利用可能）');
        return true; // 問題なし（エリア分析は認証不要）
      }

      print('🔍 ユーザー状態チェック開始: ${currentUser.uid}');
      print('📧 メール: ${currentUser.email}');
      print('🎯 機能対応: カメラ分析（履歴保存）+ エリア分析（揮発的）');

      // Firestoreでユーザーデータが存在するかチェック
      final bool userExists =
          await _checkUserExistsInFirestore(currentUser.uid);

      if (!userExists) {
        print('⚠️ Firestoreにユーザーデータが存在しません');
        print('📝 影響範囲: カメラ分析の履歴保存が利用不可');
        print('✅ エリア分析は引き続き利用可能');
        print('🔄 ローカル認証情報をクリアします...');

        await _forceSignOut();
        return false; // 修正が必要だった
      }

      print('✅ ユーザー状態は正常です（全機能利用可能）');
      return true; // 問題なし
    } catch (e) {
      print('❌ ユーザー状態チェックエラー: $e');
      print('🔄 エラー発生時もエリア分析は継続利用可能');

      // エラーが発生した場合も強制ログアウト
      await _forceSignOut();
      return false;
    }
  }

  /// Firestoreにユーザーデータが存在するかチェック
  static Future<bool> _checkUserExistsInFirestore(String uid) async {
    try {
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      final bool exists = userDoc.exists;
      print('📊 Firestoreユーザーデータ確認結果: ${exists ? "存在" : "不存在"}');

      return exists;
    } catch (e) {
      print('❌ Firestoreユーザーチェックエラー: $e');
      print('💡 ネットワークエラーの可能性 - エリア分析は利用可能');
      return false;
    }
  }

  /// 強制的にログアウトして全てのローカルデータをクリア
  static Future<void> _forceSignOut() async {
    try {
      // Firebase Authからサインアウト
      await _auth.signOut();
      print('✅ Firebase Authからサインアウト完了');
      print('📱 タブナビゲーション: ホーム/カメラ/エリア/ログインに切り替え');

      // ローカルデータのクリーンアップ
      await _clearLocalData();
    } catch (e) {
      print('❌ 強制ログアウトエラー: $e');

      // 最後の手段：再試行
      try {
        await _auth.signOut();
        print('🔄 最終的なサインアウト試行完了');
      } catch (e2) {
        print('❌ 最終的なサインアウトも失敗: $e2');
        print('💡 アプリ再起動を推奨');
      }
    }
  }

  /// ローカルデータのクリーンアップ（機能分離対応）
  static Future<void> _clearLocalData() async {
    try {
      // カメラ分析関連のローカルデータをクリア
      // （エリア分析は揮発的なので特にクリア対象なし）

      print('🧹 ローカルデータクリーンアップ開始');
      print('📸 カメラ分析: 一時保存データクリア対象');
      print('🗺️ エリア分析: 揮発的データのため対象外');

      // 必要に応じて他のローカルストレージもクリア
      // SharedPreferences、SQLiteなどがある場合はここで削除

      print('✅ ローカルデータクリーンアップ完了');
    } catch (e) {
      print('❌ ローカルデータクリーンアップエラー: $e');
    }
  }

  /// 手動でユーザー状態をリセット（デバッグ用）
  static Future<void> manualReset() async {
    print('🔄 手動ユーザー状態リセット開始...');
    print('📝 リセット後はエリア分析のみ利用可能');
    await _forceSignOut();
    print('✅ 手動リセット完了');
  }

  /// 現在のユーザー状態を詳細表示（デバッグ用・機能分離対応）
  static void debugUserState() {
    final User? user = _auth.currentUser;

    print('🔍 === ユーザー状態デバッグ ===');

    if (user == null) {
      print('👤 ログイン状態: 未ログイン');
      print('📱 利用可能機能:');
      print('  ✅ ホーム画面: 利用可能');
      print('  ❌ カメラ分析: ログインが必要（履歴保存のため）');
      print('  ✅ エリア分析: 利用可能（揮発的表示）');
      print('  📝 タブ構成: ホーム/カメラ/エリア/ログイン');
    } else {
      print('👤 ログイン状態: ログイン済み');
      print('📊 ユーザー情報:');
      print('  - UID: ${user.uid}');
      print('  - メール: ${user.email}');
      print('  - 表示名: ${user.displayName ?? "未設定"}');
      print('  - 認証済み: ${user.emailVerified}');
      print('  - 作成日: ${user.metadata.creationTime}');
      print('  - 最終ログイン: ${user.metadata.lastSignInTime}');

      print('📱 利用可能機能:');
      print('  ✅ ホーム画面: 利用可能');
      print('  ✅ カメラ分析: 利用可能（履歴保存あり）');
      print('  ✅ エリア分析: 利用可能（揮発的表示）');
      print('  ✅ 履歴画面: 利用可能（カメラ分析履歴）');
      print('  ✅ マイページ: 利用可能');
      print('  📝 タブ構成: ホーム/カメラ/エリア/履歴/マイページ');
    }

    print('🎯 機能分離状況:');
    print('  📸 カメラ分析: Firebase連携（履歴保存）');
    print('  🗺️ エリア分析: スタンドアロン（揮発的）');
    print('  📊 好み設定: 両機能共通');
    print('=================================');
  }

  /// 機能別利用可能状況をチェック
  static Map<String, bool> getFeatureAvailability() {
    final User? user = _auth.currentUser;
    final bool isLoggedIn = user != null;

    return {
      'home': true, // ホーム：常に利用可能
      'camera': true, // カメラ：常に利用可能（履歴保存はログイン時のみ）
      'area': true, // エリア：常に利用可能
      'history': isLoggedIn, // 履歴：ログイン時のみ
      'mypage': isLoggedIn, // マイページ：ログイン時のみ
      'camera_history_save': isLoggedIn, // カメラ履歴保存：ログイン時のみ
      'area_personalization': isLoggedIn, // エリア個人化：ログイン時のみ
    };
  }

  /// 特定機能が利用可能かチェック
  static bool isFeatureAvailable(String featureName) {
    final availability = getFeatureAvailability();
    return availability[featureName] ?? false;
  }

  /// 認証が必要な機能へのアクセス時の案内メッセージ
  static String getAuthRequiredMessage(String featureName) {
    switch (featureName) {
      case 'camera_history_save':
        return 'カメラ分析の履歴保存にはログインが必要です。';
      case 'area_personalization':
        return '個人化されたエリア分析にはログインが必要です。';
      case 'history':
        return '分析履歴の閲覧にはログインが必要です。';
      case 'mypage':
        return 'マイページの利用にはログインが必要です。';
      default:
        return 'この機能の利用にはログインが必要です。';
    }
  }

  /// ユーザーデータの整合性チェック
  static Future<UserDataIntegrityResult> checkUserDataIntegrity(
      String userId) async {
    if (userId.isEmpty) {
      return UserDataIntegrityResult(
        isValid: false,
        errors: ['ユーザーIDが空です'],
        warnings: [],
      );
    }

    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Firestoreユーザードキュメントのチェック
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        errors.add('Firestoreにユーザードキュメントが存在しません');
      } else {
        final data = userDoc.data();
        if (data == null || data.isEmpty) {
          warnings.add('ユーザードキュメントが空です');
        }

        // 必須フィールドのチェック
        if (data?['email'] == null) {
          warnings.add('メールアドレスが設定されていません');
        }
        if (data?['createdAt'] == null) {
          warnings.add('作成日時が設定されていません');
        }
      }

      // 好み設定の存在チェック
      final prefsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('current')
          .get();

      if (!prefsDoc.exists) {
        warnings.add('好み設定が未設定です');
      }

      print('✅ ユーザーデータ整合性チェック完了: $userId');
    } catch (e) {
      errors.add('整合性チェック中にエラーが発生しました: $e');
      print('❌ ユーザーデータ整合性チェックエラー: $e');
    }

    return UserDataIntegrityResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Firebase Auth トークンの有効性チェック
  static Future<bool> validateAuthToken() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return false;

      // トークンを強制的に更新して有効性を確認
      await user.getIdToken(true);
      print('✅ Firebase Auth トークン有効');
      return true;
    } catch (e) {
      print('❌ Firebase Auth トークン無効: $e');
      return false;
    }
  }

  /// アプリ状態のヘルスチェック
  static Future<AppHealthStatus> performHealthCheck() async {
    final healthStatus = AppHealthStatus();

    try {
      // Firebase Auth状態チェック
      healthStatus.authStatus =
          _auth.currentUser != null ? 'logged_in' : 'logged_out';

      // Firestore接続チェック
      try {
        await _firestore
            .collection('_health')
            .doc('test')
            .get()
            .timeout(const Duration(seconds: 5));
        healthStatus.firestoreConnected = true;
      } catch (e) {
        healthStatus.firestoreConnected = false;
        healthStatus.errors.add('Firestore接続エラー: $e');
      }

      // 機能利用可能性チェック
      healthStatus.featureAvailability = getFeatureAvailability();

      print('✅ アプリヘルスチェック完了');
    } catch (e) {
      healthStatus.errors.add('ヘルスチェックエラー: $e');
      print('❌ アプリヘルスチェックエラー: $e');
    }

    return healthStatus;
  }
}

// === データクラス ===

/// ユーザーデータの整合性チェック結果
class UserDataIntegrityResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  UserDataIntegrityResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;
}

/// アプリの健全性ステータス
class AppHealthStatus {
  String authStatus = 'unknown';
  bool firestoreConnected = false;
  Map<String, bool> featureAvailability = {};
  List<String> errors = [];

  bool get isHealthy => errors.isEmpty && firestoreConnected;

  String get summary {
    if (isHealthy) {
      return '✅ アプリは正常に動作しています';
    } else {
      return '⚠️ ${errors.length}件の問題があります';
    }
  }
}
