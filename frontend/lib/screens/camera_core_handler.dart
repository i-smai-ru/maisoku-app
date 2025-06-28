// lib/screens/camera_core_handler.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

// Services
import '../services/api_service.dart';
import '../services/user_preference_service.dart';
import '../services/firestore_service.dart';

// Models
import '../models/analysis_response_model.dart';
import '../models/user_preference_model.dart';

// Utils
import '../utils/api_error_handler.dart';
import '../utils/constants.dart';

// Config
import '../config/api_config.dart';

// === 🔧 開発モード設定 ===
const bool kDebugMode = false; // 本番環境では false に設定

enum CameraAnalysisState {
  authCheck,
  loginRequired,
  initial,
  photoChoice,
  capturing,
  analyzing,
  results,
}

typedef StateChangeCallback = void Function(CameraAnalysisState state);
typedef ErrorCallback = void Function(String error, {String? debugInfo});
typedef SuccessCallback = void Function(String message);

/// 撮影・画像処理・API通信を統合したコア機能クラス（履歴機能削除版）
/// デバッグ情報は開発モード時のみ表示
class CameraCoreHandler {
  // === コールバック ===
  final StateChangeCallback onStateChanged;
  final ErrorCallback onError;
  final SuccessCallback onSuccess;

  // === Services ===
  final FirestoreService _firestoreService = FirestoreService();
  late final UserPreferenceService _userPreferenceService;
  final ImagePicker _picker = ImagePicker();

  // === 状態管理 ===
  User? _currentUser;
  CameraAnalysisState _currentState = CameraAnalysisState.authCheck;

  // === カメラ関連 ===
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRearCameraSelected = true;
  bool _cameraInitializationFailed = false;

  // === データ ===
  File? _selectedImage;
  CameraAnalysisResponse? _analysisResult;
  UserPreferenceModel? _userPreferences;

  // === フラグ ===
  bool _isAnalyzing = false;
  bool _isInitializing = true;
  bool _isProcessingImage = false;

  // === 🔍 デバッグシステム（開発モード時のみ） ===
  final Map<String, dynamic> _debugInfo = {};
  String _lastOperation = '';
  DateTime _operationStartTime = DateTime.now();

  // === 設定 ===
  static const int _maxFileSize = 2 * 1024 * 1024; // 2MB
  static const int _defaultQuality = 85;
  static const int _recompressQuality = 60;

  CameraCoreHandler({
    required this.onStateChanged,
    required this.onError,
    required this.onSuccess,
  }) {
    _userPreferenceService =
        UserPreferenceService(firestoreService: _firestoreService);
    _setupAuthListener();
  }

  // === Getters ===
  User? get currentUser => _currentUser;
  CameraAnalysisState get currentState => _currentState;
  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get cameraInitializationFailed => _cameraInitializationFailed;
  File? get selectedImage => _selectedImage;
  CameraAnalysisResponse? get analysisResult => _analysisResult;
  bool get isAnalyzing => _isAnalyzing;
  bool get isInitializing => _isInitializing;
  bool get isProcessingImage => _isProcessingImage;

  // デバッグ情報は開発モード時のみ公開
  Map<String, dynamic> get debugInfo => kDebugMode ? Map.from(_debugInfo) : {};

