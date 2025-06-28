// lib/screens/widgets/preference_setting_widget.dart

import 'package:flutter/material.dart';
import '../../models/user_preference_model.dart';
import '../../utils/constants.dart';

/// Maisoku AI v1.0: カメラ・エリア分析両対応の拡張好み設定ウィジェット
/// 詳細な好み設定に対応した機能分離バージョン + 保存ボタン統合
class PreferenceSettingWidget extends StatefulWidget {
  final UserPreferenceModel initialPreferences;
  final Function(UserPreferenceModel) onPreferencesChanged;
  final VoidCallback? onSaveRequested; // 🆕 保存リクエストコールバック
  final bool? showSaveButton; // 🆕 保存ボタン表示制御
  final bool? isSaving; // 🆕 保存中状態

  const PreferenceSettingWidget({
    Key? key,
    required this.initialPreferences,
    required this.onPreferencesChanged,
    this.onSaveRequested, // 🆕 オプショナル
    this.showSaveButton = true, // 🆕 デフォルトで表示
    this.isSaving = false, // 🆕 デフォルトで非保存中
  }) : super(key: key);

  @override
  State<PreferenceSettingWidget> createState() =>
      _PreferenceSettingWidgetState();
}

class _PreferenceSettingWidgetState extends State<PreferenceSettingWidget> {
  late UserPreferenceModel _preferences;

