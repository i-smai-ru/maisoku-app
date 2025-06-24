// lib/screens/widgets/progress_indicator_widget.dart

import 'package:flutter/material.dart';

/// Maisoku AI v1.0: プログレス表示ウィジェット
///
/// エリア分析・カメラ分析の進行状況を表示
/// - ステップ別進行状況・アニメーション対応
/// - 完了状態・エラー状態の表示
/// - Material Design 3対応・アクセシビリティ配慮
class ProgressIndicatorWidget extends StatefulWidget {
  /// 現在のステップ（1から開始）
  final int currentStep;

  /// 総ステップ数
  final int totalSteps;

  /// 各ステップのラベル
  final List<String> stepLabels;

  /// 完了フラグ
  final bool isCompleted;

  /// エラーフラグ
  final bool hasError;

  /// エラーメッセージ
  final String? errorMessage;

  /// プログレスタイトル
  final String? title;

  /// プログレスの説明文
  final String? description;

  /// プライマリカラー（分析種別による色分け）
  final Color? primaryColor;

  /// アニメーション有効フラグ
  final bool enableAnimation;

  const ProgressIndicatorWidget({
    Key? key,
    required this.currentStep,
    this.totalSteps = 2,
    this.stepLabels = const ['交通アクセス分析', '施設密度分析'],
    this.isCompleted = false,
    this.hasError = false,
    this.errorMessage,
    this.title,
    this.description,
    this.primaryColor,
    this.enableAnimation = true,
  }) : super(key: key);

  @override
  State<ProgressIndicatorWidget> createState() =>
      _ProgressIndicatorWidgetState();
}

class _ProgressIndicatorWidgetState extends State<ProgressIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // プログレスバーアニメーション
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // パルスアニメーション（進行中表示用）
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.enableAnimation) {
      _progressAnimationController.forward();
      if (!widget.isCompleted && !widget.hasError) {
        _pulseAnimationController.repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(ProgressIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentStep != widget.currentStep ||
        oldWidget.isCompleted != widget.isCompleted ||
        oldWidget.hasError != widget.hasError) {
      if (widget.enableAnimation) {
        _progressAnimationController.reset();
        _progressAnimationController.forward();
      }

      // 完了・エラー時はパルスアニメーション停止
      if (widget.isCompleted || widget.hasError) {
        _pulseAnimationController.stop();
      } else {
        _pulseAnimationController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  /// プログレス値を計算（0.0 ～ 1.0）
  double get progressValue {
    if (widget.isCompleted) return 1.0;
    if (widget.hasError) return 0.0;
    return (widget.currentStep / widget.totalSteps).clamp(0.0, 1.0);
  }

  /// プライマリカラーを取得
  Color get primaryColor {
    if (widget.hasError) return Colors.red;
    if (widget.isCompleted) return Colors.green;
    return widget.primaryColor ?? Colors.blue[600]!;
  }

  /// ステータスアイコンを取得
  IconData get statusIcon {
    if (widget.hasError) return Icons.error;
    if (widget.isCompleted) return Icons.check_circle;
    return Icons.analytics;
  }

  /// ステータステキストを取得
  String get statusText {
    if (widget.hasError) return 'エラーが発生しました';
    if (widget.isCompleted) return '分析完了';
    return widget.title ?? '分析中...';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ステータスヘッダー
          _buildStatusHeader(),

          const SizedBox(height: 20),

          // プログレスセクション
          _buildProgressSection(),

          const SizedBox(height: 20),

          // ステップリスト
          _buildStepList(),

          // エラーメッセージ・説明文
          if (widget.hasError && widget.errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorMessage(),
          ] else if (!widget.isCompleted && widget.description != null) ...[
            const SizedBox(height: 16),
            _buildDescription(),
          ],
        ],
      ),
    );
  }

  /// ステータスヘッダー
  Widget _buildStatusHeader() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: (!widget.isCompleted &&
                  !widget.hasError &&
                  widget.enableAnimation)
              ? _pulseAnimation.value
              : 1.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                statusIcon,
                color: primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// プログレスセクション
  Widget _buildProgressSection() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final animatedProgress = widget.enableAnimation
            ? progressValue * _progressAnimation.value
            : progressValue;

        return Column(
          children: [
            // 数値表示
            Text(
              widget.hasError
                  ? 'エラー'
                  : widget.isCompleted
                      ? '完了'
                      : '${widget.currentStep}/${widget.totalSteps}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 16),

            // プログレスバー
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: animatedProgress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // プログレス率表示
            Text(
              '${(animatedProgress * 100).round()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        );
      },
    );
  }

  /// ステップリスト
  Widget _buildStepList() {
    return Column(
      children: List.generate(widget.stepLabels.length, (index) {
        final bool isCompleted =
            index < widget.currentStep || widget.isCompleted;
        final bool isCurrent = index == widget.currentStep - 1 &&
            !widget.isCompleted &&
            !widget.hasError;
        final bool hasError =
            widget.hasError && index == widget.currentStep - 1;

        return _buildStepItem(
          stepNumber: index + 1,
          label: widget.stepLabels[index],
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          hasError: hasError,
        );
      }),
    );
  }

  /// 個別ステップアイテム
  Widget _buildStepItem({
    required int stepNumber,
    required String label,
    required bool isCompleted,
    required bool isCurrent,
    required bool hasError,
  }) {
    Color itemColor;
    IconData itemIcon;

    if (hasError) {
      itemColor = Colors.red;
      itemIcon = Icons.error;
    } else if (isCompleted) {
      itemColor = Colors.green;
      itemIcon = Icons.check_circle;
    } else if (isCurrent) {
      itemColor = primaryColor;
      itemIcon = Icons.radio_button_unchecked;
    } else {
      itemColor = Colors.grey[400]!;
      itemIcon = Icons.radio_button_unchecked;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // ステップアイコン
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: itemColor.withOpacity(0.1),
              border: Border.all(color: itemColor, width: 2),
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check, size: 16, color: itemColor)
                  : hasError
                      ? Icon(Icons.close, size: 16, color: itemColor)
                      : Text(
                          stepNumber.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: itemColor,
                          ),
                        ),
            ),
          ),

          const SizedBox(width: 16),

          // ステップ名
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: hasError
                    ? Colors.red[700]
                    : isCompleted
                        ? Colors.green[700]
                        : isCurrent
                            ? primaryColor
                            : Colors.grey[600],
              ),
            ),
          ),

          // ローディングインジケータ（進行中のみ）
          if (isCurrent && !hasError)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  /// エラーメッセージ表示
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 説明文表示
  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.description!,
              style: TextStyle(
                fontSize: 14,
                color: primaryColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// プログレス表示の簡易版ウィジェット
class SimpleProgressIndicator extends StatelessWidget {
  final String message;
  final Color? color;
  final double? progress;

  const SimpleProgressIndicator({
    Key? key,
    required this.message,
    this.color,
    this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.blue[600]!;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null) ...[
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              if (progress == null)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                  ),
                ),
              if (progress == null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: effectiveColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
