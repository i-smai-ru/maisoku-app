// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../models/analysis_history_entry.dart';

/// Maisoku AI v1.0: カメラ分析履歴専用画面
///
/// 機能分離対応：
/// - エリア分析は履歴保存なし（揮発的表示）
/// - カメラ分析のみ履歴表示・管理
/// - 再分析・削除・音声読み上げ機能
class HistoryScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final User currentUser;
  final Function(AnalysisHistoryEntry) onReanalyze;
  final AudioService audioService;

  const HistoryScreen({
    Key? key,
    required this.firestoreService,
    required this.currentUser,
    required this.onReanalyze,
    required this.audioService,
  }) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  List<AnalysisHistoryEntry> _analysisHistory = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _totalCount = 0;
  String _errorMessage = '';

  // サービス
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAnalysisHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // アプリがフォアグラウンドに戻った時に履歴をリロード
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshHistory();
    }
  }

  // 画面が表示される度に履歴をリロード
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted && _analysisHistory.isEmpty) {
      _loadAnalysisHistory();
    }
  }

  /// 履歴を読み込み
  Future<void> _loadAnalysisHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // カメラ分析履歴のみ取得
      final history = await widget.firestoreService
          .getAnalysisHistory(widget.currentUser.uid);

      // 総件数も取得
      final count = await widget.firestoreService
          .getAnalysisHistoryCount(widget.currentUser.uid);

      if (mounted) {
        setState(() {
          _analysisHistory = history;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ カメラ分析履歴読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '履歴の読み込みに失敗しました';
        });
        _showErrorSnackBar('履歴の読み込みに失敗しました: $e');
      }
    }
  }

  /// 履歴を更新（リフレッシュ）
  Future<void> _refreshHistory() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadAnalysisHistory();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// 履歴エントリを削除
  Future<void> _deleteHistoryEntry(AnalysisHistoryEntry entry) async {
    // 確認ダイアログ
    final bool? shouldDelete = await _showDeleteConfirmationDialog(entry);
    if (shouldDelete != true) return;

    try {
      // Firestoreから履歴を削除
      await widget.firestoreService
          .deleteAnalysisHistory(widget.currentUser.uid, entry.id);

      // Firebase Storageから画像を削除
      if (entry.imageURL.isNotEmpty) {
        try {
          await _storageService.deleteAnalysisImage(entry.imageURL);
        } catch (e) {
          print('⚠️ 画像削除エラー（継続）: $e');
        }
      }

      // 削除後に履歴を再読み込み
      await _loadAnalysisHistory();

      if (mounted) {
        _showSuccessSnackBar('カメラ分析履歴を削除しました');
      }
    } catch (e) {
      print('❌ 履歴削除エラー: $e');
      if (mounted) {
        _showErrorSnackBar('削除に失敗しました: $e');
      }
    }
  }

  /// 再分析を実行
  Future<void> _reanalyzeEntry(AnalysisHistoryEntry entry) async {
    // カメラ画面に遷移して再分析
    widget.onReanalyze(entry);
  }

  /// 分析結果を音声読み上げ
  Future<void> _speakAnalysis(AnalysisHistoryEntry entry) async {
    try {
      await widget.audioService.speak(entry.analysisTextFull);
    } catch (e) {
      print('❌ 音声読み上げエラー: $e');
      _showErrorSnackBar('音声読み上げに失敗しました');
    }
  }

  /// 削除確認ダイアログ
  Future<bool?> _showDeleteConfirmationDialog(AnalysisHistoryEntry entry) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('履歴を削除'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('この分析履歴を削除しますか？'),
              const SizedBox(height: 8),
              Text(
                '分析日時: ${entry.formattedDate}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.displaySummary,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('削除'),
            ),
          ],
        );
      },
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

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 履歴エントリカードを構築
  Widget _buildHistoryCard(AnalysisHistoryEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showHistoryDetailDialog(entry),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー行
              Row(
                children: [
                  // 分析タイプアイコン
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: entry.isPersonalized
                          ? Colors.green[100]
                          : Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          entry.isPersonalized ? Icons.person : Icons.public,
                          size: 14,
                          color: entry.isPersonalized
                              ? Colors.green[700]
                              : Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.analysisTypeDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: entry.isPersonalized
                                ? Colors.green[700]
                                : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 処理時間
                  if (entry.processingTimeSeconds != null)
                    Text(
                      entry.processingTimeDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // 分析内容プレビュー
              Text(
                entry.displaySummary,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // フッター行
              Row(
                children: [
                  // 日時
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  // アクションボタン
                  _buildActionButtons(entry),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// アクションボタンを構築
  Widget _buildActionButtons(AnalysisHistoryEntry entry) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 音声読み上げ
        IconButton(
          onPressed: () => _speakAnalysis(entry),
          icon: const Icon(Icons.volume_up),
          tooltip: '音声読み上げ',
          iconSize: 20,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
        // 再分析
        IconButton(
          onPressed: () => _reanalyzeEntry(entry),
          icon: const Icon(Icons.refresh),
          tooltip: '再分析',
          iconSize: 20,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
        // 削除
        IconButton(
          onPressed: () => _deleteHistoryEntry(entry),
          icon: const Icon(Icons.delete),
          tooltip: '削除',
          iconSize: 20,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
      ],
    );
  }

  /// 履歴詳細ダイアログ
  void _showHistoryDetailDialog(AnalysisHistoryEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: entry.isPersonalized
                        ? Colors.green[50]
                        : Colors.blue[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            entry.analysisTypeDisplay,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: entry.isPersonalized
                                  ? Colors.green[800]
                                  : Colors.blue[800],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.detailedFormattedDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),

                // 内容
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      entry.analysisTextFull,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

                // アクションボタン
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _speakAnalysis(entry);
                        },
                        icon: const Icon(Icons.volume_up),
                        label: const Text('読み上げ'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _reanalyzeEntry(entry);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('再分析'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 空の状態ウィジェット
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'カメラ分析履歴がありません',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'カメラタブで物件写真を分析すると\nここに履歴が保存されます',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // カメラタブに移動（main.dartでハンドリング）
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('カメラ分析を開始'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カメラ分析履歴'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[400]!, Colors.blue[600]!],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshHistory,
            tooltip: '履歴を更新',
          ),
        ],
      ),
      body: Column(
        children: [
          // ヘッダー
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[400]!, Colors.blue[600]!],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'カメラ分析履歴',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '保存された分析: $_totalCount件',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // メインコンテンツ
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadAnalysisHistory,
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      )
                    : _analysisHistory.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _refreshHistory,
                            child: ListView.builder(
                              itemCount: _analysisHistory.length,
                              itemBuilder: (context, index) {
                                return _buildHistoryCard(
                                    _analysisHistory[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
