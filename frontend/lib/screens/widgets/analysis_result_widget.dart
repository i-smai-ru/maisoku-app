// lib/screens/widgets/analysis_result_widget.dart

import 'package:flutter/material.dart';
import '../../models/area_analysis_model.dart';
import '../../models/address_model.dart';

/// Maisoku AI v1.0: エリア分析結果表示ウィジェット
/// 段階的認証対応（基本分析・個人化分析）の分析結果表示専用
class AnalysisResultWidget extends StatelessWidget {
  final AreaAnalysisModel areaAnalysis;
  final AddressModel address;
  final String? integratedAnalysis;
  final bool isPersonalized;
  final Function(String apiType) onRetry;
  final VoidCallback? onPlayAudio;
  final bool isSpeaking;

  const AnalysisResultWidget({
    Key? key,
    required this.areaAnalysis,
    required this.address,
    this.integratedAnalysis,
    required this.isPersonalized,
    required this.onRetry,
    this.onPlayAudio,
    this.isSpeaking = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // v1.0: 分析完了率・品質表示カード
        _buildAnalysisStatusCard(),

        const SizedBox(height: 16),

        // 統合AI分析結果（段階的認証対応）
        if (integratedAnalysis != null) _buildIntegratedAnalysisCard(),

        const SizedBox(height: 16),

        // 交通アクセス詳細
        _buildTrafficAccessSection(),

        const SizedBox(height: 16),

        // 施設密度詳細
        _buildFacilityDensitySection(),
      ],
    );
  }

  /// v1.0: 分析完了率・品質表示カード
  Widget _buildAnalysisStatusCard() {
    final completionRate = (areaAnalysis.successRate * 100).toStringAsFixed(0);
    final isComplete = areaAnalysis.successRate >= 1.0;
    final isHighQuality = areaAnalysis.successRate >= 0.8;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isComplete) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = '分析完了';
    } else if (isHighQuality) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber;
      statusText = '一部完了';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = '分析不完全';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.shade50, statusColor.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.shade200),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'エリア分析品質',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$statusText ($completionRate%)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor.shade700,
                  ),
                ),
                if (!isComplete) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${areaAnalysis.completedCount}/${AreaAnalysisModel.totalApiCount}項目完了',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 再試行ボタン（部分失敗時）
          if (!isComplete)
            TextButton.icon(
              onPressed: () => onRetry('all'),
              icon: Icon(Icons.refresh, size: 16, color: statusColor.shade700),
              label: Text(
                '再試行',
                style: TextStyle(fontSize: 12, color: statusColor.shade700),
              ),
            ),
        ],
      ),
    );
  }

  /// v1.0: 統合AI分析結果カード（段階的認証対応）
  Widget _buildIntegratedAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.smart_toy,
                color: isPersonalized ? Colors.green[600] : Colors.blue[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPersonalized ? 'まいそくAIの個人化分析' : 'まいそくAIの基本分析',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        isPersonalized ? Colors.green[800] : Colors.blue[800],
                  ),
                ),
              ),
              // 音声読み上げボタン
              if (onPlayAudio != null)
                IconButton(
                  onPressed: onPlayAudio,
                  icon: Icon(
                    isSpeaking ? Icons.stop : Icons.volume_up,
                    color:
                        isPersonalized ? Colors.green[600] : Colors.blue[600],
                    size: 20,
                  ),
                  tooltip: isSpeaking ? '読み上げ停止' : '音声で聞く',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 段階的認証状態表示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPersonalized ? Colors.green[50] : Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isPersonalized ? Colors.green[200]! : Colors.blue[200]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPersonalized ? Icons.lock : Icons.lock_open,
                  size: 14,
                  color: isPersonalized ? Colors.green[600] : Colors.blue[600],
                ),
                const SizedBox(width: 4),
                Text(
                  isPersonalized ? '個人化分析モード' : '基本分析モード',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        isPersonalized ? Colors.green[700] : Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // AI分析結果テキスト
          Text(
            integratedAnalysis!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// v1.0: 交通アクセス詳細セクション
  Widget _buildTrafficAccessSection() {
    final traffic = areaAnalysis.trafficAccess;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.train, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '交通アクセス',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const Spacer(),
              if (traffic == null || !traffic.isSuccess)
                TextButton.icon(
                  onPressed: () => onRetry('traffic'),
                  icon: Icon(Icons.refresh, size: 16, color: Colors.blue[600]),
                  label: Text(
                    '再試行',
                    style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (traffic == null || !traffic.isSuccess) ...[
            _buildErrorMessage('交通アクセス情報の取得に失敗しました'),
          ] else ...[
            // 最寄り駅
            if (traffic.stations.isNotEmpty) ...[
              _buildSubsectionTitle('最寄り駅'),
              ...traffic.stations.take(3).map((station) => _buildTrafficItem(
                    title: station.name,
                    subtitle: '${station.lines.join('・')}',
                    distance: '徒歩${station.walkingMinutes}分',
                    color: _getDistanceColor(station.walkingMinutes),
                  )),
              const SizedBox(height: 12),
            ],

            // バス停
            if (traffic.busStops.isNotEmpty) ...[
              _buildSubsectionTitle('バス停'),
              ...traffic.busStops.take(2).map((busStop) => _buildTrafficItem(
                    title: busStop.name,
                    subtitle: busStop.routesDisplay,
                    distance: '徒歩${busStop.walkingMinutes}分',
                    color: _getDistanceColor(busStop.walkingMinutes),
                  )),
              const SizedBox(height: 12),
            ],

            // 高速道路
            if (traffic.highways.isNotEmpty) ...[
              _buildSubsectionTitle('高速道路'),
              ...traffic.highways.take(2).map((highway) => _buildTrafficItem(
                    title: highway.name,
                    subtitle: highway.distanceCategory,
                    distance: highway.distanceDisplay,
                    color: _getDistanceColorForHighway(highway.distanceKm),
                  )),
            ],
          ],
        ],
      ),
    );
  }

  /// v1.0: 施設密度詳細セクション
  Widget _buildFacilityDensitySection() {
    final facility = areaAnalysis.facilityDensity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_city, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '周辺施設',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              const Spacer(),
              if (facility == null || !facility.isSuccess)
                TextButton.icon(
                  onPressed: () => onRetry('facility'),
                  icon: Icon(Icons.refresh, size: 16, color: Colors.green[600]),
                  label: Text(
                    '再試行',
                    style: TextStyle(fontSize: 12, color: Colors.green[600]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (facility == null || !facility.isSuccess) ...[
            _buildErrorMessage('施設情報の取得に失敗しました'),
          ] else ...[
            // 施設カウント表示
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: facility.facilityCounts.entries.map((entry) {
                final category = entry.key;
                final count = entry.value;
                return _buildFacilityCountChip(category, count);
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 主要施設詳細
            ...facility.topFacilities.entries
                .where((entry) => entry.value.isNotEmpty)
                .take(3)
                .map((entry) {
              final category = entry.key;
              final facilities = entry.value;
              return _buildFacilityCategorySection(category, facilities);
            }),
          ],
        ],
      ),
    );
  }

  /// サブセクションタイトル
  Widget _buildSubsectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  /// 交通アクセス項目
  Widget _buildTrafficItem({
    required String title,
    required String subtitle,
    required String distance,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              distance,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 施設カウントチップ
  Widget _buildFacilityCountChip(String category, int count) {
    final color = _getCategoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$category: ${count}件',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  /// 施設カテゴリセクション
  Widget _buildFacilityCategorySection(
      String category, List<FacilityInfo> facilities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubsectionTitle(category),
        ...facilities.take(3).map((facility) => _buildFacilityItem(facility)),
        const SizedBox(height: 12),
      ],
    );
  }

  /// 施設項目
  Widget _buildFacilityItem(FacilityInfo facility) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facility.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                if (facility.vicinity.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    facility.vicinity,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (facility.rating > 0) ...[
            Icon(Icons.star, size: 14, color: Colors.orange[600]),
            const SizedBox(width: 2),
            Text(
              facility.rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// エラーメッセージ
  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 距離による色分け（徒歩時間）
  Color _getDistanceColor(int walkingMinutes) {
    if (walkingMinutes <= 5) return Colors.green;
    if (walkingMinutes <= 10) return Colors.orange;
    return Colors.red;
  }

  /// 距離による色分け（高速道路距離）
  Color _getDistanceColorForHighway(double distanceKm) {
    if (distanceKm <= 3) return Colors.green;
    if (distanceKm <= 10) return Colors.orange;
    return Colors.red;
  }

  /// カテゴリによる色分け
  Color _getCategoryColor(String category) {
    switch (category) {
      case '医療施設':
        return Colors.red;
      case 'コンビニ':
        return Colors.blue;
      case 'スーパー':
        return Colors.green;
      case '学校':
        return Colors.purple;
      case '公園':
        return Colors.teal;
      case '銀行':
        return Colors.orange;
      case 'レストラン':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
