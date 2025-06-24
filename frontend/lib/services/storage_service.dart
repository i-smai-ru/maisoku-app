// lib/services/storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

/// Maisoku AI v1.0: Firebase Storage画像管理サービス
///
/// 機能分離対応：
/// - カメラ分析：画像アップロード・履歴保存
/// - エリア分析：画像保存なし（API直接送信）
/// - 画像最適化・セキュリティ対応
class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  // === 画像アップロード機能 ===

  /// カメラ分析画像をアップロード
  Future<String> uploadAnalysisImage(
    File imageFile,
    String userId, {
    bool isPersonalized = false,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError('ユーザーIDが空です');
    }

    if (!await imageFile.exists()) {
      throw ArgumentError('画像ファイルが存在しません');
    }

    try {
      // ファイル検証
      _validateImageFile(imageFile);

      // ファイル名生成
      final fileName = _generateFileName(imageFile, isPersonalized);

      // アップロードパス
      final path = 'users/$userId/analysis_images/$fileName';
      final ref = _storage.ref(path);

      print('📤 画像アップロード開始: $path');

      // メタデータ設定
      final metadata = SettableMetadata(
        contentType: _getContentType(imageFile),
        customMetadata: {
          'userId': userId,
          'uploadType': 'camera_analysis',
          'isPersonalized': isPersonalized.toString(),
          'appVersion': '1.0',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // アップロード実行
      final uploadTask = ref.putFile(imageFile, metadata);
      final snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();
        print('✅ 画像アップロード成功: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('アップロードが失敗しました: ${snapshot.state}');
      }
    } catch (e) {
      print('❌ 画像アップロードエラー: $e');
      if (e is FirebaseException) {
        throw _handleFirebaseStorageError(e);
      }
      rethrow;
    }
  }

  /// バイト配列から画像をアップロード（Cloud Run API用）
  Future<String> uploadImageFromBytes(
    Uint8List imageBytes,
    String userId,
    String fileName, {
    bool isPersonalized = false,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError('ユーザーIDが空です');
    }

    try {
      // ファイル名を安全化
      final safeFileName = _sanitizeFileName(fileName);
      final path = 'users/$userId/analysis_images/$safeFileName';
      final ref = _storage.ref(path);

      print('📤 バイト配列アップロード開始: $path');

      // メタデータ設定
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'uploadType': 'camera_analysis',
          'isPersonalized': isPersonalized.toString(),
          'appVersion': '1.0',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // アップロード実行
      final uploadTask = ref.putData(imageBytes, metadata);
      final snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();
        print('✅ バイト配列アップロード成功: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('アップロードが失敗しました: ${snapshot.state}');
      }
    } catch (e) {
      print('❌ バイト配列アップロードエラー: $e');
      if (e is FirebaseException) {
        throw _handleFirebaseStorageError(e);
      }
      rethrow;
    }
  }

  // === 画像削除・管理機能 ===

  /// 分析画像を削除
  Future<void> deleteAnalysisImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;

    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ 画像を削除: ${ref.fullPath}');
    } catch (e) {
      print('❌ 画像削除エラー: $e');
      if (e is FirebaseException && e.code == 'object-not-found') {
        print('⚠️ 画像が既に削除されています');
        return; // エラーにしない
      }
      rethrow;
    }
  }

  /// ユーザーの全画像を削除
  Future<void> deleteAllUserImages(String userId) async {
    if (userId.isEmpty) return;

    try {
      final userRef = _storage.ref('users/$userId/analysis_images');
      final listResult = await userRef.listAll();

      final deleteOperations = listResult.items.map((ref) => ref.delete());
      await Future.wait(deleteOperations);

      print('✅ ユーザーの全画像を削除: $userId (${listResult.items.length}件)');
    } catch (e) {
      print('❌ 全画像削除エラー: $e');
      rethrow;
    }
  }

  /// ユーザーの画像一覧を取得
  Future<List<Reference>> getUserImages(String userId) async {
    if (userId.isEmpty) return [];

    try {
      final userRef = _storage.ref('users/$userId/analysis_images');
      final listResult = await userRef.listAll();
      return listResult.items;
    } catch (e) {
      print('❌ 画像一覧取得エラー: $e');
      return [];
    }
  }

  /// ストレージ使用量を取得
  Future<int> getUserStorageSize(String userId) async {
    if (userId.isEmpty) return 0;

    try {
      final images = await getUserImages(userId);
      int totalSize = 0;

      for (final image in images) {
        final metadata = await image.getMetadata();
        totalSize += metadata.size ?? 0;
      }

      return totalSize;
    } catch (e) {
      print('❌ ストレージ使用量取得エラー: $e');
      return 0;
    }
  }

  // === 画像ダウンロード・取得機能 ===

  /// 画像URLから画像データを取得
  Future<Uint8List?> downloadImageBytes(String imageUrl) async {
    if (imageUrl.isEmpty) return null;

    try {
      final ref = _storage.refFromURL(imageUrl);
      const maxSize = 10 * 1024 * 1024; // 10MB制限
      final bytes = await ref.getData(maxSize);
      print('✅ 画像ダウンロード成功: ${bytes?.length ?? 0} bytes');
      return bytes;
    } catch (e) {
      print('❌ 画像ダウンロードエラー: $e');
      return null;
    }
  }

  /// 画像メタデータを取得
  Future<FullMetadata?> getImageMetadata(String imageUrl) async {
    if (imageUrl.isEmpty) return null;

    try {
      final ref = _storage.refFromURL(imageUrl);
      return await ref.getMetadata();
    } catch (e) {
      print('❌ 画像メタデータ取得エラー: $e');
      return null;
    }
  }

  // === プライベートヘルパーメソッド ===

  /// ファイル名を生成
  String _generateFileName(File imageFile, bool isPersonalized) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(imageFile.path).toLowerCase();
    final prefix = isPersonalized ? 'personalized' : 'basic';
    return '${prefix}_analysis_${timestamp}${extension}';
  }

  /// ファイル名を安全化
  String _sanitizeFileName(String fileName) {
    // 危険な文字を除去
    String safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    // 拡張子がない場合は追加
    if (!safe.contains('.')) {
      safe += '.jpg';
    }

    return safe;
  }

  /// ファイルの検証
  void _validateImageFile(File imageFile) {
    final extension = p.extension(imageFile.path).toLowerCase();
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

    if (!allowedExtensions.contains(extension)) {
      throw ArgumentError('サポートされていない画像形式です: $extension');
    }

    final fileSize = imageFile.lengthSync();
    const maxSize = 10 * 1024 * 1024; // 10MB

    if (fileSize > maxSize) {
      throw ArgumentError('画像ファイルが大きすぎます: ${fileSize} bytes');
    }

    if (fileSize == 0) {
      throw ArgumentError('画像ファイルが空です');
    }
  }

  /// Content-Typeを取得
  String _getContentType(File imageFile) {
    final extension = p.extension(imageFile.path).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // デフォルト
    }
  }

  /// Firebase Storageエラーを処理
  Exception _handleFirebaseStorageError(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
        return Exception('画像アップロードの権限がありません');
      case 'quota-exceeded':
        return Exception('ストレージ容量が上限に達しています');
      case 'unauthenticated':
        return Exception('認証が必要です');
      case 'retry-limit-exceeded':
        return Exception('アップロードがタイムアウトしました');
      case 'invalid-checksum':
        return Exception('ファイルが破損している可能性があります');
      default:
        return Exception('画像アップロードに失敗しました: ${e.message}');
    }
  }

  // === デバッグ・テスト用機能 ===

  /// Storage接続テスト
  Future<bool> testConnection() async {
    try {
      final testRef = _storage.ref('_test/connection_test.txt');
      final testData = Uint8List.fromList('test'.codeUnits);

      await testRef.putData(testData);
      await testRef.delete();

      print('✅ Firebase Storage接続テスト成功');
      return true;
    } catch (e) {
      print('❌ Firebase Storage接続テストエラー: $e');
      return false;
    }
  }

  /// デバッグ情報を表示
  void printDebugInfo() {
    print('''
🔍 StorageService Debug Info:
  Storage Bucket: ${_storage.bucket}
  Max Upload Size: 10MB
  Allowed Formats: jpg, jpeg, png, webp
  Path Structure: users/{userId}/analysis_images/{filename}
  Version: 1.0
''');
  }

  /// ストレージルールテスト用
  Future<void> testStorageRules(String userId) async {
    try {
      // テスト画像作成
      final testData = Uint8List.fromList('test_image_data'.codeUnits);

      // 正常なパスでテスト
      final validRef = _storage.ref('users/$userId/analysis_images/test.jpg');
      await validRef.putData(testData);
      await validRef.delete();
      print('✅ 正常パスでのアップロード成功');

      // 不正なパスでテスト（失敗するはず）
      try {
        final invalidRef =
            _storage.ref('users/other_user/analysis_images/test.jpg');
        await invalidRef.putData(testData);
        print('⚠️ 不正パスでのアップロードが成功（ルール要確認）');
      } catch (e) {
        print('✅ 不正パスでのアップロードを正常に拒否');
      }
    } catch (e) {
      print('❌ ストレージルールテストエラー: $e');
    }
  }
}
