import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class MainTestScreen extends StatefulWidget {
  @override
  _MainTestScreenState createState() => _MainTestScreenState();
}

class _MainTestScreenState extends State<MainTestScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  // API テスト用状態
  String _connectionStatus = '未テスト';
  String _healthStatus = '未テスト';
  String _helloMessage = '';

  // 認証テスト用状態
  String _authStatus = '未ログイン';
  String _authRequiredResult = '未テスト';
  String _optionalAuthResult = '未テスト';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _updateAuthStatus();

    // 認証状態の変更を監視
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _updateAuthStatus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateAuthStatus() {
    final user = _authService.currentUser;
    setState(() {
      _authStatus = user != null ? 'ログイン済み: ${user.email}' : '未ログイン';
    });
  }

  Color _getStatusColor(String status) {
    if (status.contains('成功') ||
        status.contains('healthy') ||
        status.contains('✅')) {
      return Colors.green;
    } else if (status.contains('失敗') ||
        status.contains('エラー') ||
        status.contains('❌')) {
      return Colors.red;
    } else if (status.contains('テスト中')) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  // 基本API接続テスト
  Future<void> _runBasicTest() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'テスト中...';
      _healthStatus = 'テスト中...';
      _helloMessage = '';
    });

    print('🚀 基本API接続テスト開始');
    ApiConfig.printConfig();

    // 1. ネットワーク接続テスト
    final networkResult = await ApiService.testConnectivity();
    setState(() {
      _connectionStatus = networkResult ? 'ネットワーク接続成功' : 'ネットワーク接続失敗';
    });

    if (!networkResult) {
      setState(() {
        _isLoading = false;
        _healthStatus = 'ネットワーク未接続のためスキップ';
      });
      return;
    }

    // 2. ヘルスチェック
    final healthResult = await ApiService.healthCheck();
    setState(() {
      _healthStatus = healthResult != null
          ? 'API接続成功: ${healthResult['status']}'
          : 'API接続失敗';
    });

    // 3. Hello World メッセージ取得
    if (healthResult != null) {
      final helloResult = await ApiService.getHelloWorld();
      setState(() {
        _helloMessage = helloResult ?? 'メッセージ取得失敗';
      });
    }

    setState(() {
      _isLoading = false;
    });

    print('✅ 基本API接続テスト完了');
  }

  // Google サインイン
  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _authService.signInWithGoogle();

    setState(() {
      _isLoading = false;
    });

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ログイン成功！ ${result.user?.email}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ログインに失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // サインアウト
  Future<void> _signOut() async {
    await _authService.signOut();
    setState(() {
      _authRequiredResult = '未テスト';
      _optionalAuthResult = '未テスト';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ログアウト完了'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // 認証必須APIテスト
  Future<void> _testAuthRequired() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.testAuthRequired();
      setState(() {
        _authRequiredResult =
            result != null ? '✅ ${result['message']}' : '❌ 認証エラー';
      });
    } catch (e) {
      setState(() {
        _authRequiredResult = '❌ $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  // 段階的認証APIテスト
  Future<void> _testOptionalAuth() async {
    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.testOptionalAuth();

    setState(() {
      _isLoading = false;
      _optionalAuthResult = result != null
          ? '✅ ${result['message']} (個人化: ${result['is_personalized']})'
          : '❌ APIエラー';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Maisoku API 認証テスト'),
        backgroundColor: Colors.blue[100],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🌐 基本API'),
            Tab(text: '🔐 認証テスト'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicTestTab(),
          _buildAuthTestTab(),
        ],
      ),
    );
  }

  Widget _buildBasicTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // API情報カード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('API設定情報',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildInfoRow('🌐 Base URL', ApiConfig.baseUrl),
                  _buildInfoRow('💊 Health', ApiConfig.healthEndpoint),
                  _buildInfoRow('👋 Hello', ApiConfig.helloEndpoint),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ステータスカード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('接続ステータス',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildStatusRow('ネットワーク', _connectionStatus),
                  _buildStatusRow('API Health', _healthStatus),
                  if (_helloMessage.isNotEmpty)
                    _buildStatusRow('メッセージ', _helloMessage),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // テストボタン
          ElevatedButton(
            onPressed: _isLoading ? null : _runBasicTest,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('接続テスト実行中...'),
                    ],
                  )
                : const Text('🚀 基本API接続テスト実行',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 認証状態カード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('認証状態',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_authStatus, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 認証ボタン
          if (_authService.currentUser == null)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _signIn,
              icon: const Icon(Icons.login),
              label: const Text('Googleでログイン'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[100],
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

          const SizedBox(height: 24),

          // 段階的認証APIテスト
          ElevatedButton(
            onPressed: _isLoading ? null : _testOptionalAuth,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('🔓 段階的認証API テスト'),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(_optionalAuthResult,
                  style:
                      TextStyle(color: _getStatusColor(_optionalAuthResult))),
            ),
          ),

          const SizedBox(height: 16),

          // 認証必須APIテスト
          ElevatedButton(
            onPressed: _isLoading ? null : _testAuthRequired,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('🔐 認証必須API テスト'),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(_authRequiredResult,
                  style:
                      TextStyle(color: _getStatusColor(_authRequiredResult))),
            ),
          ),

          const SizedBox(height: 24),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey[700])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                color: _getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
