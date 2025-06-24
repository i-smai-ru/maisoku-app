// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/api_config.dart';
import 'services/api_service.dart';
import 'services/firestore_service.dart';
import 'services/audio_service.dart';
import 'services/auth_check_service.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/area_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/my_page_screen.dart';
import 'models/analysis_history_entry.dart';

/// Maisoku AI v1.0 - メインアプリケーション
///
/// 機能分離対応：
/// - カメラ分析: 履歴保存あり（認証必須）
/// - エリア分析: 揮発的表示（段階的認証）
/// - 動的タブ構成: 認証状態による5タブ/4タブ切り替え
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase初期化
  await Firebase.initializeApp();

  // API設定検証
  final configErrors = ApiConfig.validateConfiguration();
  if (configErrors.isNotEmpty) {
    print('⚠️ 設定エラーが検出されました:');
    for (final error in configErrors) {
      print('   - $error');
    }
    print('   api_config.dartでAPIキーを設定してください');
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
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 24),
                Text(
                  'Maisoku AI',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'あなたの住まい選びを科学的にサポート',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Text(
                  '初期化中...',
                  style: TextStyle(
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

  /// 画面初期化
  void _initializeScreens() {
    List<Widget> newScreens = [];

    // 1. ホーム画面（常に存在）
    newScreens.add(HomeScreen(onTabChange: _changeTab));

    // 2. カメラ分析画面（常に存在）
    newScreens.add(CameraScreen(
      apiService: ApiService(),
      audioService: _audioService,
      initialImage: null,
    ));

    // 3. エリア分析画面（常に存在）
    newScreens.add(AreaScreen(
      apiService: ApiService(),
      audioService: _audioService,
    ));

    if (_currentUser != null) {
      // ログイン時：5タブ構成

      // 4. 履歴画面（カメラ分析履歴のみ）
      newScreens.add(HistoryScreen(
        firestoreService: _firestoreService,
        currentUser: _currentUser!,
        onReanalyze: _navigateToReanalyze,
        audioService: _audioService,
      ));

      // 5. マイページ画面
      newScreens.add(MyPageScreen(
        firestoreService: _firestoreService,
        currentUser: _currentUser,
        audioService: _audioService,
      ));
    } else {
      // 未ログイン時：4タブ構成

      // 4. ログイン画面
      newScreens.add(LoginScreen(
        onLoginSuccess: () {
          // ログイン成功後の処理はauthStateChangesで自動処理
        },
      ));
    }

    _screens = newScreens;
  }

  /// 音声サービスセットアップ
  void _setupAudioService() {
    // 音声サービスの初期化処理（必要に応じて）
  }

  /// タブ変更処理
  void _changeTab(int index) {
    // 画面が初期化されていない場合は何もしない
    if (_screens.isEmpty) return;

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

      // カメラ分析タブの場合は初期画像なしでリセット
      if (index == 1) {
        _screens[1] = CameraScreen(
          apiService: ApiService(),
          audioService: _audioService,
          initialImage: null,
        );
      }

      // エリア分析タブは常にリセット（揮発的表示）
      if (index == 2) {
        _screens[2] = AreaScreen(
          apiService: ApiService(),
          audioService: _audioService,
        );
      }
    });
  }

  /// 履歴から再分析への遷移
  void _navigateToReanalyze(AnalysisHistoryEntry entry) {
    setState(() {
      // カメラ画面を再分析用に更新
      _screens[1] = CameraScreen(
        apiService: ApiService(),
        audioService: _audioService,
        initialImage: null, // 画像は履歴から復元
        reanalysisEntry: entry,
      );

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
