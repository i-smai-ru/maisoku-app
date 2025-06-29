// lib/screens/area_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Services
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../services/user_preference_service.dart';
import '../services/address_service.dart';

// Models
import '../models/analysis_response_model.dart';
import '../models/user_preference_model.dart';
import '../models/address_model.dart';

// Widgets
import 'widgets/address_input_widget.dart';
import '../screens/widgets/markdown_analysis_result_widget.dart';

// Utils
import '../utils/constants.dart';
import '../utils/api_error_handler.dart';

/// Maisoku AI v1.0: エリア分析画面（1画面完結・段階的認証対応・Markdown表示対応）
///
/// 修正内容：
/// - 状態遷移（AreaAnalysisState）を削除し、1画面完結に変更
/// - 現在地ボタン・住所確定・分析開始の流れを統合
/// - 結果表示エリアを画面下部に固定配置
/// - タブ切り替えコールバックでナビゲーション問題を解決
/// - Markdown形式の分析結果表示に対応
class AreaScreen extends StatefulWidget {
  // タブ切り替え用のコールバック関数を追加
  final VoidCallback? onNavigateToLogin;
  final VoidCallback? onNavigateToMyPage;

  const AreaScreen({
    Key? key,
    this.onNavigateToLogin,
    this.onNavigateToMyPage,
  }) : super(key: key);

