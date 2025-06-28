// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/api_config.dart';
import 'services/api_service.dart';
import 'services/firestore_service.dart';
import 'services/audio_service.dart';
import 'services/auth_check_service.dart';
import 'screens/camera_screen.dart';
import 'screens/area_screen.dart';
import 'screens/my_page_screen.dart';
import 'screens/login_screen.dart';

/// Maisoku AI v1.0 - メインアプリケーション
void main() async {
  print('🚀 === Maisoku AI v1.0 ===');

  WidgetsFlutterBinding.ensureInitialized();

  // Firebase初期化
  try {
    await Firebase.initializeApp();
    print('✅ Firebase初期化成功');
  } catch (e) {
    print('❌ Firebase初期化エラー: $e');
  }

  // API設定検証
  final configResult = ApiConfig.validateConfiguration();
  if (configResult['has_errors'] == true) {
    print('⚠️ 設定エラーが検出されました:');
    final errors = configResult['errors'] as List<String>;
    for (final error in errors) {
      print('   - $error');
    }
    print('   api_config.dartでAPIキーを設定してください');
  } else {
    print('✅ API設定確認完了');
  }

  runApp(MaisokuApp());
}

class MaisokuApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maisoku AI - あなたの住まい選びを科学的にサポート',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,

        // v1.0: Material Design 3対応
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        // アプリバーテーマ
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),

        // ボトムナビゲーションテーマ
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green[700],
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Colors.white,
          elevation: 8,
        ),
      ),
      // ルーティング設定を追加
      routes: {
        '/my_page': (context) => MyPageScreen(
              firestoreService: FirestoreService(),
              currentUser: FirebaseAuth.instance.currentUser,
              audioService: AudioService(),
            ),
        // 必要に応じて他のルートも追加
      },
      home: AuthCheckWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 認証チェック機能付きラッパー（段階的認証対応）
class AuthCheckWrapper extends StatefulWidget {
  @override
  State<AuthCheckWrapper> createState() => _AuthCheckWrapperState();
}

class _AuthCheckWrapperState extends State<AuthCheckWrapper> {
  bool _isChecking = true;
  String _statusMessage = 'アプリを初期化中...';

  @override
  void initState() {
    super.initState();
    _performStartupCheck();
  }

  /// 起動時認証チェック（段階的認証対応）
  Future<void> _performStartupCheck() async {
    try {
      setState(() {
        _statusMessage = 'Firebase接続を確認中...';
      });

      // Firebase完全初期化待機
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _statusMessage = 'ユーザー認証状態をチェック中...';
      });

      // 🔄 段階的認証システムでの認証状態検証
      final isValid = await AuthCheckService.validateUserOnStartup();
      print('🔐 起動時認証チェック結果: ${isValid ? "有効" : "無効"}');

      setState(() {
        _statusMessage = isValid ? '認証済み - 全機能利用可能' : '基本機能利用可能';
      });

      if (!isValid) {
        setState(() {
          _statusMessage = '基本機能で開始（ログインで全機能利用可能）';
        });
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        setState(() {
          _statusMessage = '全機能利用可能';
        });
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 🎯 段階的認証状態のデバッグ出力
      AuthCheckService.debugUserState();

      setState(() {
        _isChecking = false;
      });
      print('✅ 起動時チェック完了（段階的認証対応）');
    } catch (e) {
      print('❌ 起動時チェックエラー: $e');

      setState(() {
        _statusMessage = 'エラーが発生しました。基本機能で開始します...';
      });

      await AuthCheckService.manualReset();
      await Future.delayed(const Duration(milliseconds: 1000));

      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.green[400]!, Colors.green[600]!],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'Maisoku AI',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'あなたの住まい選びを科学的にサポート',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🔧 v1.0',
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
      );
    }

    return MainTabScreen();
  }
}

/// メインタブ画面
class MainTabScreen extends StatefulWidget {
  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen>
    with WidgetsBindingObserver {
  // === 🔐 認証・サービス ===
  User? _currentUser;
  late FirestoreService _firestoreService;
  late AudioService _audioService;

  // === 📱 画面管理 ===
  List<Widget> _screens = [];
  int _currentIndex = 0;

  // === 🎯 段階的認証状態管理 ===
  Map<String, bool> _featureAvailability = {};
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    print('🔧 MainTabScreen: initState開始');

    WidgetsBinding.instance.addObserver(this);

    // サービス初期化
    _firestoreService = FirestoreService();
    _audioService = AudioService();

    // 🔄 段階的認証状態監視開始
    _setupGradualAuthListener();
    _setupAudioService();
  }

