// lib/screens/camera_ui_components.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'camera_core_handler.dart';
import '../services/audio_service.dart';

typedef UserActionCallback = void Function(String action,
    {Map<String, dynamic>? params});

class CameraUIComponents {
  final UserActionCallback onUserAction;

  CameraUIComponents({required this.onUserAction});

  Widget buildForState(
    BuildContext context,
    CameraAnalysisState state,
    User? currentUser,
    CameraCoreHandler coreHandler,
  ) {
    switch (state) {
      case CameraAnalysisState.authCheck:
        return _buildAuthCheckScreen();
      case CameraAnalysisState.loginRequired:
        return _buildLoginRequiredScreen();
      case CameraAnalysisState.initial:
        return _buildInitialScreen(context, currentUser, coreHandler);
      case CameraAnalysisState.photoChoice:
        return _buildPhotoChoiceScreen(context, coreHandler);
      case CameraAnalysisState.capturing:
        return _buildCapturingScreen(context, coreHandler);
      case CameraAnalysisState.analyzing:
        return _buildAnalyzingScreen(context, currentUser, coreHandler);
      case CameraAnalysisState.results:
        return _buildResultsScreen(context, currentUser, coreHandler);
    }
  }

  Widget _buildAuthCheckScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('認証確認中'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildLoginRequiredScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログインが必要'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'ログインが必要です',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'カメラ分析機能をご利用いただくには\nログインが必要です',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onUserAction('navigate_to_login'),
                  icon: const Icon(Icons.login),
                  label: const Text('ログインタブに移動'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialScreen(
      BuildContext context, User? currentUser, CameraCoreHandler coreHandler) {
    if (coreHandler.isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('カメラ分析'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('初期化中...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('カメラ分析'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // メインヘッダー
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'カメラ分析',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '物件写真をAIが詳細分析',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // メインアクションボタン
              ElevatedButton.icon(
                onPressed: coreHandler.isProcessingImage
                    ? null
                    : () => onUserAction('show_photo_choice'),
                icon: coreHandler.isProcessingImage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.camera_alt, size: 24),
                label: Text(
                  coreHandler.isProcessingImage ? '画像処理中...' : '写真を撮影・選択',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // ユーザー状態表示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: currentUser != null
                      ? Colors.green[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentUser != null
                        ? Colors.green[200]!
                        : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      currentUser != null
                          ? Icons.verified_user
                          : Icons.info_outline,
                      color: currentUser != null
                          ? Colors.green[600]
                          : Colors.orange[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentUser != null
                            ? 'ログイン済み：${currentUser.email}\n✅ 全ての機能を利用できます'
                            : '未ログイン状態\n🔓 基本機能は今すぐ利用できます',
                        style: TextStyle(
                          fontSize: 14,
                          color: currentUser != null
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // カメラ状態表示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: !coreHandler.cameraInitializationFailed
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !coreHandler.cameraInitializationFailed
                        ? Colors.green[200]!
                        : Colors.red[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      !coreHandler.cameraInitializationFailed
                          ? Icons.check_circle
                          : Icons.error,
                      color: !coreHandler.cameraInitializationFailed
                          ? Colors.green[600]
                          : Colors.red[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        !coreHandler.cameraInitializationFailed
                            ? 'カメラ利用可能'
                            : 'カメラ利用不可（ギャラリーのみ）',
                        style: TextStyle(
                          fontSize: 14,
                          color: !coreHandler.cameraInitializationFailed
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoChoiceScreen(
      BuildContext context, CameraCoreHandler coreHandler) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('写真選択'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => onUserAction('reset_analysis'),
        ),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                '写真の選択方法を選んでください',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // カメラ撮影ボタン（利用可能時のみ）
              if (!coreHandler.cameraInitializationFailed) ...[
                _buildSelectionCard(
                  icon: Icons.camera_alt,
                  iconColor: Colors.blue[600]!,
                  title: 'カメラで撮影',
                  subtitle: '物件写真や間取り図を直接撮影',
                  onTap: coreHandler.isProcessingImage
                      ? null
                      : () => onUserAction('start_camera_capture'),
                ),
                const SizedBox(height: 16),
              ],

              // ギャラリー選択ボタン
              _buildSelectionCard(
                icon: Icons.photo_library,
                iconColor: Colors.green[600]!,
                title: 'ギャラリーから選択',
                subtitle: '保存済みの写真から選択',
                onTap: coreHandler.isProcessingImage
                    ? null
                    : () => onUserAction('pick_from_gallery'),
              ),

              // 画像処理中の表示
              if (coreHandler.isProcessingImage) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Text('画像を最適化中...',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.blue[700]))),
                    ],
                  ),
                ),
              ],

              // カメラ利用不可時の説明
              if (coreHandler.cameraInitializationFailed) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange[600], size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'カメラが利用できません。ギャラリーから画像を選択してください。',
                          style: TextStyle(fontSize: 14),
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
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: onTap != null
                      ? iconColor.withOpacity(0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size: 32, color: onTap != null ? iconColor : Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: onTap != null ? null : Colors.grey,
                        )),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: onTap != null
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        )),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios, color: iconColor, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapturingScreen(
      BuildContext context, CameraCoreHandler coreHandler) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('撮影'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => onUserAction('show_photo_choice'),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(coreHandler),

          // 撮影ガイド
          Positioned(
            left: 0,
            right: 0,
            top: 100,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '物件情報・間取り図を撮影してください',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),

          // 撮影コントロール
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildCaptureControls(coreHandler),
          ),

          // 画像処理中のオーバーレイ
          if (coreHandler.isProcessingImage)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('画像を処理中...',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    SizedBox(height: 8),
                    Text('HEIF形式をJPEG形式に変換・最適化しています',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(CameraCoreHandler coreHandler) {
    if (!coreHandler.isCameraInitialized ||
        coreHandler.cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('カメラを準備中...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1 / coreHandler.cameraController!.value.aspectRatio,
      child: CameraPreview(coreHandler.cameraController!),
    );
  }

  Widget _buildCaptureControls(CameraCoreHandler coreHandler) {
    return Container(
      height: 120,
      color: Colors.black.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton.small(
            heroTag: 'gallery',
            backgroundColor: Colors.white,
            onPressed: coreHandler.isProcessingImage
                ? null
                : () => onUserAction('pick_from_gallery'),
            child: const Icon(Icons.photo_library, color: Colors.black87),
          ),
          FloatingActionButton.large(
            heroTag: 'capture',
            backgroundColor: Colors.white,
            onPressed: (coreHandler.isCameraInitialized &&
                    !coreHandler.isProcessingImage)
                ? () => onUserAction('take_picture')
                : null,
            child:
                const Icon(Icons.camera_alt, color: Colors.black87, size: 32),
          ),
          FloatingActionButton.small(
            heroTag: 'switch',
            backgroundColor: Colors.white,
            onPressed: (coreHandler.isCameraInitialized &&
                    !coreHandler.isProcessingImage)
                ? () => onUserAction('switch_camera')
                : null,
            child: const Icon(Icons.flip_camera_ios, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingScreen(
      BuildContext context, User? currentUser, CameraCoreHandler coreHandler) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析中'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => onUserAction('reset_analysis'),
        ),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
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
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 3),
                    const SizedBox(height: 24),
                    const Text('個人化AI分析中...',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Cloud Run APIで画像を解析しています',
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person,
                              color: Colors.green[600], size: 16),
                          const SizedBox(width: 8),
                          Text('${currentUser?.email ?? "ユーザー"} の好みを反映',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (coreHandler.selectedImage != null) ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(coreHandler.selectedImage!,
                        fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen(
      BuildContext context, User? currentUser, CameraCoreHandler coreHandler) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析結果'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => onUserAction('reset_analysis'),
        ),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          // 音声再生ボタン
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => _handleAudioPlay(context, coreHandler),
            tooltip: '音声で読み上げ',
          ),
          // コピーボタン
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _handleTextCopy(context, coreHandler),
            tooltip: 'テキストをコピー',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 成功ヘッダー
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green[600], size: 32),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('分析が完了しました！',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('AIがあなたの好みに合わせて物件を分析しました'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 操作ボタン行
              _buildActionButtons(context, coreHandler),

              const SizedBox(height: 16),

              // 分析結果表示
              if (coreHandler.analysisResult != null)
                Expanded(
                  child: _buildAnalysisResultCard(
                      context, coreHandler.analysisResult!),
                )
              else
                const Expanded(
                  child: Center(
                    child: Text('分析結果がありません'),
                  ),
                ),

              const SizedBox(height: 16),

              // メインアクションボタン
              ElevatedButton.icon(
                onPressed: () => onUserAction('reset_analysis'),
                icon: const Icon(Icons.refresh),
                label: const Text('別の写真を分析'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, CameraCoreHandler coreHandler) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleAudioPlay(context, coreHandler),
            icon: const Icon(Icons.volume_up),
            label: const Text('音声再生'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[600],
              side: BorderSide(color: Colors.blue[600]!),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleTextCopy(context, coreHandler),
            icon: const Icon(Icons.copy),
            label: const Text('コピー'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green[600],
              side: BorderSide(color: Colors.green[600]!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisResultCard(
      BuildContext context, dynamic analysisResult) {
    final String analysisText = analysisResult.analysis;
    final String formattedText = _formatAnalysisText(analysisText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text('個人化AI分析結果',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: _buildFormattedText(formattedText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // テキストのフォーマット処理
  String _formatAnalysisText(String text) {
    if (text.isEmpty) return '';

    String formatted = text;

    // エスケープシーケンスを実際の文字に変換
    formatted = formatted.replaceAll('\\n', '\n');
    formatted = formatted.replaceAll('\\t', '\t');

    return formatted;
  }

  // フォーマットされたテキストウィジェットを構築
  Widget _buildFormattedText(String text) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().isEmpty) {
        // 空行の場合
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      // マークダウン形式の処理
      if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
        // 太字見出し（**text**）
        final headingText = line.substring(2, line.length - 2);
        spans.add(TextSpan(
          text: headingText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ));
      } else if (line.trimLeft().startsWith('*   ')) {
        // リスト項目（*   text）
        final bulletText = line.trimLeft().substring(4);
        spans.add(TextSpan(
          text: '• $bulletText',
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.black87,
          ),
        ));
      } else if (line.trimLeft().startsWith('* ')) {
        // リスト項目（* text）
        final bulletText = line.trimLeft().substring(2);
        spans.add(TextSpan(
          text: '• $bulletText',
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.black87,
          ),
        ));
      } else {
        // 通常のテキスト内の**text**を太字に変換
        final parts = _parseInlineMarkdown(line);
        spans.addAll(parts);
      }

      // 最後の行でない場合は改行を追加
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.left,
    );
  }

  // インラインマークダウンの解析
  List<TextSpan> _parseInlineMarkdown(String text) {
    final List<TextSpan> spans = [];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // マッチ前のテキスト
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.black87,
          ),
        ));
      }

      // 太字テキスト
      spans.add(TextSpan(
        text: match.group(1) ?? '',
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ));

      lastEnd = match.end;
    }

    // 残りのテキスト
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.black87,
        ),
      ));
    }

    // マッチが見つからなかった場合
    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.black87,
        ),
      ));
    }

    return spans;
  }