  @override
  State<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends State<AreaScreen> {
  // === 認証・段階的分析管理 ===
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _canPersonalize = false;
  String _analysisType = 'basic'; // 'basic' or 'personalized'

  // === データ ===
  String _confirmedAddress = '';
  AreaAnalysisResponse? _analysisResult;
  UserPreferenceModel? _userPreferences;

  // === 状態フラグ ===
  bool _isAnalyzing = false;
  bool _hasConfirmedAddress = false;

  // === Services ===
  final FirestoreService _firestoreService = FirestoreService();
  late final UserPreferenceService _userPreferenceService;
  late final AddressService _addressService;

  @override
  void initState() {
    super.initState();
    print('🗺️ AreaScreen: initState開始 - 1画面完結版（Markdown対応）');

    _userPreferenceService =
        UserPreferenceService(firestoreService: _firestoreService);
    _addressService = AddressService();

    // 🔄 認証状態の初期化・監視
    _setupAuthStateManagement();

    // 初期データ読み込み
    _loadInitialData();
  }

  // === 🔄 認証状態管理（段階的認証対応） ===

  /// 認証状態管理の設定
  void _setupAuthStateManagement() {
    // 初期認証状態の設定
    _updateAuthenticationStatus();

    // 認証状態の変更を監視
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        print('🔐 エリア分析: 認証状態変更 ${user?.uid ?? "ログアウト"}');
        setState(() {
          _currentUser = user;
        });
        _updateAuthenticationStatus();
        _loadUserPreferences(); // 認証状態変更時に好み設定を再読み込み
      }
    });
  }

  /// 認証状態の更新・分析タイプの判定
  void _updateAuthenticationStatus() {
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _currentUser = user;
      _isAuthenticated = user != null;

      // 🎯 個人化分析の可能性をチェック
      _canPersonalize = _isAuthenticated &&
          _userPreferences != null &&
          !_userPreferences!.isEmpty;

      // 分析タイプの決定
      _analysisType = _canPersonalize ? 'personalized' : 'basic';
    });

    print('📊 エリア分析状態更新:');
    print('   🔐 認証済み: $_isAuthenticated');
    print('   🎯 個人化可能: $_canPersonalize');
    print('   📝 分析タイプ: $_analysisType');
  }

  /// 初期データ読み込み
  Future<void> _loadInitialData() async {
    await _loadUserPreferences();
  }

  /// ユーザー好み設定の読み込み
  Future<void> _loadUserPreferences() async {
    if (!_isAuthenticated) {
      setState(() {
        _userPreferences = null;
      });
      _updateAuthenticationStatus();
      return;
    }

    try {
      print('⚙️ ユーザー好み設定読み込み開始...');

      final prefs = await _userPreferenceService.getPreferences();

      if (mounted) {
        setState(() {
          _userPreferences = prefs;
        });
        _updateAuthenticationStatus(); // 好み設定読み込み後に状態更新

        if (prefs != null) {
          print('✅ 好み設定読み込み完了: 個人化分析利用可能');
        } else {
          print('📝 好み設定未設定: 基本分析のみ利用可能');
        }
      }
    } catch (e) {
      print('❌ 好み設定読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _userPreferences = null;
        });
        _updateAuthenticationStatus();
      }
    }
  }

  // === 住所処理 ===

  /// AddressInputWidget からの住所選択コールバック
  void _onAddressSelected(AddressModel addressModel) {
    setState(() {
      _confirmedAddress = addressModel.normalizedAddress;
      _hasConfirmedAddress = true;
      _analysisResult = null; // 前回の結果をクリア
    });

    print('📍 住所確定: $_confirmedAddress');
  }

  /// 分析開始
  void _startAnalysis() {
    if (!_hasConfirmedAddress || _confirmedAddress.isEmpty) {
      _showErrorSnackBar('住所を確定してください');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    _performAreaAnalysis();
  }

  // === 🤖 Cloud Run API分析処理（段階的認証対応） ===

  Future<void> _performAreaAnalysis() async {
    if (_confirmedAddress.isEmpty) {
      _showErrorSnackBar('分析する住所がありません');
      return;
    }

    try {
      print('🤖 エリア分析開始:');
      print('   📍 住所: $_confirmedAddress');
      print('   🔐 認証状態: ${_isAuthenticated ? "ログイン済み" : "未ログイン"}');
      print('   📝 好み設定: ${_userPreferences != null ? "あり" : "なし"}');
      print('   🎯 分析タイプ: $_analysisType');

      // 🔄 段階的認証に対応したAPI呼び出し
      final Map<String, dynamic>? preferences =
          _canPersonalize ? _userPreferences!.toJson() : null;

      final result = await ApiService.analyzeArea(
        address: _confirmedAddress,
        preferences: preferences,
      );

      if (result != null) {
        final analysisResponse = AreaAnalysisResponse.fromJson(result);

        // 🎯 クライアント側の分析タイプ情報を取得
        final clientAnalysisType = result['_clientAnalysisType'] as String?;
        final clientIsAuthenticated =
            result['_clientIsAuthenticated'] as bool? ?? false;
        final clientHasPreferences =
            result['_clientHasPreferences'] as bool? ?? false;

        print('✅ エリア分析完了:');
        print(
            '   📊 サーバー分析タイプ: ${analysisResponse.isPersonalized ? "個人化" : "基本"}');
        print('   🔄 クライアント分析タイプ: $clientAnalysisType');
        print('   🔐 認証状態: $clientIsAuthenticated');
        print('   📝 好み設定: $clientHasPreferences');

        setState(() {
          _analysisResult = analysisResponse;
          _isAnalyzing = false;

          // 実際の分析タイプを更新（サーバーからの応答を優先）
          _analysisType =
              (clientAnalysisType == 'personalized') ? 'personalized' : 'basic';
        });

        // 🎯 使用統計の更新（認証済みユーザーのみ）
        if (_isAuthenticated) {
          try {
            await _firestoreService.incrementUserAnalysisCount(
                _currentUser!.uid, 'area');
            print('📊 エリア分析回数を更新');
          } catch (e) {
            print('⚠️ 使用統計更新エラー: $e');
          }
        }
      } else {
        throw Exception('分析結果が取得できませんでした');
      }
    } catch (e) {
      print('❌ エリア分析エラー: $e');

      setState(() {
        _isAnalyzing = false;
      });

      final errorMessage = ApiErrorHandler.getErrorMessage('area_analysis', e);
      _showErrorSnackBar(errorMessage);
    }
  }

  // === 再分析・リセット ===

  void _retryAnalysis() {
    print('🔄 エリア分析再試行');
    _startAnalysis();
  }

  void _resetAnalysis() {
    print('🔄 エリア分析リセット');
    setState(() {
      _confirmedAddress = '';
      _hasConfirmedAddress = false;
      _analysisResult = null;
      _isAnalyzing = false;
    });
  }

  // === ナビゲーション（修正版） ===

  void _navigateToMyPage() {
    print('📱 マイページへの遷移要求');
    if (widget.onNavigateToMyPage != null) {
      widget.onNavigateToMyPage!();
    } else {
      print('⚠️ onNavigateToMyPage コールバックが設定されていません');
    }
  }

  void _navigateToLogin() {
    print('📱 ログイン画面への遷移要求');
    if (widget.onNavigateToLogin != null) {
      widget.onNavigateToLogin!();
    } else {
      print('⚠️ onNavigateToLogin コールバックが設定されていません');
    }
  }

  // === UI ヘルパー ===

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // === 🎨 UI ビルド ===

  @override
  Widget build(BuildContext context) {
    print('🏗️ AreaScreen: build実行 - 1画面完結版（Markdown対応）');

    return Scaffold(
      appBar: AppBar(
        title: const Text('エリア分析'),
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
        padding: const EdgeInsets.all(AppConstants.PADDING_MEDIUM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.circular(AppConstants.CARD_BORDER_RADIUS),
              ),
              child: Column(
                children: [
                  Icon(Icons.location_on, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'エリア分析',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '住所・駅名で交通・施設を総合分析',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 🔄 段階的認証状態表示
            _buildEnhancedAuthStatusCard(),

            const SizedBox(height: 24),

            // 住所入力ウィジェット（新版使用）
            AddressInputWidget(
              onAddressSelected: _onAddressSelected,
              addressService: _addressService,
              hintText: '住所・駅名・ランドマークを入力',
            ),

            const SizedBox(height: 16),

            // 分析開始ボタン（住所確定後に表示）
            if (_hasConfirmedAddress) ...[
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _startAnalysis,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _canPersonalize
                              ? Icons.verified_user
                              : Icons.analytics,
                          size: 24),
                  label: Text(
                    _isAnalyzing
                        ? '分析中...'
                        : (_canPersonalize ? '個人化分析を開始' : '基本分析を開始'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canPersonalize ? Colors.green[600] : Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.BUTTON_BORDER_RADIUS),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 確定済み住所表示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '確定済み: $_confirmedAddress',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: _resetAnalysis,
                      tooltip: '住所を変更',
                      color: Colors.green[600],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 🔒 個人化分析の案内（未ログイン・設定なし時）
            if (!_canPersonalize) _buildPersonalizationPromotionCard(),

            const SizedBox(height: 24),

            // === 結果表示エリア（固定） ===
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.grey[700], size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '分析結果',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isAnalyzing) ...[
                    // 分析中表示
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _canPersonalize ? '個人化AI分析中...' : '基本AI分析中...',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _canPersonalize
                                ? 'あなたの好み設定を反映して分析しています'
                                : '一般的な観点から客観的に分析しています',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else if (_analysisResult != null) ...[
                    // 分析結果表示（Markdown対応版）
                    _buildAnalysisResultCard(),
                  ] else ...[
                    // 初期状態
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off,
                              color: Colors.grey[400], size: 64),
                          const SizedBox(height: 16),
                          Text(
                            '住所を入力して分析を開始してください',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // === 🎨 UIコンポーネント ===

  /// 🔄 強化された認証状態カード
  Widget _buildEnhancedAuthStatusCard() {
    Color cardColor;
    Color iconColor;
    Color textColor;
    IconData icon;
    String title;
    String description;

    if (!_isAuthenticated) {
      cardColor = Colors.orange[50]!;
      iconColor = Colors.orange[600]!;
      textColor = Colors.orange[800]!;
      icon = Icons.info_outline;
      title = '基本分析モード（未ログイン）';
      description = '一般的な観点から客観的な住環境分析を提供します。';
    } else if (!_canPersonalize) {
      cardColor = Colors.blue[50]!;
      iconColor = Colors.blue[600]!;
      textColor = Colors.blue[800]!;
      icon = Icons.settings;
      title = '基本分析モード（好み設定なし）';
      description = 'ログイン済みですが、好み設定を行うと個人化分析が利用できます。';
    } else {
      cardColor = Colors.green[50]!;
      iconColor = Colors.green[600]!;
      textColor = Colors.green[800]!;
      icon = Icons.verified_user;
      title = '個人化分析モード';
      description = 'あなたの好み設定を反映した個人化された分析を実行します。';
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.8),
              ),
            ),

            // アクションボタン
            if (!_isAuthenticated || !_canPersonalize) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!_isAuthenticated) {
                      _navigateToLogin();
                    } else {
                      _navigateToMyPage();
                    }
                  },
                  icon: Icon(!_isAuthenticated ? Icons.login : Icons.settings),
                  label: Text(
                    !_isAuthenticated ? 'ログインして個人化分析を利用' : '好み設定で個人化分析を有効化',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 🔒 個人化分析促進カード
  Widget _buildPersonalizationPromotionCard() {
    if (_isAuthenticated && _userPreferences == null) {
      // ログイン済み・好み設定なし
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  '好み設定で個人化分析を有効化',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'マイページで好み設定を行うと、あなたの価値観に合わせた個人化分析が利用できます。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _navigateToMyPage,
              icon: const Icon(Icons.settings),
              label: const Text('好み設定を行う'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else if (!_isAuthenticated) {
      // 未ログイン
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.login, color: Colors.orange[600]),
                const SizedBox(width: 8),
                const Text(
                  'ログインして個人化分析を利用',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'ログインして好み設定を行うと、あなたの価値観に合わせた個人化分析が利用できます。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _navigateToLogin,
              icon: const Icon(Icons.login),
              label: const Text('ログインする'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// 分析結果カード（Markdown対応版）
  Widget _buildAnalysisResultCard() {
    final bool isActuallyPersonalized = _analysisType == 'personalized';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Markdown対応の分析結果表示
        MarkdownAnalysisResultWidget(
          markdownText: _analysisResult!.analysis,
          isPersonalized: isActuallyPersonalized,
        ),

        const SizedBox(height: 16),

        // データ情報
        if (_analysisResult!.facilityCount != null ||
            _analysisResult!.transportCount != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'データ分析情報',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text('処理時間: ${_analysisResult!.formattedProcessingTime}'),
                Text('分析タイプ: ${isActuallyPersonalized ? "個人化分析" : "基本分析"}'),
                if (_analysisResult!.facilityCount != null)
                  Text('発見施設数: ${_analysisResult!.facilityCount}件'),
                if (_analysisResult!.transportCount != null)
                  Text('交通手段数: ${_analysisResult!.transportCount}件'),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // アクションボタン
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _retryAnalysis,
                icon: const Icon(Icons.refresh),
                label: const Text('再分析'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetAnalysis,
                icon: const Icon(Icons.edit_location),
                label: const Text('別の住所'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[600],
                  side: BorderSide(color: Colors.green[300]!),
                ),
              ),
            ),
          ],
        ),

        // 個人化分析への案内（基本分析時のみ）
        if (!isActuallyPersonalized) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.upgrade, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      '個人化分析にアップグレード',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isAuthenticated
                      ? 'マイページで好み設定を行うと、あなたの価値観に合わせた詳細な分析を提供します。'
                      : 'ログインして好み設定を行うと、あなたの価値観に合わせた詳細な分析を提供します。',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed:
                      _isAuthenticated ? _navigateToMyPage : _navigateToLogin,
                  icon: Icon(_isAuthenticated ? Icons.settings : Icons.login),
                  label: Text(_isAuthenticated ? '好み設定を行う' : 'ログインして個人化分析'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
