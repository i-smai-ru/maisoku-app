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
import 'screens/history_screen.dart';
import 'models/analysis_history_entry.dart';

/// Maisoku AI v1.0 - メインアプリケーション
///
/// 機能分離対応：
/// - カメラ分析: 履歴保存あり（認証必須）
/// - エリア分析: 揮発的表示（段階的認証）
/// - 動的タブ構成: 認証状態による5タブ/4タブ切り替え
void main() async {
  print('🚀 === Maisoku AI v1.0 起動 ===');

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

/// 認証チェック機能付きラッパー
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

  /// 起動時認証チェック
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

      // 認証状態検証
      final isValid = await AuthCheckService.validateUserOnStartup();
      print('🔐 起動時認証チェック結果: ${isValid ? "有効" : "無効"}');

      if (!isValid) {
        setState(() {
          _statusMessage = '認証情報をクリアしました';
        });
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        setState(() {
          _statusMessage = 'ユーザー状態確認完了';
        });
        await Future.delayed(const Duration(milliseconds: 300));
      }

      setState(() {
        _isChecking = false;
      });
      print('✅ 起動時チェック完了');
    } catch (e) {
      print('❌ 起動時チェックエラー: $e');

      setState(() {
        _statusMessage = 'エラーが発生しました。認証情報をリセットします...';
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
              ],
            ),
          ),
        ),
      );
    }

    return MainTabScreen();
  }
}