  // === 🔐 認証・初期化処理 ===

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (kDebugMode) {
        print('🔐 [CoreHandler] 認証状態変更: ${user?.uid ?? "ログアウト"}');
      }
      _currentUser = user;
      _handleAuthStateChange(user);
    });
  }

  void _handleAuthStateChange(User? user) {
    if (user == null) {
      if (kDebugMode) print('📤 [CoreHandler] ログアウト検出');
      _changeState(CameraAnalysisState.loginRequired);
      _resetAllData();
    } else {
      if (kDebugMode) print('📥 [CoreHandler] ログイン検出');
      _safeInitialize();
    }
  }

  Future<void> performAuthCheck() async {
    if (kDebugMode) print('🔒 [CoreHandler] 初回認証チェック開始');
    _startOperation('auth_check');

    _changeState(CameraAnalysisState.authCheck);
    await Future.delayed(const Duration(milliseconds: 500));

    final User? user = FirebaseAuth.instance.currentUser;
    _currentUser = user;

    if (user != null) {
      if (kDebugMode) {
        print('✅ [CoreHandler] 認証済み: ${user.email ?? "メールアドレス不明"}');
      }
      _updateDebugInfo('auth_status', 'authenticated');
      _updateDebugInfo('user_email', user.email ?? 'unknown');
      _safeInitialize();
    } else {
      if (kDebugMode) print('🔐 [CoreHandler] 未認証');
      _updateDebugInfo('auth_status', 'unauthenticated');
      _changeState(CameraAnalysisState.loginRequired);
    }

    _endOperation('auth_check');
  }

  Future<void> _safeInitialize() async {
    if (kDebugMode) print('📱 [CoreHandler] 安全な初期化開始');
    _startOperation('safe_initialize');

    try {
      _isInitializing = true;
      _changeState(CameraAnalysisState.initial);

      // UserPreferences読み込み
      await _loadUserPreferences();

      // カメラ一覧取得
      await _getCameraList();

      _isInitializing = false;
      _updateDebugInfo('initialization_success', true);
      if (kDebugMode) print('✅ [CoreHandler] 初期化完了');
    } catch (e) {
      _isInitializing = false;
      _updateDebugInfo('initialization_error', e.toString());
      _handleErrorWithDebug('初期化エラー', e, 'initialization');
    }

    _endOperation('safe_initialize');
  }

  Future<void> _loadUserPreferences() async {
    if (_currentUser == null) return;

    try {
      if (kDebugMode) print('⚙️ [CoreHandler] UserPreferences読み込み開始');

      final prefs = await _userPreferenceService.getPreferences().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) print('⏰ UserPreferences読み込みタイムアウト');
          return null;
        },
      );

      _userPreferences = prefs;
      _updateDebugInfo('has_preferences', prefs != null);
      if (prefs != null && kDebugMode) {
        _updateDebugInfo('preferences_count', prefs.toJson().length);
      }

      if (kDebugMode) {
        print(
            '✅ [CoreHandler] UserPreferences読み込み完了: ${prefs != null ? "あり" : "なし"}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ [CoreHandler] UserPreferences読み込みエラー: $e');
      _updateDebugInfo('preferences_error', e.toString());
    }
  }

  Future<void> _getCameraList() async {
    try {
      if (kDebugMode) print('📷 [CoreHandler] カメラ一覧取得開始');

      _cameras = await availableCameras().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) print('⏰ カメラ一覧取得タイムアウト');
          throw Exception('カメラ一覧取得がタイムアウトしました');
        },
      );

      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('利用可能なカメラが見つかりません');
      }

      _updateDebugInfo('cameras_count', _cameras!.length);
      if (kDebugMode) print('✅ [CoreHandler] カメラ一覧取得完了: ${_cameras!.length}台');
    } catch (e) {
      if (kDebugMode) print('❌ [CoreHandler] カメラ一覧取得エラー: $e');
      _cameraInitializationFailed = true;
      _updateDebugInfo('camera_list_error', e.toString());
      rethrow;
    }
  }

  // === 📷 カメラ操作 ===

  Future<bool> initializeCameraLazy() async {
    if (_cameraInitializationFailed || _cameras == null || _cameras!.isEmpty) {
      return false;
    }

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return true;
    }

    try {
      if (kDebugMode) print('📷 [CoreHandler] 遅延カメラ初期化開始');
      _startOperation('camera_initialize');

      final camera = _isRearCameraSelected ? _cameras!.first : _cameras!.last;
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('カメラ初期化がタイムアウトしました');
        },
      );

      _isCameraInitialized = true;
      _cameraInitializationFailed = false;
      _updateDebugInfo('camera_initialized', true);
      if (kDebugMode) {
        _updateDebugInfo('camera_resolution',
            _cameraController!.value.previewSize.toString());
        print('✅ [CoreHandler] カメラ初期化完了');
      }
      _endOperation('camera_initialize');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [CoreHandler] カメラ初期化エラー: $e');
      _isCameraInitialized = false;
      _cameraInitializationFailed = true;
      _updateDebugInfo('camera_init_error', e.toString());
      _endOperation('camera_initialize');
      return false;
    }
  }

  Future<void> takePicture() async {
    if (_currentUser == null) {
      onError('写真撮影にはログインが必要です');
      return;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      onError('カメラが初期化されていません');
      return;
    }

    try {
      if (kDebugMode) print('📸 [CoreHandler] 写真撮影開始');
      _startOperation('take_picture');
      _changeState(CameraAnalysisState.capturing);

      final XFile photo = await _cameraController!.takePicture();
      final File originalFile = File(photo.path);

      _updateDebugInfo('capture_success', true);
      _updateDebugInfo('original_file_path', originalFile.path);

      // 画像処理・分析へ
      await _processAndAnalyze(originalFile);

      _endOperation('take_picture');
    } catch (e) {
      _changeState(CameraAnalysisState.photoChoice);
      _handleErrorWithDebug('撮影に失敗しました', e, 'camera_capture');
      _endOperation('take_picture');
    }
  }

  Future<void> pickImageFromGallery() async {
    if (_currentUser == null) {
      onError('ギャラリー選択にはログインが必要です');
      return;
    }

    try {
      if (kDebugMode) print('🖼️ [CoreHandler] ギャラリー選択開始');
      _startOperation('pick_gallery');

      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);

      if (photo != null) {
        final File originalFile = File(photo.path);
        _updateDebugInfo('gallery_selection_success', true);
        _updateDebugInfo('selected_file_path', originalFile.path);

        // 画像処理・分析へ
        await _processAndAnalyze(originalFile);
      }

      _endOperation('pick_gallery');
    } catch (e) {
      _handleErrorWithDebug('画像選択に失敗しました', e, 'gallery_selection');
      _endOperation('pick_gallery');
    }
  }

  void switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;

    _isRearCameraSelected = !_isRearCameraSelected;
    _isCameraInitialized = false;
    _updateDebugInfo(
        'camera_switched', _isRearCameraSelected ? 'rear' : 'front');

    initializeCameraLazy();
  }

  // === 🖼️ 画像処理 ===

  Future<void> _processAndAnalyze(File originalFile) async {
    try {
      if (kDebugMode) print('🖼️ [CoreHandler] 画像処理・分析開始');
      _startOperation('process_and_analyze');

      // 画像処理
      final processedFile = await _processImageWithDebug(originalFile);
      if (processedFile == null) {
        throw Exception('画像処理に失敗しました');
      }

      _selectedImage = processedFile;

      // API分析
      await _analyzeWithDebug(processedFile);

      _endOperation('process_and_analyze');
    } catch (e) {
      _changeState(CameraAnalysisState.photoChoice);
      _handleErrorWithDebug('画像処理・分析エラー', e, 'process_analyze');
      _endOperation('process_and_analyze');
    }
  }

  Future<File?> _processImageWithDebug(File originalFile) async {
    try {
      if (kDebugMode) print('🖼️ [CoreHandler] 画像処理開始: ${originalFile.path}');
      _isProcessingImage = true;

      // デバッグ情報（開発モード時のみ）
      if (kDebugMode) {
        _updateDebugInfo(
            'image_processing_start', DateTime.now().toIso8601String());
        _updateDebugInfo('original_path', originalFile.path);
        final originalSize = await originalFile.length();
        _updateDebugInfo('original_size', originalSize);
        _updateDebugInfo(
            'original_size_kb', (originalSize / 1024).toStringAsFixed(2));
      }

      // ファイル検証
      await _validateImageFile(originalFile);

      // 一時ディレクトリ取得
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${tempDir.path}/processed_$timestamp.jpg';

      if (kDebugMode) _updateDebugInfo('target_path', targetPath);

      // 画像圧縮（HEIF→JPEG統一変換）
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        quality: _defaultQuality,
        minWidth: 300,
        minHeight: 300,
        rotate: 0,
        keepExif: false,
      );

      if (compressedFile != null) {
        final file = File(compressedFile.path);
        final fileSize = await file.length();

        if (kDebugMode) {
          _updateDebugInfo('compressed_size', fileSize);
          _updateDebugInfo(
              'compressed_size_kb', (fileSize / 1024).toStringAsFixed(2));
          _updateDebugInfo(
              'compression_ratio',
              _calculateCompressionRatio(
                await originalFile.length(),
                fileSize,
              ));
        }

        // サイズチェック・再圧縮
        final finalFile = await _handleFileSizeOptimization(
          file,
          fileSize,
          tempDir.path,
          timestamp,
        );

        if (kDebugMode) {
          _updateDebugInfo(
              'image_processing_end', DateTime.now().toIso8601String());
          _updateDebugInfo('final_size_kb',
              (await finalFile.length() / 1024).toStringAsFixed(2));
        }
        _isProcessingImage = false;

        if (kDebugMode) print('✅ [CoreHandler] 画像処理完了: ${finalFile.path}');
        return finalFile;
      } else {
        throw Exception('画像の圧縮に失敗しました');
      }
    } catch (e) {
      _isProcessingImage = false;
      _updateDebugInfo('image_processing_error', e.toString());
      if (kDebugMode) print('❌ [CoreHandler] 画像処理エラー: $e');
      rethrow;
    }
  }

  Future<void> _validateImageFile(File imageFile) async {
    if (!await imageFile.exists()) {
      throw Exception('画像ファイルが存在しません');
    }

    final fileSize = await imageFile.length();
    if (fileSize == 0) {
      throw Exception('画像ファイルが空です');
    }

    if (fileSize > 5 * 1024 * 1024) {
      // 5MB制限
      throw Exception(
          '画像ファイルが大きすぎます: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
    }

    final extension = imageFile.path.toLowerCase().split('.').last;
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'];

    if (!allowedExtensions.contains(extension)) {
      throw Exception('サポートされていない画像形式です: $extension');
    }

    _updateDebugInfo('file_validation', 'passed');
    _updateDebugInfo('file_extension', extension);
  }

  Future<File> _handleFileSizeOptimization(
    File compressedFile,
    int fileSize,
    String tempDirPath,
    int timestamp,
  ) async {
    if (fileSize > _maxFileSize) {
      if (kDebugMode) {
        print('📏 [CoreHandler] ファイルサイズが大きいため再圧縮: ${fileSize / 1024 / 1024}MB');
      }
      _updateDebugInfo('needs_recompression', true);

      final recompressedFile = await FlutterImageCompress.compressAndGetFile(
        compressedFile.path,
        '$tempDirPath/recompressed_$timestamp.jpg',
        quality: _recompressQuality,
        minWidth: 300,
        minHeight: 300,
        rotate: 0,
        keepExif: false,
      );

      if (recompressedFile != null) {
        final finalSize = await File(recompressedFile.path).length();
        if (kDebugMode) {
          _updateDebugInfo('final_size', finalSize);
          _updateDebugInfo(
              'final_compression_ratio',
              _calculateCompressionRatio(
                _debugInfo['original_size'] ?? 0,
                finalSize,
              ));
          print('✅ [CoreHandler] 再圧縮完了: ${recompressedFile.path}');
        }
        return File(recompressedFile.path);
      }
    }

    _updateDebugInfo('needs_recompression', false);
    _updateDebugInfo('final_size', fileSize);
    return compressedFile;
  }

  String _calculateCompressionRatio(int originalSize, int compressedSize) {
    if (originalSize == 0) return '0.00';
    final ratio = ((originalSize - compressedSize) / originalSize * 100);
    return ratio.toStringAsFixed(2);
  }

  // === 🤖 API分析 ===

  Future<void> _analyzeWithDebug(File imageFile) async {
    if (_currentUser == null) {
      onError('画像分析にはログインが必要です');
      return;
    }

    try {
      if (kDebugMode) print('🤖 [CoreHandler] API分析開始');
      _startOperation('api_analyze');

      _isAnalyzing = true;
      _changeState(CameraAnalysisState.analyzing);

      // 送信前デバッグ情報（開発モード時のみ）
      if (kDebugMode) await _logPreAnalysisDebugInfo(imageFile);

      final result = await ApiService.analyzeCameraImage(
        imageFile: imageFile,
        preferences: _userPreferences?.toJson(),
      );

      if (result != null) {
        final analysisResponse = CameraAnalysisResponse.fromJson(result);
        _analysisResult = analysisResponse;
        _isAnalyzing = false;
        _updateDebugInfo('analysis_success', true);

        if (kDebugMode) {
          _updateDebugInfo('analysis_length', analysisResponse.analysis.length);
          _updateDebugInfo('processing_time', analysisResponse.processingTime);
        }

        _changeState(CameraAnalysisState.results);

        if (kDebugMode) {
          print('✅ [CoreHandler] 分析成功: ${analysisResponse.analysis.length}文字');
        }
        onSuccess('分析が完了しました');
      } else {
        throw Exception('分析結果が取得できませんでした');
      }

      _endOperation('api_analyze');
    } catch (e) {
      _isAnalyzing = false;
      _updateDebugInfo('analysis_error', e.toString());

      // エラーハンドリング（簡略化 - 開発者向け詳細情報は非表示）
      if (e.toString().contains('422') ||
          e.toString().contains('Unprocessable Entity')) {
        // 422エラーの場合は分かりやすいメッセージに変換
        onError('画像の処理に問題が発生しました。別の画像をお試しください。');
      } else {
        _handleErrorWithDebug('分析エラー', e, 'api_analysis');
      }

      _endOperation('api_analyze');
    }
  }

  Future<void> _logPreAnalysisDebugInfo(File imageFile) async {
    if (!kDebugMode) return;

    try {
      final fileSize = await imageFile.length();

      _updateDebugInfo(
          'pre_analysis_timestamp', DateTime.now().toIso8601String());
      _updateDebugInfo('analysis_file_path', imageFile.path);
      _updateDebugInfo('analysis_file_size', fileSize);
      _updateDebugInfo(
          'analysis_file_size_kb', (fileSize / 1024).toStringAsFixed(2));
      _updateDebugInfo('user_id', _currentUser!.uid);
      _updateDebugInfo('user_email', _currentUser!.email ?? 'unknown');
      _updateDebugInfo('has_preferences', _userPreferences != null);

      if (_userPreferences != null) {
        _updateDebugInfo('preferences_data', _userPreferences!.toJson());
      }

      print('📊 [CoreHandler] 送信前デバッグ情報記録完了');
    } catch (e) {
      print('❌ [CoreHandler] 送信前デバッグ情報記録エラー: $e');
    }
  }

  // === 履歴保存機能（削除済み）===
  // 履歴機能は完全に削除されています

  // === 🔄 状態管理 ===

  void _changeState(CameraAnalysisState newState) {
    _currentState = newState;
    onStateChanged(newState);
  }

  void _resetAllData() {
    _selectedImage = null;
    _analysisResult = null;
    _isAnalyzing = false;
    _userPreferences = null;
    _isProcessingImage = false;
    if (kDebugMode) _debugInfo.clear();
  }

  void resetAnalysis() {
    if (_currentUser == null) {
      _changeState(CameraAnalysisState.loginRequired);
    } else {
      _changeState(CameraAnalysisState.initial);
      _selectedImage = null;
      _analysisResult = null;
      _isAnalyzing = false;
      _isProcessingImage = false;
    }
  }

  // === 🔍 デバッグ支援（開発モード時のみ） ===

  void _startOperation(String operation) {
    _lastOperation = operation;
    _operationStartTime = DateTime.now();
    if (kDebugMode) {
      _updateDebugInfo('current_operation', operation);
      _updateDebugInfo(
          'operation_start', _operationStartTime.toIso8601String());
    }
  }

  void _endOperation(String operation) {
    if (kDebugMode) {
      final duration = DateTime.now().difference(_operationStartTime);
      _updateDebugInfo('${operation}_duration_ms', duration.inMilliseconds);
      _updateDebugInfo('last_completed_operation', operation);
      _updateDebugInfo('last_operation_end', DateTime.now().toIso8601String());
    }
  }

  void _updateDebugInfo(String key, dynamic value) {
    if (kDebugMode) {
      _debugInfo[key] = value;
    }
  }

  void _handleErrorWithDebug(String message, dynamic error, String category) {
    if (kDebugMode) {
      _updateDebugInfo('error_category', category);
      _updateDebugInfo('error_message', error.toString());
      _updateDebugInfo('error_timestamp', DateTime.now().toIso8601String());
      _updateDebugInfo('error_operation', _lastOperation);

      print('❌ [CoreHandler][$category] エラー発生');
      print('詳細: $error');
      print('操作: $_lastOperation');

      // 開発モードでは詳細なデバッグ情報も送信
      final debugReport = _generateDebugReport();
      onError(message, debugInfo: debugReport);
    } else {
      // 本番モードでは簡潔なエラーメッセージのみ
      onError(message);
    }
  }

  String _generateDebugReport() {
    if (!kDebugMode) return '';

    final buffer = StringBuffer();

    buffer.writeln('=== CameraCoreHandler デバッグレポート ===');
    buffer.writeln('生成時刻: ${DateTime.now().toIso8601String()}');
    buffer.writeln('現在の操作: $_lastOperation');
    buffer.writeln('現在の状態: $_currentState');
    buffer.writeln('');

    // 基本状態
    buffer.writeln('🔧 基本状態:');
    buffer.writeln('  認証済み: ${_currentUser != null}');
    buffer.writeln('  カメラ初期化: $_isCameraInitialized');
    buffer.writeln('  分析中: $_isAnalyzing');
    buffer.writeln('  画像処理中: $_isProcessingImage');
    buffer.writeln('');

    // 詳細デバッグ情報
    buffer.writeln('🔍 詳細デバッグ情報:');
    _debugInfo.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });

    return buffer.toString();
  }

  // === ライフサイクル ===

  void handleLifecycleChange(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_currentUser != null) {
        initializeCameraLazy();
      }
    }
  }

  void dispose() {
    _cameraController?.dispose();
    if (kDebugMode) {
      _debugInfo.clear();
      print('📱 [CoreHandler] disposed');
    }
  }
}
