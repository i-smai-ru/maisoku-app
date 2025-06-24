// lib/services/audio_service.dart

import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import './firestore_service.dart';

/// Maisoku AI v1.0: 音声読み上げサービス
///
/// 機能：
/// - AI分析結果の音声読み上げ
/// - ユーザー設定による音声ON/OFF制御
/// - 日本語対応・読み上げ速度調整
/// - プラットフォーム別最適化（iOS/Android）
class AudioService {
  final FlutterTts _flutterTts = FlutterTts();
  final StreamController<bool> _completedController =
      StreamController<bool>.broadcast();

  // 音声読み上げ完了状態のストリーム
  Stream<bool> get isCompleted => _completedController.stream;

  // 現在の音声読み上げ状態
  bool _isSpeaking = false;
  bool _isInitialized = false;
  String _currentLanguage = "ja-JP";
  double _speechRate = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;

  AudioService() {
    _initialize();
  }

  /// 初期化
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // 基本設定
      await _setupBasicSettings();

      // プラットフォーム別設定
      await _setupPlatformSpecificSettings();

      // イベントハンドラー設定
      _setupEventHandlers();

      _isInitialized = true;
      print('✅ AudioService初期化完了');
    } catch (e) {
      print('❌ AudioService初期化エラー: $e');
    }
  }

  /// 基本設定
  Future<void> _setupBasicSettings() async {
    await _flutterTts.setLanguage(_currentLanguage);
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setVolume(_volume);
  }

  /// プラットフォーム別設定
  Future<void> _setupPlatformSpecificSettings() async {
    if (Platform.isIOS) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );

      // iOS特有の設定
      await _flutterTts.setSharedInstance(true);
    } else if (Platform.isAndroid) {
      // Android特有の設定
      await _flutterTts.setQueueMode(0); // QUEUE_FLUSH
    }
  }

  /// イベントハンドラー設定
  void _setupEventHandlers() {
    // 読み上げ開始
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      _completedController.add(false);
      print('🔊 音声読み上げ開始');
    });

    // 読み上げ完了
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      _completedController.add(true);
      print('✅ 音声読み上げ完了');
    });

    // 読み上げキャンセル
    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      _completedController.add(true);
      print('⏹️ 音声読み上げキャンセル');
    });

    // エラーハンドリング
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      _completedController.add(true);
      print('❌ 音声読み上げエラー: $msg');
    });

    // 進行状況（プラットフォーム依存）
    _flutterTts.setProgressHandler(
        (String text, int startOffset, int endOffset, String word) {
      // 必要に応じて進行状況を処理
    });
  }

  /// 音声読み上げ実行
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await _initialize();
    }

    // ユーザー設定チェック
    final isAudioEnabled = await _checkUserAudioSetting();
    if (!isAudioEnabled) {
      print('🔇 ユーザー設定により音声は無効');
      _completedController.add(true);
      return;
    }

    // テキストの前処理
    final processedText = _preprocessText(text);
    if (processedText.isEmpty) {
      print('⚠️ 読み上げテキストが空です');
      _completedController.add(true);
      return;
    }

    try {
      // 既存の読み上げを停止
      if (_isSpeaking) {
        await stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('🔊 音声読み上げ開始: ${processedText.length}文字');
      await _flutterTts.speak(processedText);
    } catch (e) {
      print('❌ 音声読み上げエラー: $e');
      _isSpeaking = false;
      _completedController.add(true);

      // エラー時の代替処理
      await _handleSpeakError(e);
    }
  }

  /// 音声読み上げ停止
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      print('⏹️ 音声読み上げ停止');
    } catch (e) {
      print('❌ 音声停止エラー: $e');
    }
  }

  /// 一時停止
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      print('⏸️ 音声読み上げ一時停止');
    } catch (e) {
      print('❌ 音声一時停止エラー: $e');
    }
  }

  /// ユーザーの音声設定をチェック
  Future<bool> _checkUserAudioSetting() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final FirestoreService firestoreService = FirestoreService();
        final userAudioEnabled =
            await firestoreService.getUserAudioSetting(currentUser.uid);

        if (!userAudioEnabled) {
          print('🔇 ユーザー設定により音声は無効: ${currentUser.uid}');
          return false;
        }

        print('🔊 ユーザー設定により音声は有効: ${currentUser.uid}');
        return true;
      } else {
        print('🔊 未ログイン：音声はデフォルトで有効');
        return true; // 未ログイン時はデフォルトで有効
      }
    } catch (e) {
      print('❌ 音声設定取得エラー: $e');
      return true; // エラー時はデフォルトで有効
    }
  }

  /// テキストの前処理
  String _preprocessText(String text) {
    if (text.isEmpty) return '';

    String processed = text;

    // 不要な文字を除去
    processed = processed.replaceAll(RegExp(r'[【】『』「」〈〉《》]'), '');
    processed = processed.replaceAll(RegExp(r'[■□●○◆◇▲△▼▽]'), '');

    // 改行を句読点に変換
    processed = processed.replaceAll('\n', '。');
    processed = processed.replaceAll('\r', '');

    // 連続する句読点を整理
    processed = processed.replaceAll(RegExp(r'。+'), '。');
    processed = processed.replaceAll(RegExp(r'、+'), '、');

    // 長すぎるテキストを分割（flutter_ttsの制限対応）
    const maxLength = 4000;
    if (processed.length > maxLength) {
      processed = processed.substring(0, maxLength) + '。';
      print('⚠️ テキストを${maxLength}文字に制限しました');
    }

    return processed.trim();
  }

  /// 読み上げエラーのハンドリング
  Future<void> _handleSpeakError(dynamic error) async {
    // エラーの種類に応じた処理
    if (error.toString().contains('network') ||
        error.toString().contains('connection')) {
      print('🌐 ネットワークエラー：オフライン音声エンジンを試行');
      // オフライン音声エンジンの使用を試行
      await _tryOfflineEngine();
    } else if (error.toString().contains('language')) {
      print('🗣️ 言語エラー：英語での読み上げを試行');
      // 英語での読み上げを試行
      await _tryEnglishFallback();
    }
  }

  /// オフライン音声エンジンの試行
  Future<void> _tryOfflineEngine() async {
    try {
      // プラットフォーム固有のオフライン音声設定
      if (Platform.isAndroid) {
        await _flutterTts.setEngine("com.google.android.tts");
      }
    } catch (e) {
      print('❌ オフライン音声エンジン設定エラー: $e');
    }
  }

  /// 英語フォールバック
  Future<void> _tryEnglishFallback() async {
    try {
      await _flutterTts.setLanguage("en-US");
      print('🔄 英語モードに切り替え');
    } catch (e) {
      print('❌ 英語フォールバック失敗: $e');
    }
  }

  // === 設定変更メソッド ===

  /// 読み上げ速度を設定
  Future<void> setSpeechRate(double rate) async {
    try {
      _speechRate = rate.clamp(0.1, 2.0);
      await _flutterTts.setSpeechRate(_speechRate);
      print('🎚️ 読み上げ速度を設定: $_speechRate');
    } catch (e) {
      print('❌ 読み上げ速度設定エラー: $e');
    }
  }

  /// 音程を設定
  Future<void> setPitch(double pitch) async {
    try {
      _pitch = pitch.clamp(0.5, 2.0);
      await _flutterTts.setPitch(_pitch);
      print('🎵 音程を設定: $_pitch');
    } catch (e) {
      print('❌ 音程設定エラー: $e');
    }
  }

  /// 音量を設定
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _flutterTts.setVolume(_volume);
      print('🔊 音量を設定: $_volume');
    } catch (e) {
      print('❌ 音量設定エラー: $e');
    }
  }

  /// 言語を設定
  Future<void> setLanguage(String language) async {
    try {
      _currentLanguage = language;
      await _flutterTts.setLanguage(_currentLanguage);
      print('🗣️ 言語を設定: $_currentLanguage');
    } catch (e) {
      print('❌ 言語設定エラー: $e');
    }
  }

  // === 状態取得メソッド ===

  /// 現在読み上げ中かどうか
  bool get isSpeaking => _isSpeaking;

  /// 初期化済みかどうか
  bool get isInitialized => _isInitialized;

  /// 現在の設定を取得
  Map<String, dynamic> get currentSettings => {
        'language': _currentLanguage,
        'speechRate': _speechRate,
        'pitch': _pitch,
        'volume': _volume,
        'isSpeaking': _isSpeaking,
        'isInitialized': _isInitialized,
      };

  // === 利用可能な音声エンジン情報 ===

  /// 利用可能な言語を取得
  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages);
    } catch (e) {
      print('❌ 利用可能言語取得エラー: $e');
      return ['ja-JP', 'en-US']; // デフォルト
    }
  }

  /// 利用可能な音声を取得
  Future<List<Map<String, String>>> getAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return List<Map<String, String>>.from(voices);
    } catch (e) {
      print('❌ 利用可能音声取得エラー: $e');
      return [];
    }
  }

  /// 音声エンジンの情報を取得
  Future<String?> getDefaultEngine() async {
    try {
      return await _flutterTts.getDefaultEngine;
    } catch (e) {
      print('❌ デフォルト音声エンジン取得エラー: $e');
      return null;
    }
  }

  // === デバッグ・テスト用 ===

  /// テスト音声を再生
  Future<void> testSpeak() async {
    const testText = "これはMaisoku AIの音声テストです。正常に聞こえていますか？";
    await speak(testText);
  }

  /// 設定情報をデバッグ出力
  void printDebugInfo() {
    print('''
🔍 AudioService Debug Info:
  初期化状態: $_isInitialized
  読み上げ中: $_isSpeaking
  言語: $_currentLanguage
  読み上げ速度: $_speechRate
  音程: $_pitch
  音量: $_volume
  プラットフォーム: ${Platform.operatingSystem}
''');
  }

  /// リソースの解放
  void dispose() {
    try {
      // 読み上げ停止
      if (_isSpeaking) {
        _flutterTts.stop();
      }

      // StreamControllerのクローズ
      if (!_completedController.isClosed) {
        _completedController.close();
      }

      print('✅ AudioService リソース解放完了');
    } catch (e) {
      print('❌ AudioService リソース解放エラー: $e');
    }
  }
}
