// lib/screens/history_screen.dart - 画像表示・その場再分析対応版

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

/// Maisoku AI v1.0: カメラ分析履歴専用画面（画像表示・その場再分析対応版）
///
/// 機能追加：
/// - 履歴に画像表示
/// - その場での再分析機能
/// - 任意保存機能
/// - 正確な履歴件数表示
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

  // 再分析関連
  bool _isReanalyzing = false;
  String? _reanalyzingEntryId;
  String? _reanalysisResult;

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

      if (mounted) {
        setState(() {
          _analysisHistory = history;
          _totalCount = history.length; // 実際の履歴数を使用
          _isLoading = false;
        });
      }

      print('✅ 履歴読み込み完了: ${history.length}件');
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

  /// その場再分析機能
  Future<void> _performReanalysis(AnalysisHistoryEntry entry) async {
    if (_isReanalyzing) return;

    setState(() {
      _isReanalyzing = true;
      _reanalyzingEntryId = entry.id;
      _reanalysisResult = null;
    });

    try {
      print('🔄 その場再分析開始: ${entry.id}');

      // API呼び出しで再分析実行
      final analysisResult = await _apiService.analyzeCameraImage(
        imageUrl: entry.imageURL,
        preferences: '', // 現在の好み設定を取得する場合は追加実装
      );

      if (mounted) {
        setState(() {
          _reanalysisResult =
              analysisResult['analysisText'] ?? '分析結果を取得できませんでした';
        });

        _showSuccessSnackBar('再分析が完了しました');

        // 再分析結果を表示するダイアログを開く
        _showReanalysisResultDialog(entry, _reanalysisResult!);
      }
    } catch (e) {
      print('❌ 再分析エラー: $e');
      if (mounted) {
        _showErrorSnackBar('再分析に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReanalyzing = false;
          _reanalyzingEntryId = null;
        });
      }
    }
  }

  /// 再分析結果を保存
  Future<void> _saveReanalysisResult(
      AnalysisHistoryEntry originalEntry, String newAnalysisText) async {
    try {
      // 新しい履歴エントリを作成
      final newEntry = AnalysisHistoryEntry.fromCameraAnalysis(
        userId: widget.currentUser.uid,
        analysisText: newAnalysisText,
        imageURL: originalEntry.imageURL, // 同じ画像を使用
        isPersonalized: originalEntry.isPersonalized,
        preferenceSnapshot: originalEntry.preferenceSnapshot,
      );

      // Firestoreに保存
      await widget.firestoreService.saveAnalysisHistory(
        widget.currentUser.uid,
        newEntry,
      );

      // 履歴を再読み込み
      await _loadAnalysisHistory();

      if (mounted) {
        _showSuccessSnackBar('再分析結果を保存しました');
      }
    } catch (e) {
      print('❌ 再分析結果保存エラー: $e');
      if (mounted) {
        _showErrorSnackBar('保存に失敗しました: $e');
      }
    }
  }

  /// 再分析結果表示ダイアログ
  void _showReanalysisResultDialog(
      AnalysisHistoryEntry originalEntry, String newAnalysisText) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
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
                          Icon(Icons.refresh,
                              color: Colors.green[600], size: 24),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '再分析結果',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '元の分析: ${originalEntry.formattedDate}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // 内容
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🆕 新しい分析結果:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Text(
                            newAnalysisText,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '📄 元の分析結果:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            originalEntry.analysisTextFull,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // アクションボタン
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.audioService.speak(newAnalysisText);
                          },
                          icon: const Icon(Icons.volume_up),
                          label: const Text('読み上げ'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _saveReanalysisResult(
                                originalEntry, newAnalysisText);
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('結果を保存'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
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
      },
    );
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

  /// 履歴エントリカードを構築（画像表示対応）
  Widget _buildHistoryCard(AnalysisHistoryEntry entry) {
    final isCurrentlyReanalyzing =
        _isReanalyzing && _reanalyzingEntryId == entry.id;

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

              // 画像と分析内容の行
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 画像サムネイル
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: entry.hasValidImage
                          ? CachedNetworkImage(
                              imageUrl: entry.imageURL,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey[600],
                                  size: 32,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.image_not_supported,
                              color: Colors.grey[600],
                              size: 32,
                            ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 分析内容プレビュー
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displaySummary,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // 日時
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // アクションボタン行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 音声読み上げ
                  _buildActionButton(
                    icon: Icons.volume_up,
                    label: '読み上げ',
                    onPressed: () => _speakAnalysis(entry),
                    color: Colors.blue[600]!,
                  ),
                  // その場再分析
                  _buildActionButton(
                    icon: isCurrentlyReanalyzing
                        ? Icons.hourglass_empty
                        : Icons.refresh,
                    label: isCurrentlyReanalyzing ? '分析中...' : '再分析',
                    onPressed: isCurrentlyReanalyzing
                        ? null
                        : () => _performReanalysis(entry),
                    color: Colors.green[600]!,
                  ),
                  // 削除
                  _buildActionButton(
                    icon: Icons.delete,
                    label: '削除',
                    onPressed: () => _deleteHistoryEntry(entry),
                    color: Colors.red[600]!,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// アクションボタンを構築
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
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
            constraints: const BoxConstraints(maxWidth: 500),
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

                // 画像表示
                if (entry.hasValidImage) ...[
                  Container(
                    width: double.infinity,
                    height: 200,
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: entry.imageURL,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey[600],
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // 内容
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                          _performReanalysis(entry);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('再分析'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                        ),
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
                  if (_isReanalyzing) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '再分析中...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