  // 音声再生処理
  void _handleAudioPlay(
      BuildContext context, CameraCoreHandler coreHandler) async {
    if (coreHandler.analysisResult == null) {
      _showSnackBar(context, 'エラー：分析結果がありません', Colors.red);
      return;
    }

    try {
      // AudioService のインスタンスを作成
      final audioService = AudioService();

      // 分析結果のテキストを取得して音声再生
      final analysisText = coreHandler.analysisResult!.analysis;
      final cleanText = _cleanTextForAudio(analysisText);

      _showSnackBar(context, '音声再生を開始しています...', Colors.blue);

      // 音声再生
      await audioService.speak(cleanText);

      // 完了を監視
      audioService.isCompleted.listen((isCompleted) {
        if (isCompleted) {
          _showSnackBar(context, '音声再生が完了しました', Colors.green);
        }
      });
    } catch (e) {
      _showSnackBar(context, '音声再生でエラーが発生しました：$e', Colors.red);
    }
  }

  // テキストコピー処理
  void _handleTextCopy(BuildContext context, CameraCoreHandler coreHandler) {
    if (coreHandler.analysisResult == null) {
      _showSnackBar(context, 'エラー：分析結果がありません', Colors.red);
      return;
    }

    try {
      final analysisText = coreHandler.analysisResult!.analysis;
      final cleanText = _cleanTextForCopy(analysisText);

      Clipboard.setData(ClipboardData(text: cleanText));
      _showSnackBar(context, '分析結果をクリップボードにコピーしました', Colors.green);
    } catch (e) {
      _showSnackBar(context, 'コピーでエラーが発生しました：$e', Colors.red);
    }
  }

  // 音声用のテキストクリーニング
  String _cleanTextForAudio(String text) {
    String cleaned = text;

    // エスケープシーケンスを変換
    cleaned = cleaned.replaceAll('\\n', '\n');

    // マークダウン記号を除去
    cleaned = cleaned.replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'^\*\s+', multiLine: true), '');

    // 連続する改行を整理
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n'), '\n');

    return cleaned.trim();
  }

  // コピー用のテキストクリーニング
  String _cleanTextForCopy(String text) {
    String cleaned = text;

    // エスケープシーケンスを変換
    cleaned = cleaned.replaceAll('\\n', '\n');
    cleaned = cleaned.replaceAll('\\t', '\t');

    return cleaned.trim();
  }

  // スナックバー表示
  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