  // Maisoku AI v1.0: 拡張設定用の追加フィールド
  double _budgetMin = 50000; // 最低予算
  double _budgetMax = 200000; // 最高予算
  double _stationWalkTime = 10; // 駅徒歩時間（分）
  double _importanceBalance = 0.5; // 利便性vs静けさのバランス
  List<String> _avoidAreas = []; // 避けたいエリアタイプ
  List<String> _preferredRoomTypes = []; // 好みの間取り
  List<String> _amenityPriorities = []; // 重視する設備
  List<String> _workStyles = []; // 働き方
  List<String> _lifePatterns = []; // 生活パターン

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
    _initializeExtendedPreferences();
  }

  void _initializeExtendedPreferences() {
    // Maisoku AI v1.0: 既存の設定から拡張設定を復元
    _budgetMin = 50000;
    _budgetMax = 200000;
    _stationWalkTime = 10;
    _importanceBalance = 0.5;
    _avoidAreas = [];
    _preferredRoomTypes = [];
    _amenityPriorities = [];
    _workStyles = [];
    _lifePatterns = [];
  }

  void _updatePreferences(UserPreferenceModel newPreferences) {
    setState(() {
      _preferences = newPreferences;
    });
    widget.onPreferencesChanged(newPreferences);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Maisoku AI v1.0: ヘッダー更新
          _buildHeader(),

          const SizedBox(height: 24),

          // Maisoku AI v1.0: 機能対応表示カード
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.green[50]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📱 好み設定の適用範囲',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        icon: Icons.camera_alt,
                        title: 'カメラ分析',
                        description: '物件写真の評価',
                        color: Colors.blue[600]!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFeatureCard(
                        icon: Icons.location_on,
                        title: 'エリア分析',
                        description: '住環境の評価',
                        color: Colors.green[600]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 基本設定セクション
          _buildSection(
            title: '💰 予算設定',
            icon: Icons.account_balance_wallet,
            children: [
              _buildBudgetSlider(),
              const SizedBox(height: 16),
              _buildBudgetPrioritySelection(),
            ],
          ),

          const SizedBox(height: 24),

          _buildSection(
            title: '👨‍👩‍👧‍👦 ライフスタイル',
            icon: Icons.family_restroom,
            children: [
              _buildLifestyleSelection(),
            ],
          ),

          const SizedBox(height: 24),

          _buildSection(
            title: '🏠 間取り・物件タイプ',
            icon: Icons.home_work,
            children: [
              _buildRoomTypeSelection(),
            ],
          ),

          const SizedBox(height: 24),

          // 立地・交通セクション
          _buildSection(
            title: '🚇 交通アクセス',
            icon: Icons.train,
            children: [
              _buildStationWalkTimeSlider(),
              const SizedBox(height: 16),
              _buildTransportPriorities(),
            ],
          ),

          const SizedBox(height: 24),

          _buildSection(
            title: '🏪 周辺施設の重視度',
            icon: Icons.location_city,
            children: [
              _buildFacilityPriorities(),
            ],
          ),

          const SizedBox(height: 24),

          _buildSection(
            title: '⚖️ 環境バランス',
            icon: Icons.balance,
            children: [
              _buildImportanceBalanceSlider(),
            ],
          ),

          const SizedBox(height: 24),

          _buildSection(
            title: '🚫 避けたい環境',
            icon: Icons.do_not_disturb,
            children: [
              _buildAvoidAreasSelection(),
            ],
          ),

          const SizedBox(height: 24),

          // ライフスタイル詳細セクション
          _buildSection(
            title: '💼 働き方',
            icon: Icons.work,
            children: [
              _buildWorkStyleSelection(),
            ],
          ),

          const SizedBox(height: 24),

          _buildSection(
            title: '⏰ 生活パターン',
            icon: Icons.schedule,
            children: [
              _buildLifePatternSettings(),
            ],
          ),

          const SizedBox(height: 24),

          _buildSection(
            title: '🛠️ 重視する設備',
            icon: Icons.build,
            children: [
              _buildAmenityPriorities(),
            ],
          ),

          const SizedBox(height: 24),

          // Maisoku AI v1.0: サマリーと説明 + 保存ボタン
          _buildBottomSummaryWithSaveButton(),

          // 🆕 追加の余白（保存ボタンがある場合）
          if (widget.showSaveButton == true) const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '詳細好み設定',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Maisoku AI v1.0: カメラ・エリア分析結果をカスタマイズ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Maisoku AI v1.0: 機能分離説明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'カメラ分析とエリア分析で、あなたの価値観に合わせた個人化された分析結果を提供します',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.green[600], size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '家賃予算: ${(_budgetMin / 1000).toInt()}万円 〜 ${(_budgetMax / 1000).toInt()}万円',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: RangeValues(_budgetMin, _budgetMax),
          min: 30000,
          max: 500000,
          divisions: 47,
          labels: RangeLabels(
            '${(_budgetMin / 1000).toInt()}万',
            '${(_budgetMax / 1000).toInt()}万',
          ),
          onChanged: (RangeValues values) {
            setState(() {
              _budgetMin = values.start;
              _budgetMax = values.end;
            });
          },
          activeColor: Colors.green[600],
        ),
      ],
    );
  }

  Widget _buildBudgetPrioritySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '予算に対する考え方',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        _buildRadioGroup<String>(
          options: AppConstants.BUDGET_PRIORITIES,
          selectedValue: _preferences.budgetPriority,
          onChanged: (value) => _updatePreferences(
            _preferences.copyWith(budgetPriority: value),
          ),
        ),
      ],
    );
  }

  Widget _buildStationWalkTimeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '駅徒歩時間: ${_stationWalkTime.toInt()}分以内',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _stationWalkTime,
          min: 1,
          max: 30,
          divisions: 29,
          label: '${_stationWalkTime.toInt()}分',
          onChanged: (value) {
            setState(() {
              _stationWalkTime = value;
            });
          },
          activeColor: Colors.green[600],
        ),
      ],
    );
  }

  Widget _buildImportanceBalanceSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '利便性 vs 静けさ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('静か', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: _importanceBalance,
                min: 0,
                max: 1,
                divisions: 10,
                onChanged: (value) {
                  setState(() {
                    _importanceBalance = value;
                  });
                },
                activeColor: Colors.green[600],
              ),
            ),
            const Text('便利', style: TextStyle(fontSize: 12)),
          ],
        ),
        Text(
          _importanceBalance < 0.3
              ? '静かな環境を重視'
              : _importanceBalance > 0.7
                  ? '利便性を重視'
                  : 'バランス重視',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTransportPriorities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCheckboxTile(
          title: '駅近（徒歩圏内）が重要',
          subtitle: '最寄り駅まで徒歩10分以内を重視',
          value: _preferences.prioritizeStationAccess,
          onChanged: (value) => _updatePreferences(
            _preferences.copyWith(prioritizeStationAccess: value),
          ),
        ),
        _buildCheckboxTile(
          title: '複数路線アクセス',
          subtitle: '複数の路線が利用できることを重視',
          value: _preferences.prioritizeMultipleLines,
          onChanged: (value) => _updatePreferences(
            _preferences.copyWith(prioritizeMultipleLines: value),
          ),
        ),
        _buildCheckboxTile(
          title: '車移動メイン',
          subtitle: '駐車場や高速道路へのアクセスを重視',
          value: _preferences.prioritizeCarAccess,
          onChanged: (value) => _updatePreferences(
            _preferences.copyWith(prioritizeCarAccess: value),
          ),
        ),
      ],
    );
  }

  Widget _buildFacilityPriorities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCheckboxTile(
          title: '病院・クリニック',
          subtitle: '医療施設へのアクセスを重視',
          value: _preferences.prioritizeMedical,
          onChanged: (value) => _updatePreferences(
            _preferences.copyWith(prioritizeMedical: value),
          ),
        ),
        _buildCheckboxTile(
          title: 'スーパー・コンビニ',
          subtitle: '日常の買い物施設を重視',
          value: _preferences.prioritizeShopping,
          onChanged: (value) => _updatePreferences(
            _preferences.copyWith(prioritizeShopping: value),
          ),
        ),
        _buildCheckboxTile(
          title: '学校・教育施設',
          subtitle: '教育環境を重視',
          value: _preferences.prioritizeEducation,
          onChanged: (value) => _updatePreferences(
            _preferences.copyWith(prioritizeEducation: value),
          ),
        ),
        _buildCheckboxTile(
          title: '公園・緑地',
          subtitle: '自然環境や憩いの場を重視',
          value: _preferences.prioritizeParks,
          onChanged: (value) => _updatePreferences(
            _preferences.copyWith(prioritizeParks: value),
          ),
        ),
      ],
    );
  }

  Widget _buildLifestyleSelection() {
    return _buildRadioGroup<String>(
      options: AppConstants.LIFESTYLE_TYPES,
      selectedValue: _preferences.lifestyleType,
      onChanged: (value) => _updatePreferences(
        _preferences.copyWith(lifestyleType: value),
      ),
    );
  }

  Widget _buildWorkStyleSelection() {
    return _buildMultiSelectChips(
      title: '働き方',
      options: const [
        'リモートワーク',
        '毎日通勤',
        'フレックス',
        'シフト制',
        '出張多め',
        '学生',
        '専業主婦/夫',
        '自営業',
      ],
      selectedOptions: _workStyles,
      onSelectionChanged: (selected) {
        setState(() {
          _workStyles = selected;
        });
      },
    );
  }

  Widget _buildAvoidAreasSelection() {
    return _buildMultiSelectChips(
      title: '避けたい環境',
      options: const [
        '騒音が多い',
        '治安が心配',
        '夜道が暗い',
        '人通りが少ない',
        '坂道が多い',
        '工場が近い',
        '線路沿い',
        '繁華街',
      ],
      selectedOptions: _avoidAreas,
      onSelectionChanged: (selected) {
        setState(() {
          _avoidAreas = selected;
        });
      },
    );
  }

  Widget _buildRoomTypeSelection() {
    return _buildMultiSelectChips(
      title: '希望する間取り',
      options: const [
        'ワンルーム',
        '1K',
        '1DK',
        '1LDK',
        '2K',
        '2DK',
        '2LDK',
        '3K以上',
        '3LDK以上',
      ],
      selectedOptions: _preferredRoomTypes,
      onSelectionChanged: (selected) {
        setState(() {
          _preferredRoomTypes = selected;
        });
      },
    );
  }

  Widget _buildAmenityPriorities() {
    return _buildMultiSelectChips(
      title: '重視する設備',
      options: const [
        'エアコン',
        '洗濯機',
        'バス・トイレ別',
        'オートロック',
        'エレベーター',
        '宅配ボックス',
        'インターネット',
        '駐車場',
        '駐輪場',
        'ペット可',
        'フローリング',
        'システムキッチン',
      ],
      selectedOptions: _amenityPriorities,
      onSelectionChanged: (selected) {
        setState(() {
          _amenityPriorities = selected;
        });
      },
    );
  }

  Widget _buildLifePatternSettings() {
    return _buildMultiSelectChips(
      title: '生活パターン',
      options: const [
        '早起き',
        '夜型',
        '在宅時間長い',
        '外出多め',
        '料理をよくする',
        '来客多め',
        '静かに過ごしたい',
        'アクティブ',
      ],
      selectedOptions: _lifePatterns,
      onSelectionChanged: (selected) {
        setState(() {
          _lifePatterns = selected;
        });
      },
    );
  }

  Widget _buildMultiSelectChips({
    required String title,
    required List<String> options,
    required List<String> selectedOptions,
    required Function(List<String>) onSelectionChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedOptions.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                final newSelection = List<String>.from(selectedOptions);
                if (selected) {
                  newSelection.add(option);
                } else {
                  newSelection.remove(option);
                }
                onSelectionChanged(newSelection);
              },
              selectedColor: Colors.green[100],
              checkmarkColor: Colors.green[700],
              labelStyle: TextStyle(
                color: isSelected ? Colors.green[700] : Colors.grey[700],
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return CheckboxListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      value: value,
      onChanged: (newValue) => onChanged(newValue ?? false),
      activeColor: Colors.green[600],
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildRadioGroup<T>({
    required Map<T, String> options,
    required T selectedValue,
    required Function(T) onChanged,
  }) {
    return Column(
      children: options.entries.map((entry) {
        return RadioListTile<T>(
          title: Text(
            entry.value,
            style: const TextStyle(fontSize: 14),
          ),
          value: entry.key,
          groupValue: selectedValue,
          onChanged: (value) => value != null ? onChanged(value) : null,
          activeColor: Colors.green[600],
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }

  /// Maisoku AI v1.0: 機能カード
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
    );
  }

  // 🆕 保存ボタン付きサマリー
  Widget _buildBottomSummaryWithSaveButton() {
    final stats = _getPreferenceStats();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '設定完了度: ${(((stats['total'] ?? 0) / 15) * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (stats['total'] ?? 0) / 15,
            backgroundColor: Colors.green[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats['total'] ?? 0}個の設定項目を選択済み（基本: ${stats['basic'] ?? 0}, 交通: ${stats['transport'] ?? 0}, 施設: ${stats['facility'] ?? 0}）',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
            ),
          ),

          // 🆕 ウィジェット内保存ボタン（オプション）
          if (widget.showSaveButton == true &&
              widget.onSaveRequested != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.save, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '設定を保存する',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '変更した好み設定を保存して、AI分析に反映させます',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.isSaving == true
                          ? null
                          : widget.onSaveRequested,
                      icon: widget.isSaving == true
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.green,
                              ),
                            )
                          : const Icon(Icons.save_alt, size: 20),
                      label: Text(
                        widget.isSaving == true ? '保存中...' : '今すぐ保存',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Maisoku AI v1.0: 注意事項更新
          Container(
            padding: const EdgeInsets.all(16),
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
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Maisoku AI v1.0 好み設定について',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• カメラ分析：物件写真の評価に好み設定を適用\n'
                  '• エリア分析：交通・施設情報の重み付けに適用\n'
                  '• 詳細設定：予算範囲、間取り、設備なども考慮\n'
                  '• 設定変更後は必ず保存ボタンを押してください',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _getPreferenceStats() {
    int basicCount = 0;
    int transportCount = 0;
    int facilityCount = 0;

    // 基本設定カウント
    if (_preferences.lifestyleType.isNotEmpty) basicCount++;
    if (_preferences.budgetPriority.isNotEmpty) basicCount++;
    if (_preferredRoomTypes.isNotEmpty) basicCount++;
    if (_workStyles.isNotEmpty) basicCount++;
    if (_lifePatterns.isNotEmpty) basicCount++;

    // 交通手段カウント
    if (_preferences.prioritizeStationAccess) transportCount++;
    if (_preferences.prioritizeMultipleLines) transportCount++;
    if (_preferences.prioritizeCarAccess) transportCount++;

    // 周辺施設カウント
    if (_preferences.prioritizeMedical) facilityCount++;
    if (_preferences.prioritizeShopping) facilityCount++;
    if (_preferences.prioritizeEducation) facilityCount++;
    if (_preferences.prioritizeParks) facilityCount++;

    // 追加設定カウント
    if (_avoidAreas.isNotEmpty) facilityCount++;
    if (_amenityPriorities.isNotEmpty) basicCount++;

    return {
      'basic': basicCount,
      'transport': transportCount,
      'facility': facilityCount,
      'total': basicCount + transportCount + facilityCount,
    };
  }
}
