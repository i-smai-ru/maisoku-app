// lib/screens/camera_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/camera_core_handler.dart';
import '../screens/camera_ui_components.dart';
import '../services/audio_service.dart';

// === 🔧 開発モード設定 ===
const bool kDebugMode = false; // 本番環境では false に設定

/// CameraScreen - 本番用（デバッグ情報非表示）
///
/// 責務:
/// - 全体の状態管理とライフサイクル
/// - コンポーネント間の調整
/// - ユーザーアクションの処理
/// - エラー表示の統一（デバッグ情報は開発モード時のみ）
/// - 音声再生サービスの管理
class CameraScreen extends StatefulWidget {
  final String? initialImageUrl;
  final VoidCallback? onNavigateToLogin;

  const CameraScreen({
    Key? key,
    this.initialImageUrl,
    this.onNavigateToLogin,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // === 🎯 シンプルな状態管理 ===
  CameraAnalysisState _currentState = CameraAnalysisState.authCheck;
  User? _currentUser;

  // === 📱 コンポーネント ===
  late CameraCoreHandler _coreHandler;
  late CameraUIComponents _uiComponents;
  late AudioService _audioService;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('📱 CameraScreen: initState開始 - 本番用（デバッグ情報非表示）');
    }
    WidgetsBinding.instance.addObserver(this);

    // 🔧 コンポーネント初期化
    _initializeComponents();

    // 🔒 認証チェック開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _coreHandler.performAuthCheck();
    });
  }

  @override
  void dispose() {
    if (kDebugMode) print('📱 CameraScreen: dispose開始');
    _coreHandler.dispose();
    _audioService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _coreHandler.handleLifecycleChange(state);

    // アプリがバックグラウンドに移行した時は音声を停止
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _audioService.stop();
    }
  }

  // === 🔧 コンポーネント初期化 ===
  void _initializeComponents() {
    // 音声サービス初期化
    _audioService = AudioService();

    // コア機能ハンドラー初期化
    _coreHandler = CameraCoreHandler(
      onStateChanged: _handleStateChange,
      onError: _handleError,
      onSuccess: _handleSuccess,
    );

    // UI コンポーネント初期化
    _uiComponents = CameraUIComponents(
      onUserAction: _handleUserAction,
    );
  }

  // === 📞 シンプルなコールバック処理 ===

  /// 状態変更ハンドラー
  void _handleStateChange(CameraAnalysisState newState) {
    if (mounted) {
      setState(() {
        _currentState = newState;
        _currentUser = _coreHandler.currentUser;
      });
      if (kDebugMode) print('📱 状態変更: $newState');
    }
  }

  /// エラーハンドラー（本番用：デバッグ情報の制御）
  void _handleError(String error, {String? debugInfo}) {
    if (kDebugMode) print('❌ エラー: $error');
    if (mounted) {
      // エラー時は音声を停止
      _audioService.stop();

      if (debugInfo != null && kDebugMode) {
        // デバッグ情報付きエラーは開発モード時のみ表示
        _showErrorDialogWithDebug(error, debugInfo);
      } else {
        // 通常エラーはスナックバー（本番・開発両用）
        _showErrorSnackBar(error);
      }
    }
  }

  /// 成功ハンドラー（統一成功表示）
  void _handleSuccess(String message) {
    if (kDebugMode) print('✅ 成功: $message');
    if (mounted) {
      _showSuccessSnackBar(message);
    }
  }

  /// ユーザーアクションハンドラー（統一アクション処理）
  void _handleUserAction(String action, {Map<String, dynamic>? params}) {
    if (kDebugMode) print('👆 ユーザーアクション: $action');

    switch (action) {
      // === 認証関連 ===
      case 'navigate_to_login':
        _navigateToLogin();
        break;

      // === 写真選択関連 ===
      case 'show_photo_choice':
        setState(() => _currentState = CameraAnalysisState.photoChoice);
        break;
      case 'start_camera_capture':
        _startCameraCapture();
        break;
      case 'pick_from_gallery':
        _coreHandler.pickImageFromGallery();
        break;

      // === カメラ操作関連 ===
      case 'take_picture':
        _coreHandler.takePicture();
        break;
      case 'switch_camera':
        _coreHandler.switchCamera();
        break;

      // === 分析関連 ===
      case 'reset_analysis':
        // 音声を停止してから分析をリセット
        _audioService.stop();
        _coreHandler.resetAnalysis();
        break;

      // === 音声・コピー関連 ===
      case 'play_audio':
        _playAnalysisAudio();
        break;
      case 'stop_audio':
        _audioService.stop();
        break;
      case 'copy_text':
        _copyAnalysisText();
        break;

      default:
        if (kDebugMode) print('⚠️ 未知のアクション: $action');
    }
  }

  // === 🎬 特定アクション処理 ===

  /// カメラ撮影開始（カメラ初期化付き）
  Future<void> _startCameraCapture() async {
    final success = await _coreHandler.initializeCameraLazy();
    if (success) {
      setState(() => _currentState = CameraAnalysisState.capturing);
    } else {
      _handleError('カメラが利用できません。ギャラリーから画像を選択してください。');
    }
  }

  /// ログイン画面への遷移
  void _navigateToLogin() {
    if (widget.onNavigateToLogin != null) {
      widget.onNavigateToLogin!();
    } else {
      _showErrorSnackBar('ログインするには画面下部の「ログイン」タブをタップしてください');
    }
  }

  /// 分析結果の音声再生
  Future<void> _playAnalysisAudio() async {
    if (_coreHandler.analysisResult == null) {
      _showErrorSnackBar('分析結果がありません');
      return;
    }

    try {
      _showInfoSnackBar('音声再生を開始しています...');

      final analysisText = _coreHandler.analysisResult!.analysis;
      final cleanText = _cleanTextForAudio(analysisText);

      await _audioService.speak(cleanText);

      // 音声再生完了の監視
      _audioService.isCompleted.listen((isCompleted) {
        if (isCompleted && mounted) {
          _showSuccessSnackBar('音声再生が完了しました');
        }
      });
    } catch (e) {
      _showErrorSnackBar('音声再生でエラーが発生しました');
      if (kDebugMode) print('音声再生エラー: $e');
    }
  }

  /// 分析結果のテキストコピー
  void _copyAnalysisText() {
    if (_coreHandler.analysisResult == null) {
      _showErrorSnackBar('分析結果がありません');
      return;
    }

    try {
      final analysisText = _coreHandler.analysisResult!.analysis;
      final cleanText = _cleanTextForCopy(analysisText);

      Clipboard.setData(ClipboardData(text: cleanText));
      _showSuccessSnackBar('分析結果をクリップボードにコピーしました');
    } catch (e) {
      _showErrorSnackBar('コピーでエラーが発生しました');
      if (kDebugMode) print('コピーエラー: $e');
    }
  }

  // === 🧹 テキストクリーニング ===

  /// 音声用のテキストクリーニング
  String _cleanTextForAudio(String text) {
    String cleaned = text;

    // エスケープシーケンスを変換
    cleaned = cleaned.replaceAll('\\n', '\n');

    // マークダウン記号を除去
    cleaned = cleaned.replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'^\*\s+', multiLine: true), '');

    // 連続する改行を整理
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n'), '\n');

    return cleaned.trim();
  }

  /// コピー用のテキストクリーニング
  String _cleanTextForCopy(String text) {
    String cleaned = text;

    // エスケープシーケンスを変換
    cleaned = cleaned.replaceAll('\\n', '\n');
    cleaned = cleaned.replaceAll('\\t', '\t');

    return cleaned.trim();
  }

  // === 🎨 UI表示ヘルパー ===

  /// エラースナックバー表示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '閉じる',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 成功スナックバー表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 情報スナックバー表示
  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// デバッグ情報付きエラーダイアログ表示（開発モード時のみ）
  void _showErrorDialogWithDebug(String error, String debugInfo) {
    if (!kDebugMode) {
      // 本番モードでは通常のエラースナックバーとして表示
      _showErrorSnackBar(error);
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600]),
              const SizedBox(width: 8),
              const Text('エラーが発生しました'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // エラーメッセージ
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // デバッグ情報（展開可能）
                ExpansionTile(
                  title: Row(
                    children: [
                      Icon(Icons.bug_report,
                          color: Colors.purple[600], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'デバッグ情報',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          debugInfo,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
            if (kDebugMode)
              ElevatedButton(
                onPressed: () {
                  // デバッグ情報をクリップボードにコピー
                  Clipboard.setData(ClipboardData(text: debugInfo));
                  Navigator.of(context).pop();
                  _showSuccessSnackBar('デバッグ情報をコピーしました');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('デバッグ情報をコピー'),
              ),
          ],
        );
      },
    );
  }

  // === 📱 メインビルドメソッド ===
  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print(
          '🏗️ CameraScreen: build実行 - state: $_currentState, user: ${_currentUser?.uid ?? "null"}');
    }

    // UIコンポーネントに状態別UI構築を委譲
    return _uiComponents.buildForState(
      context,
      _currentState,
      _currentUser,
      _coreHandler,
    );
  }
}
