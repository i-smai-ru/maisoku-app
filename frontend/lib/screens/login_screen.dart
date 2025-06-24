// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Maisoku AI v1.0: ログイン画面
///
/// 段階的認証システム対応：
/// - 未ログイン時の4タブ目として表示
/// - Google認証によるFirebaseログイン
/// - ログイン成功時の自動マイページ遷移
/// - カメラ分析履歴保存・エリア分析個人化の説明
class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    Key? key,
    this.onLoginSuccess,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late AuthService _authService;
  late FirestoreService _firestoreService;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _firestoreService = FirestoreService();
  }

  /// Google認証でログイン
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential != null && userCredential.user != null) {
        // ログイン成功
        print('✅ ログイン成功: ${userCredential.user!.email}');

        // ユーザーデータの確認・作成
        await _firestoreService.upsertUser(userCredential.user!);

        if (mounted) {
          _showSuccessSnackBar(
              'ログインしました: ${userCredential.user!.displayName ?? userCredential.user!.email}');

          // コールバック実行（main.dartでタブ切り替え処理）
          widget.onLoginSuccess?.call();
        }
      } else {
        // ユーザーがキャンセルした場合
        if (mounted) {
          setState(() {
            _errorMessage = 'ログインがキャンセルされました';
          });
        }
      }
    } catch (e) {
      print('❌ ログインエラー: $e');

      if (mounted) {
        setState(() {
          if (e.toString().contains('退会処理中')) {
            _errorMessage = '退会処理中のアカウントです。しばらくお待ちください。';
          } else {
            _errorMessage = 'ログインに失敗しました: ${_getErrorMessage(e.toString())}';
          }
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

  /// エラーメッセージを分かりやすく変換
  String _getErrorMessage(String error) {
    if (error.contains('network')) {
      return 'ネットワークエラーが発生しました';
    } else if (error.contains('account-exists-with-different-credential')) {
      return 'このメールアドレスは別の認証方法で登録されています';
    } else if (error.contains('user-cancelled')) {
      return 'ログインがキャンセルされました';
    } else if (error.contains('sign_in_failed')) {
      return 'ログインに失敗しました。再度お試しください';
    }
    return 'ログインエラーが発生しました';
  }

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// エラーメッセージ表示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
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
      body: SingleChildScrollView(
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
                  ],
                ),
              ),
            ),

            // メインコンテンツ
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

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
                          'カメラ分析履歴保存',
                          '物件写真の分析結果を保存・比較・再分析可能',
                          Colors.blue[600]!,
                        ),
                        _buildFeatureItem(
                          Icons.location_on,
                          'エリア分析個人化',
                          'あなたの好み設定を反映した個人的な環境評価',
                          Colors.green[600]!,
                        ),
                        _buildFeatureItem(
                          Icons.settings,
                          '個人設定保存',
                          '音声設定・好み設定・使用履歴の保存',
                          Colors.purple[600]!,
                        ),
                        _buildFeatureItem(
                          Icons.sync,
                          'データ同期',
                          'デバイス間でのデータ同期・バックアップ',
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
                          '• カメラ分析：基本的な物件写真分析（履歴保存なし）\n'
                          '• エリア分析：基本的な住環境分析（揮発的表示）',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                          : Image.asset(
                              'assets/images/google_logo.png',
                              width: 20,
                              height: 20,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.login,
                                    color: Colors.white);
                              },
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
                          'Firebase Authenticationによる安全な認証\n'
                          'Google標準のセキュリティ基準を満たした認証システム',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
