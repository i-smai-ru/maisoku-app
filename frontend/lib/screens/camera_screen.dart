// lib/screens/camera_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

// Services
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../services/user_preference_service.dart';
import '../services/storage_service.dart';

// Models
import '../models/analysis_response_model.dart';
import '../models/user_preference_model.dart';
import '../models/analysis_history_entry.dart';

// Utils
import '../utils/constants.dart';
import '../utils/api_error_handler.dart';

// Config
import '../config/api_config.dart';

enum CameraAnalysisState {
  initial,
  photoChoice,
  capturing,
  analyzing,
  results,
}

class CameraScreen extends StatefulWidget {
  final String? initialImageUrl;

  const CameraScreen({
    Key? key,
    this.initialImageUrl,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // === Camera関連 ===
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRearCameraSelected = true;
  bool _cameraInitializationFailed = false;

  // === 状態管理 ===
  CameraAnalysisState _currentState = CameraAnalysisState.initial;

  // === データ ===
  File? _selectedImage;
  CameraAnalysisResponse? _analysisResult;
  UserPreferenceModel? _userPreferences;

  // === フラグ ===
  bool _isAnalyzing = false;
  bool _isSaving = false;
  bool _isSaved = false;
  bool _isInitializing = true;
  String _initializationError = '';

  // === Services ===
  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  late final UserPreferenceService _userPreferenceService;

  @override
  void initState() {
    super.initState();
    print('📱 CameraScreen: initState開始');

    WidgetsBinding.instance.addObserver(this);
    _userPreferenceService =
        UserPreferenceService(firestoreService: _firestoreService);

    // 安全な非同期初期化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeInitialize();
    });
  }

