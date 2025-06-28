// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../models/user_model.dart';
import '../models/user_preference_model.dart';

/// Maisoku AI v1.0: Firestore操作サービス
///
/// 機能：
/// - カメラ分析：揮発的表示（履歴保存なし）
/// - エリア分析：揮発的表示（履歴保存なし）
/// - ユーザー管理：認証・好み設定・音声設定
class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // === ユーザー管理機能 ===

  /// Firebase Authユーザーから UserModel を作成・更新
  Future<void> upsertUser(fb_auth.User firebaseUser) async {
    final userModel = UserModel.fromFirebaseAuth(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      photoURL: firebaseUser.photoURL,
    );

    try {
      await _db.collection('users').doc(firebaseUser.uid).set(
            userModel.toJson(),
            SetOptions(merge: true),
          );
      print('✅ ユーザーデータを保存: ${firebaseUser.uid}');
    } catch (e) {
      print('❌ ユーザーデータ保存エラー: $e');
      rethrow;
    }
  }

  /// ユーザー情報を取得
  Future<UserModel?> getUser(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final doc = await _db.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ ユーザー情報取得エラー: $e');
      return null;
    }
  }

  /// ユーザー情報を更新
  Future<void> updateUser(UserModel userModel) async {
    try {
      await _db.collection('users').doc(userModel.id).update(
            userModel.toJson(),
          );
      print('✅ ユーザー情報を更新: ${userModel.id}');
    } catch (e) {
      print('❌ ユーザー情報更新エラー: $e');
      rethrow;
    }
  }

  /// ユーザーが存在するかチェック
  Future<bool> userExists(String userId) async {
    if (userId.isEmpty) return false;

    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      print('❌ ユーザー存在チェックエラー: $e');
      return false;
    }
  }

  // === 音声設定管理 ===

  /// 音声設定を取得
  Future<bool> getUserAudioSetting(String userId) async {
    if (userId.isEmpty) return true;

    try {
      final doc = await _db.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return data['audioEnabled'] as bool? ?? true;
      }
      return true;
    } catch (e) {
      print('❌ 音声設定取得エラー: $e');
      return true;
    }
  }

  /// 音声設定を更新
  Future<void> updateUserAudioSetting(String userId, bool isEnabled) async {
    if (userId.isEmpty) return;

    try {
      await _db.collection('users').doc(userId).update({
        'audioEnabled': isEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ 音声設定を更新: $userId → $isEnabled');
    } catch (e) {
      print('❌ 音声設定更新エラー: $e');
      rethrow;
    }
  }

  // === ユーザー好み設定管理 ===

  /// ユーザー好み設定を取得
  Future<UserPreferenceModel?> getUserPreferences(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('current')
          .get();

      if (doc.exists && doc.data() != null) {
        return UserPreferenceModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ 好み設定取得エラー: $e');
      return null;
    }
  }

  /// ユーザー好み設定を保存
  Future<void> saveUserPreferences(
    String userId,
    UserPreferenceModel preferences,
  ) async {
    if (userId.isEmpty) {
      throw ArgumentError('ユーザーIDが空です');
    }

    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('current')
          .set(preferences.toJson(), SetOptions(merge: true));

      print('✅ 好み設定を保存: $userId');
    } catch (e) {
      print('❌ 好み設定保存エラー: $e');
      rethrow;
    }
  }

  /// ユーザー好み設定を削除
  Future<void> deleteUserPreferences(String userId) async {
    if (userId.isEmpty) return;

    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('current')
          .delete();

      print('✅ 好み設定を削除: $userId');
    } catch (e) {
      print('❌ 好み設定削除エラー: $e');
      rethrow;
    }
  }

  // === 統計・分析機能 ===

  /// ユーザーの利用統計を更新
  Future<void> incrementUserAnalysisCount(
    String userId,
    String analysisType, // 'camera' or 'area'
  ) async {
    if (userId.isEmpty) return;

    try {
      final fieldName = analysisType == 'camera'
          ? 'cameraAnalysisCount'
          : 'areaAnalysisCount';
      final lastFieldName = analysisType == 'camera'
          ? 'lastCameraAnalysisAt'
          : 'lastAreaAnalysisAt';

      await _db.collection('users').doc(userId).update({
        fieldName: FieldValue.increment(1),
        lastFieldName: FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ ${analysisType}分析回数を更新: $userId');
    } catch (e) {
      print('❌ 利用統計更新エラー: $e');
    }
  }

  // === 退会・アカウント管理 ===

  /// ユーザーを論理削除（退会処理）
  Future<void> withdrawUser(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('ユーザーIDが空です');
    }

    try {
      await _db.collection('users').doc(userId).update({
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ ユーザーを論理削除: $userId');
    } catch (e) {
      print('❌ 退会処理エラー: $e');
      rethrow;
    }
  }

  /// ユーザーが退会済みかチェック
  Future<bool> isUserWithdrawn(String userId) async {
    if (userId.isEmpty) return false;

    try {
      final doc = await _db.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return data['deletedAt'] != null;
      }
      return false;
    } catch (e) {
      print('❌ 退会状態チェックエラー: $e');
      return false;
    }
  }

  // === バッチ操作・クリーンアップ ===

  /// ユーザーの全データを削除（完全削除）
  Future<void> deleteUserCompletely(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('ユーザーIDが空です');
    }

    final batch = _db.batch();

    try {
      // 好み設定を削除
      final preferencesRef = _db
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('current');
      batch.delete(preferencesRef);

      // ユーザー本体を削除
      final userRef = _db.collection('users').doc(userId);
      batch.delete(userRef);

      await batch.commit();
      print('✅ ユーザーデータを完全削除: $userId');
    } catch (e) {
      print('❌ 完全削除エラー: $e');
      rethrow;
    }
  }

  // === デバッグ・開発用 ===

  /// Firestore接続状況をテスト
  Future<bool> testConnection() async {
    try {
      await _db.collection('_test').doc('connection').set({
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'connected',
      });

      await _db.collection('_test').doc('connection').delete();
      print('✅ Firestore接続テスト成功');
      return true;
    } catch (e) {
      print('❌ Firestore接続テストエラー: $e');
      return false;
    }
  }

  /// デバッグ情報を表示
  void printDebugInfo() {
    print('''
🔍 FirestoreService Debug Info:
  Database: ${_db.app.name}
  Available: ${_db.app.isAutomaticDataCollectionEnabled}
  Collections:
    - users/{userId}
    - users/{userId}/preferences/current
''');
  }
}
