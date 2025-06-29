// lib/widgets/markdown_analysis_result_widget.dart

import 'package:flutter/material.dart';

/// Markdownテキストを適切にフォーマットして表示するウィジェット
class MarkdownAnalysisResultWidget extends StatelessWidget {
  final String markdownText;
  final bool isPersonalized;

  const MarkdownAnalysisResultWidget({
    Key? key,
    required this.markdownText,
    required this.isPersonalized,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgets = _parseMarkdownToWidgets(markdownText, context);

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
          // ヘッダー
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
            ],
          ),

          const SizedBox(height: 12),

          // 分析タイプ表示
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

          const SizedBox(height: 16),

          // Markdown解析済みコンテンツ
          ...widgets,
        ],
      ),
    );
  }

  /// Markdownテキストを解析してWidgetリストに変換
  List<Widget> _parseMarkdownToWidgets(String markdown, BuildContext context) {
    final List<Widget> widgets = [];
    final List<String> lines = markdown.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];

      if (line.trim().isEmpty) {
        // 空行はスペースとして追加
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // 見出し処理
      if (line.startsWith('## ')) {
        widgets.add(_buildHeader2(line.substring(3).trim()));
        widgets.add(const SizedBox(height: 12));
      } else if (line.startsWith('# ')) {
        widgets.add(_buildHeader1(line.substring(2).trim()));
        widgets.add(const SizedBox(height: 16));
      } else if (line.startsWith('**') && line.endsWith('**')) {
        // 太字見出し行
        final String boldText = line.substring(2, line.length - 2);
        widgets.add(_buildBoldHeading(boldText));
        widgets.add(const SizedBox(height: 8));
      } else if (line.trim().startsWith('*   ')) {
        // リスト項目
        final String listItem = line.substring(line.indexOf('*   ') + 4);
        widgets.add(_buildListItem(listItem));
      } else if (line.trim().startsWith('- ')) {
        // リスト項目（ハイフン）
        final String listItem = line.substring(line.indexOf('- ') + 2);
        widgets.add(_buildListItem(listItem));
      } else {
        // 通常のテキスト
        widgets.add(_buildParagraph(line));
        widgets.add(const SizedBox(height: 6));
      }
    }

    return widgets;
  }

  /// レベル1見出し
  Widget _buildHeader1(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  /// レベル2見出し
  Widget _buildHeader2(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue[800],
      ),
    );
  }

  /// 太字見出し
  Widget _buildBoldHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.green[700],
        ),
      ),
    );
  }

  /// リスト項目
  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 8),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.blue[600],
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: _buildFormattedText(text),
          ),
        ],
      ),
    );
  }

  /// 段落
  Widget _buildParagraph(String text) {
    return _buildFormattedText(text);
  }

  /// インライン書式を処理したテキスト
  Widget _buildFormattedText(String text) {
    final List<InlineSpan> spans = [];
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
    final RegExp italicRegex = RegExp(r'\*(.*?)\*');

    int lastIndex = 0;

    // 太字処理
    for (final Match match in boldRegex.allMatches(text)) {
      // マッチ前のテキスト
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Colors.black87,
          ),
        ));
      }

      // 太字テキスト
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ));

      lastIndex = match.end;
    }

    // 残りのテキスト
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Colors.black87,
        ),
      ));
    }

    // スパンが空の場合は通常のテキストとして処理
    if (spans.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Colors.black87,
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

/// エリア分析結果の改良版表示ウィジェット
class ImprovedAnalysisResultWidget extends StatelessWidget {
  final String analysisText;
  final bool isPersonalized;
  final Function(String apiType) onRetry;
  final VoidCallback? onPlayAudio;
  final bool isSpeaking;

  const ImprovedAnalysisResultWidget({
    Key? key,
    required this.analysisText,
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
        // Markdown形式の分析結果表示
        MarkdownAnalysisResultWidget(
          markdownText: analysisText,
          isPersonalized: isPersonalized,
        ),

        const SizedBox(height: 16),

        // アクションボタン
        Row(
          children: [
            // 音声読み上げボタン
            if (onPlayAudio != null)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPlayAudio,
                  icon: Icon(
                    isSpeaking ? Icons.stop : Icons.volume_up,
                    size: 20,
                  ),
                  label: Text(isSpeaking ? '読み上げ停止' : '音声で聞く'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            if (onPlayAudio != null) const SizedBox(width: 12),

            // 再分析ボタン
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onRetry('all'),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('再分析'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPersonalized ? Colors.green[600] : Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 個人化分析への案内（基本分析時のみ）
        if (!isPersonalized) ...[
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
                const Text(
                  'ログインして好み設定を行うと、あなたの価値観に合わせた詳細な分析を提供します。',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // ログイン画面への遷移処理
                    // Navigator.pushNamed(context, '/login');
                  },
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('ログインして個人化分析'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