/// メインタブ画面 - 動的タブ構成対応
class MainTabScreen extends StatefulWidget {
  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen>
    with WidgetsBindingObserver {
  // 認証・サービス
  User? _currentUser;
  late FirestoreService _firestoreService;
  late AudioService _audioService;

  // 画面管理
  List<Widget> _screens = [];
  int _currentIndex = 0;
  int? _historyReturnIndex; // 履歴から戻る時のタブ記憶

  @override
  void initState() {
    super.initState();
    print('🔧 MainTabScreen: initState開始');

    WidgetsBinding.instance.addObserver(this);

    // サービス初期化
    _firestoreService = FirestoreService();
    _audioService = AudioService();

    // 認証状態監視開始
    _setupAuthListener();
    _setupAudioService();
  }

  @override
  void dispose() {
    print('🔧 MainTabScreen: dispose');
    WidgetsBinding.instance.removeObserver(this);
    _audioService.dispose();
    super.dispose();
  }

  /// 認証状態監視設定
  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        print('🔐 認証状態変更: ${user?.uid ?? "ログアウト"}');

        setState(() {
          final wasLoggedIn = _currentUser != null;
          final isNowLoggedIn = user != null;
          _currentUser = user;

          // 画面を再構築
          _initializeScreens();

          // タブ位置調整
          if (wasLoggedIn && !isNowLoggedIn) {
            // ログアウト時：履歴タブ以降にいた場合はホームに戻る
            print('📤 ログアウト検出: タブを調整します');
            if (_currentIndex >= 3) {
              _currentIndex = 0; // ホームに戻る
            }
          } else if (!wasLoggedIn && isNowLoggedIn) {
            // ログイン時：ログイン画面にいた場合はマイページに移動
            print('📥 ログイン検出: タブを調整します');
            if (_currentIndex == 3) {
              _currentIndex = 4; // マイページに移動
            }
          }

          // インデックスの安全性チェック
          if (_currentIndex >= _screens.length) {
            _currentIndex = 0;
          }
        });
      }
    });
  }

  /// 画面初期化（実装済み画面を使用）
  void _initializeScreens() {
    print('🏗️ MainTabScreen: 画面初期化開始');
    List<Widget> newScreens = [];

    // 1. ホーム画面（常に存在）
    newScreens.add(_buildHomeScreen());

    // 2. カメラ分析画面（常に存在） - 修正版CameraScreenを使用
    newScreens.add(const CameraScreen());

    // 3. エリア分析画面（常に存在） - 実装済み画面を使用
    newScreens.add(const AreaScreen());

    if (_currentUser != null) {
      // ログイン時：5タブ構成
      print('👤 ログイン状態: 5タブ構成で初期化');

      // 4. 履歴画面（カメラ分析履歴のみ） - 実装済み画面を使用
      newScreens.add(HistoryScreen(
        firestoreService: _firestoreService,
        currentUser: _currentUser!,
        onReanalyze: _navigateToReanalyze,
        audioService: _audioService,
      ));

      // 5. マイページ画面 - 実装済み画面を使用
      newScreens.add(MyPageScreen(
        firestoreService: _firestoreService,
        currentUser: _currentUser,
        audioService: _audioService,
      ));
    } else {
      // 未ログイン時：4タブ構成
      print('🔒 未ログイン状態: 4タブ構成で初期化');

      // 4. ログイン画面
      newScreens.add(_buildLoginScreen());
    }

    _screens = newScreens;
    print('✅ 画面初期化完了: ${_screens.length}画面');
  }

  /// ホーム画面を構築（実装版）
  Widget _buildHomeScreen() {
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
                child: const Column(
                  children: [
                    Icon(Icons.home, color: Colors.white, size: 48),
                    SizedBox(height: 16),
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
                      'あなたの住まい選びをサポート',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 機能カード
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      title: 'カメラ分析',
                      description: '物件写真をAI分析',
                      icon: Icons.camera_alt,
                      color: Colors.blue,
                      onTap: () => _changeTab(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFeatureCard(
                      title: 'エリア分析',
                      description: '周辺環境を総合評価',
                      icon: Icons.location_on,
                      color: Colors.green,
                      onTap: () => _changeTab(2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ログイン状態に応じた追加機能
              if (_currentUser != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        title: '分析履歴',
                        description: '過去の分析結果',
                        icon: Icons.history,
                        color: Colors.purple,
                        onTap: () => _changeTab(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFeatureCard(
                        title: 'マイページ',
                        description: '設定・アカウント管理',
                        icon: Icons.person,
                        color: Colors.orange,
                        onTap: () => _changeTab(4),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _buildFeatureCard(
                  title: 'ログイン・会員登録',
                  description: '履歴保存・個人化分析',
                  icon: Icons.login,
                  color: Colors.orange,
                  onTap: () => _changeTab(3),
                ),
              ],

              const SizedBox(height: 32),

              // ユーザー状態表示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _currentUser != null
                      ? Colors.green[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _currentUser != null
                        ? Colors.green[200]!
                        : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _currentUser != null
                          ? Icons.verified_user
                          : Icons.info_outline,
                      color: _currentUser != null
                          ? Colors.green[600]
                          : Colors.orange[600],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser != null ? 'ログイン済み' : '未ログイン',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _currentUser != null
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentUser != null
                                ? '個人化分析・履歴保存が利用できます'
                                : 'ログインすると分析履歴の保存や個人化分析が利用できます',
                            style: TextStyle(
                              fontSize: 14,
                              color: _currentUser != null
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                          ),
                        ],
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

  /// 機能カードウィジェット
  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color[600],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ログイン画面を構築
  Widget _buildLoginScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン・会員登録'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange[400]!, Colors.orange[600]!],
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
            colors: [Colors.orange[50]!, Colors.white],
          ),
        ),
        child: Center(
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
                      Icon(
                        Icons.login,
                        size: 64,
                        color: Colors.orange[600],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'ログイン・会員登録',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'アカウントを作成すると以下の機能が利用できます：',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.save,
                                  color: Colors.green[600], size: 20),
                              const SizedBox(width: 8),
                              const Text('分析履歴の保存'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.person,
                                  color: Colors.blue[600], size: 20),
                              const SizedBox(width: 8),
                              const Text('個人化された分析'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.settings,
                                  color: Colors.purple[600], size: 20),
                              const SizedBox(width: 8),
                              const Text('好み設定の管理'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'ログイン機能は現在開発中です',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 音声サービスセットアップ
  void _setupAudioService() {
    print('🔊 AudioService: セットアップ開始');
    // 音声サービスの初期化処理（必要に応じて）
  }

  /// タブ変更処理
  void _changeTab(int index) {
    print('📱 タブ変更: $_currentIndex -> $index');

    // 画面が初期化されていない場合は何もしない
    if (_screens.isEmpty) {
      print('⚠️ 画面未初期化のためタブ変更をスキップ');
      return;
    }

    setState(() {
      // 履歴画面から戻る場合のインデックス記憶
      if (_currentIndex == 3 && _currentUser != null) {
        // 現在履歴画面にいる場合は、次のタブを記憶
        if (index != 3) {
          _historyReturnIndex = index;
          return;
        }
      }

      // 履歴画面に戻る場合の処理
      if (_historyReturnIndex != null && index != 3) {
        if (_historyReturnIndex == index) {
          _currentIndex = index;
          _historyReturnIndex = null;
          return;
        }
      }

      _currentIndex = index;
      _historyReturnIndex = null; // リセット

      // カメラ分析タブの場合はリセット
      if (index == 1) {
        print('📷 CameraScreen: リセット');
        _screens[1] = const CameraScreen();
      }

      // エリア分析タブは常にリセット（揮発的表示）
      if (index == 2) {
        print('📍 AreaScreen: リセット');
        _screens[2] = const AreaScreen();
      }
    });
  }

  /// 履歴から再分析への遷移（将来実装用）
  void _navigateToReanalyze(AnalysisHistoryEntry entry) {
    print('🔄 履歴から再分析: ${entry.id}');
    setState(() {
      // カメラ画面を再分析用に更新（将来的にinitialImageUrlを使用）
      _screens[1] = const CameraScreen();

      // カメラタブに移動
      _currentIndex = 1;
    });
  }

  /// ボトムナビゲーションアイテム構築
  List<BottomNavigationBarItem> _buildBottomNavItems() {
    if (_currentUser != null) {
      // ログイン時：5タブ構成
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
          icon: Icon(Icons.history),
          label: '履歴',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'マイページ',
        ),
      ];
    } else {
      // 未ログイン時：4タブ構成
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
        '🏗️ MainTabScreen: build実行 - currentIndex: $_currentIndex, screens: ${_screens.length}');

    // 画面が初期化されていない場合はローディング表示
    if (_screens.isEmpty) {
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
                  '画面を準備中...',
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
      body: _screens.isNotEmpty
          ? IndexedStack(
              index: _currentIndex.clamp(0, _screens.length - 1),
              children: _screens,
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: _screens.isNotEmpty
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex.clamp(0, _screens.length - 1),
              onTap: _changeTab,
              items: _buildBottomNavItems(),
              selectedItemColor: Colors.green[700],
              unselectedItemColor: Colors.grey[600],
              backgroundColor: Colors.white,
              elevation: 8,
            )
          : null,
    );
  }
}