  @override
  void dispose() {
    print('📱 CameraScreen: dispose開始');
    _cameraController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraLazy();
    }
  }

  // === 安全な初期化処理 ===

  /// 安全な初期化（カメラ初期化を遅延）
  Future<void> _safeInitialize() async {
    print('📱 CameraScreen: _safeInitialize開始');

    try {
      setState(() {
        _isInitializing = true;
        _initializationError = '';
      });

      // 段階1: 基本サービス初期化
      print('📱 段階1: 基本サービス初期化');
      await Future.delayed(const Duration(milliseconds: 100));

      // 段階2: UserPreferences読み込み（タイムアウト付き）
      print('📱 段階2: UserPreferences読み込み');
      await _loadUserPreferencesWithTimeout();

      // 段階3: カメラ一覧取得のみ（初期化は遅延）
      print('📱 段階3: カメラ一覧取得');
      await _getCameraListOnly();

      // 段階4: 履歴からの画像処理
      if (widget.initialImageUrl != null) {
        print('📱 段階4: 履歴画像処理');
        await _loadImageFromUrl(widget.initialImageUrl!);
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        print('📱 CameraScreen: 基本初期化完了（カメラ初期化は遅延）');
      }
    } catch (e) {
      print('❌ CameraScreen: 初期化エラー: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initializationError = '初期化エラー: $e';
        });
      }
    }
  }

  /// カメラ一覧のみ取得（CameraController初期化なし）
  Future<void> _getCameraListOnly() async {
    try {
      print('📷 カメラ一覧取得開始...');

      _cameras = await availableCameras().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ カメラ一覧取得タイムアウト');
          throw Exception('カメラ一覧取得がタイムアウトしました');
        },
      );

      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('利用可能なカメラが見つかりません');
      }

      print('✅ カメラ一覧取得完了: ${_cameras!.length}台');
    } catch (e) {
      print('❌ カメラ一覧取得エラー: $e');
      setState(() {
        _cameraInitializationFailed = true;
      });
      _showErrorSnackBar('カメラの確認に失敗しました: $e');
    }
  }

  /// 遅延カメラ初期化（実際に撮影画面に移る時のみ）
  Future<bool> _initializeCameraLazy() async {
    if (_cameraInitializationFailed || _cameras == null || _cameras!.isEmpty) {
      return false;
    }

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return true; // 既に初期化済み
    }

    try {
      print('📷 遅延カメラ初期化開始...');

      final camera = _isRearCameraSelected ? _cameras!.first : _cameras!.last;
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('⏰ CameraController初期化タイムアウト');
          throw Exception('カメラ初期化がタイムアウトしました');
        },
      );

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _cameraInitializationFailed = false;
        });
        print('✅ 遅延カメラ初期化完了');
      }
      return true;
    } catch (e) {
      print('❌ 遅延カメラ初期化エラー: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _cameraInitializationFailed = true;
        });
      }
      _showErrorSnackBar('カメラの初期化に失敗しました: $e');
      return false;
    }
  }

  /// 旧版互換メソッド
  Future<void> _initializeCamera() async {
    await _initializeCameraLazy();
  }

  /// タイムアウト付きUserPreferences読み込み
  Future<void> _loadUserPreferencesWithTimeout() async {
    try {
      print('⚙️ UserPreferences読み込み開始...');

      final prefs = await _userPreferenceService.getPreferences().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ UserPreferences読み込みタイムアウト');
          return null;
        },
      );

      if (mounted) {
        setState(() {
          _userPreferences = prefs;
        });
        print('✅ UserPreferences読み込み完了: ${prefs != null ? "あり" : "なし"}');
      }
    } catch (e) {
      print('❌ UserPreferences読み込みエラー: $e');
    }
  }

  /// 旧版互換メソッド
  Future<void> _loadUserPreferences() async {
    return _loadUserPreferencesWithTimeout();
  }

  Future<void> _loadImageFromUrl(String imageUrl) async {
    print('📷 履歴画像読み込み: $imageUrl');
  }

  // === 写真選択・撮影 ===

  void _showPhotoChoice() {
    setState(() {
      _currentState = CameraAnalysisState.photoChoice;
    });
  }

  /// 撮影画面に移る時にカメラを初期化
  Future<void> _showCapturingState() async {
    // カメラ初期化を試行
    final success = await _initializeCameraLazy();

    if (success) {
      setState(() {
        _currentState = CameraAnalysisState.capturing;
      });
    } else {
      // カメラ初期化失敗時はギャラリー選択に誘導
      _showErrorSnackBar('カメラが利用できません。ギャラリーから画像を選択してください。');
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showErrorSnackBar('カメラが初期化されていません');
      return;
    }

    try {
      setState(() {
        _currentState = CameraAnalysisState.capturing;
      });

      final XFile photo = await _cameraController!.takePicture();
      setState(() {
        _selectedImage = File(photo.path);
      });

      await _analyzeImage();
    } catch (e) {
      setState(() {
        _currentState = CameraAnalysisState.photoChoice;
      });
      _showErrorSnackBar('撮影に失敗しました: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: ApiConfig.imageMaxWidth.toDouble(),
        maxHeight: ApiConfig.imageMaxHeight.toDouble(),
        imageQuality: (ApiConfig.imageQuality * 100).toInt(),
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
        await _analyzeImage();
      }
    } catch (e) {
      _showErrorSnackBar('画像選択に失敗しました: $e');
    }
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _isRearCameraSelected = !_isRearCameraSelected;
      _isCameraInitialized = false;
    });

    _initializeCameraLazy();
  }

  // === 分析処理 ===

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      _showErrorSnackBar('分析する画像がありません');
      return;
    }

    setState(() {
      _currentState = CameraAnalysisState.analyzing;
      _isAnalyzing = true;
      _analysisResult = null;
    });

    try {
      final result = await ApiService.analyzeCameraImage(
        imageFile: _selectedImage!,
        preferences: _userPreferences?.toJson(),
      );

      if (result != null) {
        final analysisResponse = CameraAnalysisResponse.fromJson(result);

        setState(() {
          _analysisResult = analysisResponse;
          _currentState = CameraAnalysisState.results;
          _isAnalyzing = false;
        });

        if (FirebaseAuth.instance.currentUser != null) {
          _saveAnalysisHistory();
        }
      } else {
        throw Exception('分析結果が取得できませんでした');
      }
    } catch (e) {
      setState(() {
        _currentState = CameraAnalysisState.photoChoice;
        _isAnalyzing = false;
      });

      final errorMessage =
          ApiErrorHandler.getErrorMessage('camera_analysis', e);
      _showErrorSnackBar(errorMessage);
    }
  }

  // === 保存処理 ===

  Future<void> _saveAnalysisHistory() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null ||
        _selectedImage == null ||
        _analysisResult == null) {
      return;
    }

    if (_isSaved || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final imageUrl = await _storageService.uploadAnalysisImage(
        _selectedImage!,
        currentUser.uid,
        isPersonalized: _userPreferences != null,
      );

      final historyEntry = AnalysisHistoryEntry.fromCameraAnalysis(
        userId: currentUser.uid,
        analysisText: _analysisResult!.analysis,
        imageURL: imageUrl,
        imagePath: _selectedImage!.path,
        isPersonalized: _userPreferences != null,
        preferenceSnapshot: _userPreferences?.toJson().toString(),
        processingTimeSeconds: _analysisResult!.processingTime,
      );

      await _firestoreService.saveAnalysisHistory(historyEntry);

      setState(() {
        _isSaved = true;
        _isSaving = false;
      });

      _showSuccessSnackBar(AppConstants.SUCCESS_CAMERA_ANALYSIS_SAVED);
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showErrorSnackBar('保存に失敗しました: $e');
    }
  }

  // === UI ヘルパー ===

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _resetAnalysis() {
    setState(() {
      _currentState = CameraAnalysisState.initial;
      _selectedImage = null;
      _analysisResult = null;
      _isAnalyzing = false;
      _isSaving = false;
      _isSaved = false;
    });
  }

  // === UI ビルド ===

  @override
  Widget build(BuildContext context) {
    print(
        '🏗️ CameraScreen: build実行 - state: $_currentState, initializing: $_isInitializing');

    if (_isInitializing) {
      return _buildInitializingScreen();
    }

    if (_initializationError.isNotEmpty) {
      return _buildInitializationErrorScreen();
    }

    switch (_currentState) {
      case CameraAnalysisState.initial:
        return _buildInitialState();
      case CameraAnalysisState.photoChoice:
        return _buildPhotoChoiceState();
      case CameraAnalysisState.capturing:
        return _buildCapturingState();
      case CameraAnalysisState.analyzing:
        return _buildAnalyzingState();
      case CameraAnalysisState.results:
        return _buildResultsState();
    }
  }

  Widget _buildInitializingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カメラ分析'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 3),
                    const SizedBox(height: 24),
                    const Text(
                      '初期化中...',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'サービスを準備しています',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitializationErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カメラ分析'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[600]),
                    const SizedBox(height: 24),
                    const Text(
                      '初期化エラー',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _initializationError,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _initializationError = '';
                        });
                        _safeInitialize();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('再試行'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カメラ分析'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.PADDING_MEDIUM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.circular(AppConstants.CARD_BORDER_RADIUS),
              ),
              child: Column(
                children: [
                  Icon(Icons.camera_alt, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'カメラ分析',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '物件写真をAIが詳細分析',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _showPhotoChoice,
              icon: const Icon(Icons.camera_alt, size: 24),
              label: const Text(
                '写真を撮影・選択',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.BUTTON_BORDER_RADIUS),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // カメラ状態表示（遅延初期化対応）
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cameraInitializationFailed
                    ? Colors.red[50]
                    : (_cameras != null ? Colors.green[50] : Colors.blue[50]),
                borderRadius:
                    BorderRadius.circular(AppConstants.CARD_BORDER_RADIUS),
                border: Border.all(
                  color: _cameraInitializationFailed
                      ? Colors.red[200]!
                      : (_cameras != null
                          ? Colors.green[200]!
                          : Colors.blue[200]!),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _cameraInitializationFailed
                        ? Icons.error
                        : (_cameras != null ? Icons.check_circle : Icons.info),
                    color: _cameraInitializationFailed
                        ? Colors.red[600]
                        : (_cameras != null
                            ? Colors.green[600]
                            : Colors.blue[600]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cameraInitializationFailed
                          ? 'カメラ利用不可（ギャラリーのみ）'
                          : (_cameras != null ? 'カメラ利用可能' : 'カメラ確認中...'),
                      style: TextStyle(
                        color: _cameraInitializationFailed
                            ? Colors.red[700]
                            : (_cameras != null
                                ? Colors.green[700]
                                : Colors.blue[700]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius:
                    BorderRadius.circular(AppConstants.CARD_BORDER_RADIUS),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'カメラ分析でできること',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• 間取り図・物件情報の自動読み取り\n'
                    '• 設備・条件の詳細分析\n'
                    '• あなたの好みに合わせた評価\n'
                    '• 分析履歴の保存（ログイン時）',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            if (FirebaseAuth.instance.currentUser == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ログインすると分析履歴を保存できます',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoChoiceState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('写真選択'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _resetAnalysis,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.PADDING_MEDIUM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Text(
              '写真の選択方法を選んでください',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // カメラ撮影ボタン（カメラ利用可能時のみ）
            if (!_cameraInitializationFailed) ...[
              Card(
                child: InkWell(
                  onTap: _showCapturingState, // 遅延初期化対応
                  borderRadius:
                      BorderRadius.circular(AppConstants.CARD_BORDER_RADIUS),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.camera_alt,
                            size: 48, color: Colors.blue[600]),
                        const SizedBox(height: 12),
                        const Text(
                          'カメラで撮影',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '物件写真や間取り図を直接撮影',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Card(
              child: InkWell(
                onTap: _pickImageFromGallery,
                borderRadius:
                    BorderRadius.circular(AppConstants.CARD_BORDER_RADIUS),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.photo_library,
                          size: 48, color: Colors.green[600]),
                      const SizedBox(height: 12),
                      const Text(
                        'ギャラリーから選択',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '保存済みの写真から選択',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // カメラ利用不可時の説明
            if (_cameraInitializationFailed) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'カメラが利用できません。ギャラリーから画像を選択してください。',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapturingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('撮影'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _currentState = CameraAnalysisState.photoChoice;
            });
          },
        ),
      ),
      body: Stack(
        children: [
          _buildCameraPreview(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildCaptureControls(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '物件情報・間取り図を撮影してください',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析中'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _resetAnalysis,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 3),
                    const SizedBox(height: 24),
                    const Text(
                      'AI分析中...',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cloud Run APIで画像を解析しています',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_selectedImage != null)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsState() {
    if (_analysisResult == null) {
      return _buildAnalyzingState();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('分析結果'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _resetAnalysis,
        ),
        actions: [
          if (FirebaseAuth.instance.currentUser != null && !_isSaved)
            IconButton(
              onPressed: _isSaving ? null : _saveAnalysisHistory,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.PADDING_MEDIUM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text(
                          '分析情報',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('処理時間: ${_analysisResult!.formattedProcessingTime}'),
                    Text(_analysisResult!.personalizationDescription),
                    if (_isSaved)
                      const Text('✅ 履歴に保存済み',
                          style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '分析対象画像',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        const Text(
                          'AI分析結果',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _analysisResult!.analysis,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resetAnalysis,
              icon: const Icon(Icons.refresh),
              label: const Text('別の写真を分析'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_isCameraInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _cameraInitializationFailed ? 'カメラ初期化に失敗しました' : 'カメラを準備中...',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1 / _cameraController!.value.aspectRatio,
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildCaptureControls() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton.small(
            heroTag: 'gallery',
            backgroundColor: Colors.white,
            onPressed: _pickImageFromGallery,
            child: const Icon(Icons.photo_library, color: Colors.black87),
          ),
          FloatingActionButton.large(
            heroTag: 'capture',
            backgroundColor: Colors.white,
            onPressed: _isCameraInitialized ? _takePicture : null,
            child:
                const Icon(Icons.camera_alt, color: Colors.black87, size: 32),
          ),
          FloatingActionButton.small(
            heroTag: 'switch',
            backgroundColor: Colors.white,
            onPressed: _isCameraInitialized ? _switchCamera : null,
            child: const Icon(Icons.flip_camera_ios, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
