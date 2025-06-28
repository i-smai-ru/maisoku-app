// lib/screens/login_screen.dart - Googleログイン完全実装版

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Maisoku AI v1.0: ログイン画面（Googleログイン完全実装）
///
/// 実装機能：
/// - Google Sign-In による Firebase Authentication
/// - ログイン成功時の自動マイページ遷移
/// - エラーハンドリング・ユーザビリティ向上
/// - 段階的認証システムの価値提案
class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    Key? key,
    this.onLoginSuccess,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // === Services ===
  late AuthService _authService;
  late FirestoreService _firestoreService;

  // === 状態管理 ===
  bool _isLoading = false;
  String _errorMessage = '';

  // === アニメーション ===
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    print('🔐 LoginScreen: initState開始（Googleログイン対応）');

    _authService = AuthService();
    _firestoreService = FirestoreService();

    // アニメーションの初期化
    _setupAnimations();

    // 画面表示アニメーション開始
    _startEntryAnimation();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  /// アニメーション設定
  void _setupAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  /// 画面表示アニメーション開始
  void _startEntryAnimation() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeAnimationController.forward();
        _slideAnimationController.forward();
      }
    });
  }

  // === 🔐 認証処理 ===

  /// Google認証でログイン
  Future<void> _signInWithGoogle() async {
    print('🔐 Googleログイン開始');

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential != null && userCredential.user != null) {
        // ログイン成功
        final user = userCredential.user!;
        print('✅ ログイン成功: ${user.email}');

        // ユーザーデータの確認・作成
        await _firestoreService.upsertUser(user);
        print('📝 ユーザーデータ更新完了');

        if (mounted) {
          // 成功メッセージ表示
          _showSuccessSnackBar('ログインしました！全機能が利用できます');

          // ログイン完了ダイアログ表示
          _showLoginCompletionDialog(user);

          // コールバック実行（main.dartでタブ切り替え処理）
          await Future.delayed(const Duration(seconds: 1));
          widget.onLoginSuccess?.call();
        }
      } else {
        // ユーザーがキャンセルした場合
        if (mounted) {
          setState(() {
            _errorMessage = 'ログインがキャンセルされました';
          });
          print('⚠️ ログインキャンセル');
        }
      }
    } catch (e) {
      print('❌ ログインエラー: $e');

      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e.toString());
        });

        _showErrorSnackBar(_errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// ログイン完了ダイアログ表示
  void _showLoginCompletionDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.verified_user, color: Colors.green[600], size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'ログイン完了！',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.displayName ?? user.email} さん',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎉 利用可能になった機能:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '📸 カメラ分析：履歴保存・比較\n'
                      '🎯 エリア分析：個人化分析\n'
                      '📊 分析履歴：過去データ管理\n'
                      '⚙️ 好み設定：個人カスタマイズ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('マイページへ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// エラーメッセージを分かりやすく変換
  String _getErrorMessage(String error) {
    String lowerError = error.toLowerCase();

    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'ネットワークエラーが発生しました。インターネット接続を確認してください。';
    } else if (lowerError
        .contains('account-exists-with-different-credential')) {
      return 'このメールアドレスは別の認証方法で登録されています。';
    } else if (lowerError.contains('user-cancelled') ||
        lowerError.contains('cancelled')) {
      return 'ログインがキャンセルされました。';
    } else if (lowerError.contains('sign_in_failed') ||
        lowerError.contains('signin_failed')) {
      return 'ログインに失敗しました。再度お試しください。';
    } else if (lowerError.contains('popup-closed-by-user') ||
        lowerError.contains('popup')) {
      return 'ログイン画面が閉じられました。';
    } else if (lowerError.contains('退会処理中')) {
      return '退会処理中のアカウントです。しばらくお待ちください。';
    } else if (lowerError.contains('too-many-requests')) {
      return 'ログイン試行回数が多すぎます。しばらくお待ちください。';
    } else if (lowerError.contains('user-disabled')) {
      return 'このアカウントは無効になっています。';
    } else if (lowerError.contains('invalid-credential')) {
      return '認証情報が無効です。再度お試しください。';
    }

    return 'ログインエラーが発生しました。時間をおいて再度お試しください。';
  }

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  /// エラーメッセージ表示
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  // === ゲスト体験案内 ===

  /// ゲスト体験ボタンアクション
  void _tryAsGuest() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 28),
              const SizedBox(width: 12),
              const Text('ゲスト体験について'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '現在でも以下の機能をご利用いただけます：',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildDialogFeatureItem(Icons.location_on, 'エリア分析（基本版）',
                  '住所入力で住環境を客観的に分析', Colors.blue[600]!),
              _buildDialogFeatureItem(Icons.search, '住所検索・GPS機能',
                  'Google Maps連携の住所候補・位置情報', Colors.green[600]!),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.upgrade,
                            color: Colors.orange[600], size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'ログインで追加される機能:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '📸 カメラ分析・📊 履歴保存・🎯 個人化分析',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // エリア分析タブに移動するためのロジック
                // 現在は単純にダイアログを閉じるのみ
                _showSuccessSnackBar('エリア分析タブをタップしてお試しください');
              },
              icon: const Icon(Icons.location_on),
              label: const Text('エリア分析を試す'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogFeatureItem(
      IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green[400]!, Colors.green[600]!],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ヘッダー部分（グラデーション背景）
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.green[400]!, Colors.green[600]!],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            // ログインアイコン
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.login,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Maisoku AIにログイン',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '個人化機能・履歴保存を利用するには\nログインが必要です',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '🔄 段階的認証システム',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // メインコンテンツ
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),

                        // エラーメッセージ表示
                        if (_errorMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Googleログインボタン
                        SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.login,
                                      size: 16,
                                      color: Colors.green[600],
                                    ),
                                  ),
                            label: Text(
                              _isLoading ? 'ログイン中...' : 'Googleでログイン',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ログインで利用可能になる機能説明
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.star,
                                      color: Colors.green[600], size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ログインで利用可能になる機能',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildFeatureItem(
                                Icons.camera_alt,
                                'カメラ分析（履歴保存）',
                                '物件写真の分析結果を保存・比較・再分析可能',
                                Colors.blue[600]!,
                              ),
                              _buildFeatureItem(
                                Icons.verified_user,
                                'エリア分析（個人化）',
                                'あなたの好み設定を反映した個人的な環境評価',
                                Colors.green[600]!,
                              ),
                              _buildFeatureItem(
                                Icons.history,
                                '分析履歴管理',
                                '過去の分析結果の管理・比較・エクスポート',
                                Colors.purple[600]!,
                              ),
                              _buildFeatureItem(
                                Icons.settings,
                                '個人設定保存',
                                '音声設定・好み設定・使用履歴の保存',
                                Colors.orange[600]!,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 現在利用可能な機能
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue[600], size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    '現在でも利用可能（未ログイン）',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '• ホーム画面：アプリ概要・機能説明\n'
                                '• エリア分析：基本的な住環境分析（揮発的表示）\n'
                                '• 住所検索：Google Maps連携の住所候補・GPS機能\n'
                                '• すべての案内・説明機能',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _tryAsGuest,
                                  icon: const Icon(Icons.try_sms_star),
                                  label: const Text('ゲストとして体験'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue[600],
                                    side: BorderSide(color: Colors.blue[300]!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 利用規約・プライバシーポリシー
                        Text(
                          'ログインすることで、利用規約およびプライバシーポリシーに同意したものとみなされます。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        // セキュリティ情報
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.security,
                                      color: Colors.grey[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'セキュリティについて',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Firebase Authenticationによる安全な認証\n'
                                '• Google標準のセキュリティ基準を満たした認証システム\n'
                                '• 個人情報の適切な暗号化・保護',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 機能項目ウィジェット
  Widget _buildFeatureItem(
      IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
