// lib/screens/area_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Services
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../services/user_preference_service.dart';

// Models
import '../models/analysis_response_model.dart';
import '../models/user_preference_model.dart';

// Widgets
import 'widgets/address_input_widget.dart';
import 'widgets/progress_indicator_widget.dart';

// Utils
import '../utils/constants.dart';
import '../utils/api_error_handler.dart';
import '../utils/address_validator.dart';

enum AreaAnalysisState {
  addressInput, // 住所入力
  addressConfirm, // 住所確認
  analyzing, // Cloud Run API分析中
  results, // 結果表示
}

class AreaScreen extends StatefulWidget {
  const AreaScreen({Key? key}) : super(key: key);

  @override
  State<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends State<AreaScreen> {
  // === 状態管理 ===
  AreaAnalysisState _currentState = AreaAnalysisState.addressInput;

  // === データ ===
  String _inputAddress = '';
  String _confirmedAddress = '';
  AreaAnalysisResponse? _analysisResult;
  UserPreferenceModel? _userPreferences;

  // === フラグ ===
  bool _isAnalyzing = false;
  bool _isPersonalized = false; // 段階的認証の結果

  // === Services ===
  final FirestoreService _firestoreService = FirestoreService();
  late final UserPreferenceService _userPreferenceService;

  @override
  void initState() {
    super.initState();

    _userPreferenceService =
        UserPreferenceService(firestoreService: _firestoreService);

    _loadUserPreferences();
    _updatePersonalizationStatus();

    // 認証状態の監視
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        _updatePersonalizationStatus();
        _loadUserPreferences();
      }
    });
  }

  // === 初期化・設定 ===

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await _userPreferenceService.getPreferences();
      setState(() {
        _userPreferences = prefs;
      });
    } catch (e) {
      print('好み設定読み込みエラー: $e');
      // エラーでも継続（好み設定なしで基本分析）
    }
  }

  void _updatePersonalizationStatus() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isPersonalized = user != null;
    });
  }

  // === 住所処理 ===

  void _onAddressInput(String address) {
    setState(() {
      _inputAddress = address.trim();
    });
  }

  void _onAddressConfirm() {
    if (_inputAddress.isEmpty) {
      _showErrorSnackBar('住所を入力してください');
      return;
    }

    if (!AddressValidator.isValidInput(_inputAddress)) {
      _showErrorSnackBar('有効な住所を入力してください');
      return;
    }

    setState(() {
      _confirmedAddress = _inputAddress;
      _currentState = AreaAnalysisState.addressConfirm;
    });
  }

  void _startAnalysis() {
    setState(() {
      _currentState = AreaAnalysisState.analyzing;
      _isAnalyzing = true;
      _analysisResult = null;
    });

    _performAreaAnalysis();
  }

  void _editAddress() {
    setState(() {
      _currentState = AreaAnalysisState.addressInput;
    });
  }

  // === Cloud Run API分析処理 ===

  Future<void> _performAreaAnalysis() async {
    if (_confirmedAddress.isEmpty) {
      _showErrorSnackBar('分析する住所がありません');
      return;
    }

    try {
      // Cloud Run API でエリア分析（段階的認証）
      final result = await ApiService.analyzeArea(
        address: _confirmedAddress,
        preferences: _userPreferences?.toJson(),
      );

      if (result != null) {
        final analysisResponse = AreaAnalysisResponse.fromJson(result);

        setState(() {
          _analysisResult = analysisResponse;
          _currentState = AreaAnalysisState.results;
          _isAnalyzing = false;
        });
      } else {
        throw Exception('分析結果が取得できませんでした');
      }
    } catch (e) {
      setState(() {
        _currentState = AreaAnalysisState.addressConfirm;
        _isAnalyzing = false;
      });

      final errorMessage = ApiErrorHandler.getErrorMessage('area_analysis', e);
      _showErrorSnackBar(errorMessage);
    }
  }

  // === 再分析・リセット ===

  void _retryAnalysis() {
    _startAnalysis();
  }

  void _resetAnalysis() {
    setState(() {
      _currentState = AreaAnalysisState.addressInput;
      _inputAddress = '';
      _confirmedAddress = '';
      _analysisResult = null;
      _isAnalyzing = false;
    });
  }

  // === ナビゲーション ===

  void _navigateToMyPage() {
    // 安全なマイページ遷移
    Navigator.pushNamed(context, '/my_page');
  }

  void _navigateToLogin() {
    // 安全なログイン画面遷移
    Navigator.pushNamed(context, '/login');
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

  // === UI ビルド ===

  @override
  Widget build(BuildContext context) {
    switch (_currentState) {
      case AreaAnalysisState.addressInput:
        return _buildAddressInputState();
      case AreaAnalysisState.addressConfirm:
        return _buildAddressConfirmState();
      case AreaAnalysisState.analyzing:
        return _buildAnalyzingState();
      case AreaAnalysisState.results:
        return _buildResultsState();
    }
  }

  Widget _buildAddressInputState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('エリア分析'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.PADDING_MEDIUM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),

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

            // 段階的認証状態表示
            _buildAuthStatusCard(),

            const SizedBox(height: 24),

            // 住所入力
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_location, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        const Text(
                          '住所・駅名を入力',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: _onAddressInput,
                      decoration: const InputDecoration(
                        hintText: '例: 東京都渋谷区、渋谷駅',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _inputAddress.isNotEmpty ? _onAddressConfirm : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('分析開始'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 機能説明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius:
                    BorderRadius.circular(AppConstants.CARD_BORDER_RADIUS),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.green[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'エリア分析でわかること',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• 最寄り駅・バス停の交通アクセス\n'
                    '• 商業・医療・教育施設の充実度\n'
                    '• 生活利便性の総合評価\n'
                    '${_isPersonalized ? '• あなたの好みに合わせた個人化分析' : '• 一般的な観点からの客観的分析'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressConfirmState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('住所確認'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _editAddress,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.PADDING_MEDIUM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),

            // 住所確認
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        const Text(
                          '分析対象住所',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _confirmedAddress,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 分析タイプ表示
            _buildAnalysisTypeCard(),

            const SizedBox(height: 32),

            // アクションボタン
            ElevatedButton.icon(
              onPressed: _startAnalysis,
              icon: const Icon(Icons.analytics, size: 24),
              label: Text(
                _isPersonalized ? '個人化分析を開始' : '基本分析を開始',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor:
                    _isPersonalized ? Colors.green[600] : Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.BUTTON_BORDER_RADIUS),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 住所編集ボタン
            OutlinedButton.icon(
              onPressed: _editAddress,
              icon: const Icon(Icons.edit),
              label: const Text('住所を編集'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析中'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _currentState = AreaAnalysisState.addressConfirm;
              _isAnalyzing = false;
            });
          },
        ),
      ),
      body: Center(
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
                    const CircularProgressIndicator(strokeWidth: 3),
                    const SizedBox(height: 24),
                    Text(
                      _isPersonalized ? '個人化AI分析中...' : '基本AI分析中...',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cloud Run APIで${_isPersonalized ? '個人化' : '基本'}エリア分析を実行中',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 分析対象住所表示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        const Text('分析中の住所',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_confirmedAddress,
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsState() {
    if (_analysisResult == null) {
      return _buildAnalyzingState();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('分析結果'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _resetAnalysis,
        ),
        actions: [
          IconButton(
            onPressed: _retryAnalysis,
            icon: const Icon(Icons.refresh),
            tooltip: '再分析',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.PADDING_MEDIUM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 分析情報ヘッダー
            _buildAnalysisInfoCard(),

            const SizedBox(height: 16),

            // 分析対象住所
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        const Text(
                          '分析対象住所',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_confirmedAddress,
                        style: const TextStyle(fontSize: 16)),
                    if (_analysisResult!.hasValidLocation)
                      Text(
                        '位置: ${_analysisResult!.latitude!.toStringAsFixed(4)}, ${_analysisResult!.longitude!.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // メイン分析結果
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isPersonalized
                              ? Icons.verified_user
                              : Icons.description,
                          color: _isPersonalized
                              ? Colors.green[600]
                              : Colors.blue[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPersonalized ? '個人化AI分析結果' : '基本AI分析結果',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _analysisResult!.analysis,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // データ充実度表示
            if (_analysisResult!.facilityCount != null ||
                _analysisResult!.transportCount != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.data_usage, color: Colors.orange[600]),
                          const SizedBox(width: 8),
                          const Text(
                            'データ分析情報',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('処理時間: ${_analysisResult!.formattedProcessingTime}'),
                      Text('データ充実度: ${_analysisResult!.dataRichness}'),
                      if (_analysisResult!.facilityCount != null)
                        Text('発見施設数: ${_analysisResult!.facilityCount}件'),
                      if (_analysisResult!.transportCount != null)
                        Text('交通手段数: ${_analysisResult!.transportCount}件'),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // アクションボタン
            ElevatedButton.icon(
              onPressed: _resetAnalysis,
              icon: const Icon(Icons.refresh),
              label: const Text('別の住所を分析'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),

            // 個人化分析への案内（未ログイン時のみ）
            if (!_isPersonalized) ...[
              const SizedBox(height: 16),
              Container(
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
                        Icon(Icons.upgrade, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text(
                          '個人化分析を試してみませんか？',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ログインして好み設定を行うと、あなたの価値観に合わせた詳細な分析を提供します。',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _navigateToMyPage,
                      icon: const Icon(Icons.login),
                      label: const Text('ログインして個人化分析'),
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
        ),
      ),
    );
  }

  // === UI コンポーネント ===

  Widget _buildAuthStatusCard() {
    return Card(
      color: _isPersonalized ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isPersonalized ? Icons.verified_user : Icons.info_outline,
                  color:
                      _isPersonalized ? Colors.green[600] : Colors.orange[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _isPersonalized ? '個人化分析モード' : '基本分析モード',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isPersonalized
                        ? Colors.green[800]
                        : Colors.orange[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isPersonalized
                  ? 'あなたの好み設定を反映した個人化された分析を実行します。'
                  : '一般的な観点から客観的な分析を実行します。ログインすると個人化分析が利用できます。',
              style: TextStyle(
                fontSize: 14,
                color: _isPersonalized ? Colors.green[700] : Colors.orange[700],
              ),
            ),
            if (!_isPersonalized) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _navigateToMyPage,
                icon: const Icon(Icons.login, size: 16),
                label:
                    const Text('ログインして個人化分析', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTypeCard() {
    return Card(
      color: _isPersonalized ? Colors.green[50] : Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isPersonalized ? Icons.person : Icons.public,
                  color: _isPersonalized ? Colors.green[600] : Colors.blue[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _isPersonalized ? '🔐 個人化分析' : '🔓 基本分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        _isPersonalized ? Colors.green[800] : Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isPersonalized
                  ? 'あなたの好み設定（交通・施設・ライフスタイル）を反映した分析を行います。'
                  : '一般的な住環境要素を客観的に評価した分析を行います。',
              style: TextStyle(
                fontSize: 14,
                color: _isPersonalized ? Colors.green[700] : Colors.blue[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  '分析情報',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('分析タイプ: ${_analysisResult!.analysisTypeDisplay}'),
            Text('処理時間: ${_analysisResult!.formattedProcessingTime}'),
            Text(_analysisResult!.personalizationDescription),
          ],
        ),
      ),
    );
  }
}