  @override
  void dispose() {
    print('🔧 MainTabScreen: dispose');
    WidgetsBinding.instance.removeObserver(this);
    _audioService.dispose();
    super.dispose();
  }

  // === 🔄 段階的認証状態監視 ===

  /// 段階的認証状態監視設定
  void _setupGradualAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        print('🔐 MainTab: 認証状態変更 ${user?.uid ?? "ログアウト"}');

        final wasLoggedIn = _currentUser != null;
        final isNowLoggedIn = user != null;

        setState(() {
          _currentUser = user;
        });

        // 🎯 機能利用可能状況の更新
        _updateFeatureAvailability();

        // 🏗️ 画面を再構築
        _initializeScreens();

        // 📱 タブ位置調整（段階的認証対応）
        _adjustTabPosition(wasLoggedIn, isNowLoggedIn);

        print('✅ MainTab: 段階的認証状態更新完了');
      }
    });
  }

  /// 機能利用可能状況の更新
  void _updateFeatureAvailability() {
    setState(() {
      _featureAvailability = AuthCheckService.getFeatureAvailability();
    });

    print('📊 機能利用可能状況:');
    _featureAvailability.forEach((feature, available) {
      print('   ${available ? "✅" : "❌"} $feature');
    });
  }

  /// タブ位置調整（段階的認証対応）
  void _adjustTabPosition(bool wasLoggedIn, bool isNowLoggedIn) {
    if (wasLoggedIn && !isNowLoggedIn) {
      // ログアウト時：認証必須画面にいた場合は適切な画面に移動
      print('📤 ログアウト検出: タブ位置を調整');

      if (_currentIndex >= 3) {
        // マイページにいた場合
        if (_currentIndex == 3) {
          // マイページ
          _currentIndex = 3; // ログイン画面に移動
          _showLogoutNotification('ログアウトしました');
        }
      }
    } else if (!wasLoggedIn && isNowLoggedIn) {
      // ログイン時：ログイン画面にいた場合はマイページに移動
      print('📥 ログイン検出: タブ位置を調整');

      if (_currentIndex == 3) {
        // ログイン画面にいた場合
        _currentIndex = 3; // マイページに移動（4タブ構成なのでindex 3）
        _showLoginNotification('ログインしました！全機能が利用できます');
      }
    }

    // インデックスの安全性チェック
    if (_currentIndex >= _screens.length) {
      _currentIndex = 0;
    }
  }

  /// ログアウト通知表示
  void _showLogoutNotification(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange[600],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// ログイン通知表示
  void _showLoginNotification(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // === 🏗️ 画面初期化 ===

  /// 画面初期化
  void _initializeScreens() {
    print('🏗️ MainTabScreen: 画面初期化開始');
    List<Widget> newScreens = [];

    // 1. ホーム画面（常に存在・段階的認証状態表示）
    newScreens.add(_buildGradualAuthHomeScreen());

    // 2. カメラ分析画面（常に存在・認証必須制御内蔵）
    newScreens.add(CameraScreen(
      onNavigateToLogin: () {
        print('📱 カメラ画面からログインタブへの遷移要求');
        // ログインタブに移動
        if (_currentUser == null) {
          // 未ログイン時：ログインタブ（index 3）に移動
          _changeTab(3);
        } else {
          // ログイン済み時：マイページタブ（index 3）に移動
          _changeTab(3);
        }
      },
    ));

    // 3. エリア分析画面（常に存在・段階的認証対応・コールバック追加）
    newScreens.add(AreaScreen(
      onNavigateToLogin: () {
        print('📱 エリア分析画面からログインタブへの遷移要求');
        if (_currentUser == null) {
          _changeTab(3); // ログインタブに移動
        } else {
          print('⚠️ 既にログイン済みです');
        }
      },
      onNavigateToMyPage: () {
        print('📱 エリア分析画面からマイページタブへの遷移要求');
        if (_currentUser != null) {
          _changeTab(3); // マイページタブに移動
        } else {
          print('⚠️ ログインが必要です');
          _changeTab(3); // ログインタブに移動
        }
      },
    ));

    // 4. ログイン画面 または マイページ画面
    if (_currentUser != null) {
      // ログイン時：マイページ画面
      print('👤 ログイン状態: 4タブ構成（マイページ）で初期化');

      newScreens.add(MyPageScreen(
        firestoreService: _firestoreService,
        currentUser: _currentUser,
        audioService: _audioService,
      ));
    } else {
      // 未ログイン時：ログイン画面
      print('🔒 未ログイン状態: 4タブ構成（ログイン）で初期化');

      newScreens.add(LoginScreen(
        onLoginSuccess: () {
          print('🎉 ログイン成功: マイページタブに移動');
          // ログイン成功時にマイページタブに移動
          // 画面の再構築により自動的にタブ構成が変更される
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _currentUser != null) {
              _changeTab(3); // マイページに移動
            }
          });
        },
      ));
    }

    setState(() {
      _screens = newScreens;
      _isInitialized = true;
    });
    print('✅ 画面初期化完了: ${_screens.length}画面');
  }

  /// 段階的認証対応ホーム画面を構築
  Widget _buildGradualAuthHomeScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maisoku AI'),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // メインロゴ・説明
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[400]!, Colors.green[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.home, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Maisoku AI',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'あなたの住まい選びをサポート',
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
                        '🔧 v1.0',
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

              const SizedBox(height: 32),

              // 🔄 段階的認証状態表示
              _buildGradualAuthStatusCard(),

              const SizedBox(height: 24),

              // 機能カード（段階的認証対応）
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      title: 'カメラ分析',
                      description: '物件写真をAI分析',
                      icon: Icons.camera_alt,
                      color: Colors.blue,
                      isAvailable: _featureAvailability['camera'] ?? false,
                      onTap: () => _handleFeatureAccess('camera', 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFeatureCard(
                      title: 'エリア分析',
                      description: '周辺環境を総合評価',
                      icon: Icons.location_on,
                      color: Colors.green,
                      isAvailable: true, // 常に利用可能（段階的）
                      onTap: () => _changeTab(2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 認証状態に応じた追加機能
              if (_currentUser != null) ...[
                _buildFeatureCard(
                  title: 'マイページ',
                  description: '設定・アカウント管理',
                  icon: Icons.person,
                  color: Colors.orange,
                  isAvailable: _featureAvailability['mypage'] ?? false,
                  onTap: () => _changeTab(3),
                ),
              ] else ...[
                _buildFeatureCard(
                  title: 'ログイン・会員登録',
                  description: '個人化分析機能を利用',
                  icon: Icons.login,
                  color: Colors.orange,
                  isAvailable: true,
                  onTap: () => _changeTab(3),
                ),
              ],

              const SizedBox(height: 32),

              // バージョン情報・技術スタック
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Maisoku AI v1.0',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '🚀 Flutter + Firebase + Cloud Run + Vertex AI\n'
                      '🤖 最新のGoogle AI技術で住まい選びをサポート\n'
                      '🔄 段階的認証システムで誰でも利用可能',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
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
      ),
    );
  }

  /// 🔄 段階的認証状態表示カード
  Widget _buildGradualAuthStatusCard() {
    if (_currentUser != null) {
      return Container(
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
                Icon(Icons.verified_user, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ログイン済み：${_currentUser!.email}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '✅ 全ての機能を利用できます\n'
              '📸 カメラ分析：個人化分析\n'
              '🗺️ エリア分析：基本分析 + 個人化分析\n'
              '⚙️ マイページ：アカウント管理',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green[700],
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '未ログイン状態',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '🔓 基本機能は今すぐ利用できます\n'
              '❌ カメラ分析：ログインが必要\n'
              '✅ エリア分析：基本分析のみ利用可能\n'
              '💡 ログインすると個人化機能が利用できます',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _changeTab(3),
                icon: const Icon(Icons.login),
                label: const Text('ログインして全機能を利用'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 機能カードウィジェット（段階的認証対応）
  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required MaterialColor color,
    required bool isAvailable,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isAvailable ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isAvailable ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isAvailable ? null : Colors.grey[100],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAvailable ? color[50] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isAvailable ? color[600] : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isAvailable ? color[800] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isAvailable ? Colors.grey[600] : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              if (!isAvailable) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ログイン必要',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 音声サービスセットアップ
  void _setupAudioService() {
    print('🔊 AudioService: セットアップ開始');
  }

  // === 📱 タブ変更・機能アクセス制御 ===

  /// 🔄 機能アクセス制御付きタブ変更
  void _handleFeatureAccess(String featureName, int tabIndex) {
    final isAvailable = _featureAvailability[featureName] ?? false;

    if (isAvailable) {
      _changeTab(tabIndex);
    } else {
      // 認証が必要な機能へのアクセス時
      final message = AuthCheckService.getAuthRequiredMessage(featureName);
      _showFeatureAccessDeniedDialog(featureName, message);
    }
  }

  /// 機能アクセス拒否ダイアログ
  void _showFeatureAccessDeniedDialog(String featureName, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.orange[600]),
              const SizedBox(width: 8),
              const Text('ログインが必要'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _changeTab(3); // ログイン画面に移動
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('ログイン'),
            ),
          ],
        );
      },
    );
  }

  /// タブ変更処理
  void _changeTab(int index) {
    print('📱 タブ変更: $_currentIndex -> $index');

    if (!_isInitialized || _screens.isEmpty) {
      print('⚠️ 画面未初期化のためタブ変更をスキップ');
      return;
    }

    // インデックスの範囲チェック（4タブ構成）
    if (index < 0 || index >= _screens.length) {
      print('⚠️ 無効なタブインデックス: $index (有効範囲: 0-${_screens.length - 1})');
      return;
    }

    setState(() {
      _currentIndex = index;

      // カメラ分析タブの場合はリセット
      if (index == 1) {
        print('📷 CameraScreen: リセット');
        _screens[1] = CameraScreen(
          onNavigateToLogin: () {
            print('📱 カメラ画面からログインタブへの遷移要求');
            _changeTab(3); // ログイン/マイページタブに移動
          },
        );
      }

      // エリア分析タブは常にリセット（揮発的表示）
      if (index == 2) {
        print('📍 AreaScreen: リセット（コールバック付き）');
        _screens[2] = AreaScreen(
          onNavigateToLogin: () {
            print('📱 エリア分析画面からログインタブへの遷移要求');
            if (_currentUser == null) {
              _changeTab(3); // ログインタブに移動
            } else {
              print('⚠️ 既にログイン済みです');
            }
          },
          onNavigateToMyPage: () {
            print('📱 エリア分析画面からマイページタブへの遷移要求');
            if (_currentUser != null) {
              _changeTab(3); // マイページタブに移動
            } else {
              print('⚠️ ログインが必要です');
              _changeTab(3); // ログインタブに移動
            }
          },
        );
      }
    });

    print('✅ タブ変更完了: $index');
  }

  /// ボトムナビゲーションアイテム構築
  List<BottomNavigationBarItem> _buildBottomNavItems() {
    if (_currentUser != null) {
      // ログイン時：4タブ構成（ホーム、カメラ、エリア、マイページ）
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'ホーム',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: 'カメラ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on),
          label: 'エリア',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'マイページ',
        ),
      ];
    } else {
      // 未ログイン時：4タブ構成（ホーム、カメラ、エリア、ログイン）
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'ホーム',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: 'カメラ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on),
          label: 'エリア',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.login),
          label: 'ログイン',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        '🏗️ MainTabScreen: build実行 - currentIndex: $_currentIndex, screens: ${_screens.length}, auth: ${_currentUser?.uid ?? "null"}');

    // 画面が初期化されていない場合はローディング表示
    if (!_isInitialized || _screens.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.green[400]!, Colors.green[600]!],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 24),
                Text(
                  'Maisoku AI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'タブ遷移システムを初期化中...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // インデックスの安全性確保
    if (_currentIndex >= _screens.length || _currentIndex < 0) {
      print('⚠️ インデックス修正: $_currentIndex -> 0');
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex.clamp(0, _screens.length - 1),
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex.clamp(0, _screens.length - 1),
        onTap: _changeTab,
        items: _buildBottomNavItems(),
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
