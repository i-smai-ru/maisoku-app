import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'config/api_config.dart';

void main() {
  runApp(MaisokuApp());
}

class MaisokuApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maisoku API テスト',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: ApiTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ApiTestScreen extends StatefulWidget {
  @override
  _ApiTestScreenState createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  String _connectionStatus = '未テスト';
  String _healthStatus = '未テスト';
  String _helloMessage = '';
  bool _isLoading = false;
  bool _networkConnected = false;

  Color _getStatusColor(String status) {
    if (status.contains('成功') || status.contains('healthy')) {
      return Colors.green;
    } else if (status.contains('失敗') || status.contains('エラー')) {
      return Colors.red;
    } else if (status.contains('テスト中')) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  // 全体テスト実行
  Future<void> _runFullTest() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'テスト中...';
      _healthStatus = 'テスト中...';
      _helloMessage = '';
    });

    // 1. ネットワーク接続テスト
    print('🚀 API接続テスト開始');
    ApiConfig.printConfig();

    final networkResult = await ApiService.testConnectivity();
    setState(() {
      _networkConnected = networkResult;
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

    print('✅ API接続テスト完了');
  }

  // 個別ヘルスチェック
  Future<void> _runHealthCheck() async {
    setState(() {
      _healthStatus = 'テスト中...';
    });

    final result = await ApiService.healthCheck();
    setState(() {
      _healthStatus =
          result != null ? 'API接続成功: ${result['status']}' : 'API接続失敗';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Maisoku API 接続テスト'),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API情報カード
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API設定情報',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    SizedBox(height: 12),
                    _buildInfoRow('🌐 Base URL', ApiConfig.baseUrl),
                    _buildInfoRow('💊 Health Check', ApiConfig.healthEndpoint),
                    _buildInfoRow('👋 Hello World', ApiConfig.helloEndpoint),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // ステータスカード
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '接続ステータス',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    SizedBox(height: 12),
                    _buildStatusRow('ネットワーク', _connectionStatus),
                    _buildStatusRow('API Health', _healthStatus),
                    if (_helloMessage.isNotEmpty)
                      _buildStatusRow('メッセージ', _helloMessage),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // テストボタン
            ElevatedButton(
              onPressed: _isLoading ? null : _runFullTest,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('接続テスト実行中...'),
                      ],
                    )
                  : Text(
                      '🚀 フル接続テスト実行',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),

            SizedBox(height: 12),

            // 個別テストボタン
            OutlinedButton(
              onPressed: _isLoading ? null : _runHealthCheck,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('💊 ヘルスチェックのみ'),
            ),

            SizedBox(height: 24),

            // デバッグ情報
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'デバッグ情報',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ログ詳細はデバッグコンソールで確認できます。\n'
                      'VS Code: Debug Console タブ\n'
                      'Xcode: Console ログ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String status) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
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
