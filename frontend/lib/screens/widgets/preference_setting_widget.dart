// lib/screens/widgets/preference_setting_widget.dart

import 'package:flutter/material.dart';
import '../../models/user_preference_model.dart';
import '../../utils/constants.dart';

/// v1.0: カメラ・エリア分析両対応の好み設定ウィジェット
/// 機能分離に対応した説明文・UI更新
class PreferenceSettingWidget extends StatefulWidget {
  final UserPreferenceModel initialPreferences;
  final Function(UserPreferenceModel) onPreferencesChanged;

  const PreferenceSettingWidget({
    Key? key,
    required this.initialPreferences,
    required this.onPreferencesChanged,
  }) : super(key: key);

  @override
  State<PreferenceSettingWidget> createState() =>
      _PreferenceSettingWidgetState();
}

class _PreferenceSettingWidgetState extends State<PreferenceSettingWidget> {
  late UserPreferenceModel _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
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
          // v1.0: ヘッダー更新
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
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
                            '好み設定',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'v1.0: カメラ・エリア分析結果をカスタマイズ',
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
                // v1.0: 機能分離説明
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'カメラ分析とエリア分析の両方で、あなたの価値観に合わせた個人化された分析結果を提供します',
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
          ),

          const SizedBox(height: 24),

          // v1.0: 機能対応表示カード
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

          // 交通手段の優先度
          _buildSection(
            title: '🚗 交通手段の優先度',
            description: 'エリア分析で重視する交通手段を選択してください（複数選択可）',
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
          ),

          const SizedBox(height: 24),

          // 周辺施設の重視度
          _buildSection(
            title: '🏪 周辺施設の重視度',
            description: 'エリア分析で重要視する施設の優先度を選択してください',
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
          ),

          const SizedBox(height: 24),

          // ライフスタイル
          _buildSection(
            title: '👨‍👩‍👧‍👦 ライフスタイル',
            description: 'カメラ・エリア分析で考慮するライフスタイルを選択してください',
            children: [
              _buildRadioGroup<String>(
                options: AppConstants.LIFESTYLE_TYPES,
                selectedValue: _preferences.lifestyleType,
                onChanged: (value) => _updatePreferences(
                  _preferences.copyWith(lifestyleType: value),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 予算感
          _buildSection(
            title: '💰 予算感',
            description: 'カメラ分析での物件評価に反映する予算に対する考え方',
            children: [
              _buildRadioGroup<String>(
                options: AppConstants.BUDGET_PRIORITIES,
                selectedValue: _preferences.budgetPriority,
                onChanged: (value) => _updatePreferences(
                  _preferences.copyWith(budgetPriority: value),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // v1.0: 設定状況の表示（更新）
          _buildPreferenceSummary(),

          const SizedBox(height: 16),

          // v1.0: 注意事項更新
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
                      'v1.0 好み設定について',
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
                  '• いつでも変更可能で、即座に反映されます',
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

  /// v1.0: 機能カード
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

  Widget _buildSection({
    required String title,
    required String description,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
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
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
      value: value,
      onChanged: (newValue) => onChanged(newValue ?? false),
      activeColor: Colors.green[600],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            style: const TextStyle(fontSize: 16),
          ),
          value: entry.key,
          groupValue: selectedValue,
          onChanged: (value) => value != null ? onChanged(value) : null,
          activeColor: Colors.green[600],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        );
      }).toList(),
    );
  }

  /// v1.0: 設定状況サマリー更新
  Widget _buildPreferenceSummary() {
    final stats = _getPreferenceStats();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '設定状況サマリー',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('交通手段', stats['transport']!, 3),
              ),
              Expanded(
                child: _buildStatItem('周辺施設', stats['facility']!, 4),
              ),
              Expanded(
                child: _buildStatItem('その他', stats['other']!, 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  stats['total'] == 0 ? Icons.tune : Icons.check_circle,
                  color: stats['total'] == 0
                      ? Colors.orange[600]
                      : Colors.green[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stats['total'] == 0
                        ? '設定を選択すると、カメラ・エリア分析がより個人的になります'
                        : '合計${stats['total']}項目を設定済み。カメラ・エリア分析で活用されます',
                    style: TextStyle(
                      fontSize: 14,
                      color: stats['total'] == 0
                          ? Colors.orange[800]
                          : Colors.green[700],
                      fontWeight: FontWeight.w500,
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

  Widget _buildStatItem(String label, int selected, int total) {
    final double progress = total > 0 ? selected / total : 0.0;

    return Column(
      children: [
        Text(
          '$selected/$total',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.green[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.green[700],
          ),
        ),
      ],
    );
  }

  Map<String, int> _getPreferenceStats() {
    int transportCount = 0;
    int facilityCount = 0;
    int otherCount = 0;

    // 交通手段カウント
    if (_preferences.prioritizeStationAccess) transportCount++;
    if (_preferences.prioritizeMultipleLines) transportCount++;
    if (_preferences.prioritizeCarAccess) transportCount++;

    // 周辺施設カウント
    if (_preferences.prioritizeMedical) facilityCount++;
    if (_preferences.prioritizeShopping) facilityCount++;
    if (_preferences.prioritizeEducation) facilityCount++;
    if (_preferences.prioritizeParks) facilityCount++;

    // その他カウント
    if (_preferences.lifestyleType.isNotEmpty) otherCount++;
    if (_preferences.budgetPriority.isNotEmpty) otherCount++;

    return {
      'transport': transportCount,
      'facility': facilityCount,
      'other': otherCount,
      'total': transportCount + facilityCount + otherCount,
    };
  }
}
