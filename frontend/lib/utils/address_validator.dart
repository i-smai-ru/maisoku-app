// lib/utils/address_validator.dart

import 'constants.dart';

/// Maisoku AI v1.0: 住所バリデーション専用クラス
/// 日本の住所形式チェック・エラーメッセージ生成・信頼度判定
class AddressValidator {
  // === 住所タイプ定義 ===
  
  /// 住所の種別を定義
  enum AddressType {
    station,    // 駅名
    address,    // 通常の住所 
    landmark,   // ランドマーク
    unclear,    // 判別不明
  }

  // === 住所タイプ判定 ===
  
  /// 入力内容から住所タイプを自動判定
  static AddressType detectAddressType(String input) {
    if (!isValidInput(input)) return AddressType.unclear;

    final String cleanInput = normalizeInput(input);

    // 優先順位に従って判定
    if (_isStationName(cleanInput)) return AddressType.station;
    if (_isAddress(cleanInput)) return AddressType.address;
    if (_isLandmark(cleanInput)) return AddressType.landmark;

    return AddressType.unclear;
  }

  /// 駅名パターンの判定
  static bool _isStationName(String input) {
    // 駅名の典型的な語尾
    final List<String> stationSuffixes = [
      '駅', 'station', 'Station', 'STATION',
      '駅前', '駅南', '駅北', '駅東', '駅西',
    ];

    // 鉄道会社・路線の接頭語
    final List<String> railwayPrefixes = [
      'JR', 'jr', 'Jr',
      '地下鉄', 'メトロ', '私鉄',
      '東急', '京急', '小田急', '京王', '西武', '東武',
      '京成', '東京メトロ', '都営',
      '阪急', '阪神', '南海', '近鉄',
    ];

    // 路線・駅関連キーワード
    final List<String> stationKeywords = [
      '線', 'ライン', '本線', '支線', '新線',
      '口', '改札', 'ホーム', '番線',
      '中央改札', '東改札', '西改札', '南改札', '北改札',
    ];

    // 語尾チェック
    for (String suffix in stationSuffixes) {
      if (input.endsWith(suffix)) return true;
    }

    // 接頭語チェック
    for (String prefix in railwayPrefixes) {
      if (input.startsWith(prefix)) return true;
    }

    // キーワード含有チェック
    for (String keyword in stationKeywords) {
      if (input.contains(keyword)) return true;
    }

    return false;
  }

  /// 通常住所パターンの判定
  static bool _isAddress(String input) {
    // 日本の住所階層キーワード
    final List<String> prefectureKeywords = [
      '都', '道', '府', '県'
    ];
    
    final List<String> cityKeywords = [
      '市', '区', '町', '村'
    ];
    
    final List<String> streetKeywords = [
      '丁目', '番地', '番', '号',
      'ー', '−', '-', '–', // ハイフン類
    ];
    
    final List<String> buildingKeywords = [
      'マンション', 'アパート', 'ハイツ', 'コーポ',
      'ビル', 'タワー', 'ハウス', 'レジデンス',
      '棟', '階', '号室', '室',
    ];

    int matchCount = 0;
    
    // 都道府県レベル
    for (String keyword in prefectureKeywords) {
      if (input.contains(keyword)) {
        matchCount += 2; // 高い重み
        break;
      }
    }
    
    // 市区町村レベル
    for (String keyword in cityKeywords) {
      if (input.contains(keyword)) {
        matchCount += 2;
        break;
      }
    }
    
    // 街区レベル
    for (String keyword in streetKeywords) {
      if (input.contains(keyword)) {
        matchCount++;
        break;
      }
    }
    
    // 建物レベル
    for (String keyword in buildingKeywords) {
      if (input.contains(keyword)) {
        matchCount++;
        break;
      }
    }

    // 住所らしい数字パターンをチェック
    if (RegExp(r'\d+').hasMatch(input)) {
      matchCount++;
    }

    // 複数の住所要素を含む場合に住所と判定
    return matchCount >= 2;
  }

  /// ランドマークパターンの判定
  static bool _isLandmark(String input) {
    // 位置表現キーワード
    final List<String> locationKeywords = [
      '近く', '付近', '周辺', 'あたり', '界隈',
      'そば', 'となり', '隣', '向かい', '前',
    ];
    
    // 大型施設キーワード
    final List<String> facilityKeywords = [
      'ショッピングモール', 'イオン', 'ららぽーと',
      'デパート', '百貨店', '商店街',
      'アウトレット', 'ビックカメラ', 'ヨドバシ',
    ];
    
    // 公共施設・観光地キーワード
    final List<String> publicKeywords = [
      '公園', '神社', '寺', '教会',
      '病院', '大学', '学校', '高校',
      'タワー', 'スカイツリー', '東京駅',
      '渋谷', '新宿', '池袋', '銀座',
      '市役所', '区役所', '図書館',
    ];

    // いずれかのカテゴリにマッチするかチェック
    final List<List<String>> allCategories = [
      locationKeywords,
      facilityKeywords, 
      publicKeywords,
    ];

    for (List<String> category in allCategories) {
      for (String keyword in category) {
        if (input.contains(keyword)) return true;
      }
    }

    return false;
  }

  // === 入力バリデーション ===
  
  /// 入力内容の基本的な妥当性をチェック
  static bool isValidInput(String input) {
    final String trimmed = input.trim();
    
    // 空文字チェック
    if (trimmed.isEmpty) return false;
    
    // 文字数チェック
    if (trimmed.length < AppConstants.MIN_ADDRESS_LENGTH) return false;
    if (trimmed.length > AppConstants.MAX_ADDRESS_LENGTH) return false;

    // 特殊文字のみの入力を除外
    final RegExp specialCharsOnly = RegExp(r'^[^\p{L}\p{N}\s\-\(\)（）]+$', unicode: true);
    if (specialCharsOnly.hasMatch(trimmed)) return false;

    // 数字のみの入力を除外（郵便番号など）
    final RegExp numbersOnly = RegExp(r'^\d+$');
    if (numbersOnly.hasMatch(trimmed)) return false;

    return true;
  }

  /// リアルタイムバリデーション用エラーメッセージ生成
  static String getValidationErrorMessage(String input) {
    final String trimmed = input.trim();
    
    if (trimmed.isEmpty) {
      return '住所・駅名・ランドマークを入力してください';
    }

    if (trimmed.length < AppConstants.MIN_ADDRESS_LENGTH) {
      return '${AppConstants.MIN_ADDRESS_LENGTH}文字以上入力してください';
    }

    if (trimmed.length > AppConstants.MAX_ADDRESS_LENGTH) {
      return '${AppConstants.MAX_ADDRESS_LENGTH}文字以内で入力してください';
    }

    // 特殊文字のみチェック
    final RegExp specialCharsOnly = RegExp(r'^[^\p{L}\p{N}\s\-\(\)（）]+$', unicode: true);
    if (specialCharsOnly.hasMatch(trimmed)) {
      return '有効な住所・駅名・ランドマークを入力してください';
    }

    // 数字のみチェック
    final RegExp numbersOnly = RegExp(r'^\d+$');
    if (numbersOnly.hasMatch(trimmed)) {
      return '郵便番号ではなく住所を入力してください';
    }

    // 英字のみチェック
    final RegExp englishOnly = RegExp(r'^[a-zA-Z\s]+$');
    if (englishOnly.hasMatch(trimmed)) {
      return '日本語で住所を入力してください';
    }

    return ''; // エラーなし
  }

  // === 住所正規化 ===
  
  /// 住所入力の前処理・正規化
  static String normalizeInput(String input) {
    String normalized = input.trim();

    // 全角英数字を半角に変換
    normalized = _convertFullWidthToHalfWidth(normalized);

    // 複数の空白を単一に統一
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    // ハイフン類の統一
    normalized = normalized.replaceAll(RegExp(r'[ー−–—]'), '-');

    // 括弧の統一
    normalized = normalized.replaceAll('（', '(').replaceAll('）', ')');

    // 不要な記号を除去（日本語・数字・基本記号は残す）
    normalized = normalized.replaceAll(
      RegExp(r'[^\p{L}\p{N}\s\-\(\)（）]', unicode: true), 
      ''
    );

    return normalized.trim();
  }

  /// 全角英数字を半角に変換
  static String _convertFullWidthToHalfWidth(String input) {
    const String fullWidth = 
        '０１２３４５６７８９'
        'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ'
        'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ';
    const String halfWidth = 
        '0123456789'
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        'abcdefghijklmnopqrstuvwxyz';

    String result = input;
    for (int i = 0; i < fullWidth.length; i++) {
      result = result.replaceAll(fullWidth[i], halfWidth[i]);
    }

    return result;
  }

  // === 信頼度・品質評価 ===
  
  /// 住所の信頼度スコアを算出（0.0-1.0）
  static double calculateConfidenceScore(String input, AddressType type) {
    if (!isValidInput(input)) return 0.0;

    double score = 0.3; // ベーススコア

    // タイプ別スコア加算
    switch (type) {
      case AddressType.station:
        if (input.endsWith('駅')) score += 0.5;
        if (input.contains('JR') || input.contains('メトロ')) score += 0.1;
        if (input.contains('線')) score += 0.1;
        break;

      case AddressType.address:
        if (input.contains('都') || input.contains('県')) score += 0.2;
        if (input.contains('市') || input.contains('区')) score += 0.2;
        if (input.contains('丁目') || input.contains('番地')) score += 0.2;
        if (RegExp(r'\d+').hasMatch(input)) score += 0.1; // 数字含有
        break;

      case AddressType.landmark:
        if (input.contains('近く') || input.contains('付近')) score += 0.3;
        if (input.contains('公園') || input.contains('駅')) score += 0.2;
        break;

      case AddressType.unclear:
        score = 0.2; // 低い信頼度
        break;
    }

    // 文字数による調整
    final int length = input.length;
    if (length >= 10 && length <= 50) {
      score += 0.1; // 適切な長さ
    } else if (length <= 4) {
      score -= 0.2; // 短すぎる
    } else if (length > 80) {
      score -= 0.1; // 長すぎる
    }

    // 住所らしさの追加チェック
    if (_hasBalancedComponents(input)) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// 住所コンポーネントのバランスをチェック
  static bool _hasBalancedComponents(String input) {
    final bool hasKanji = RegExp(r'[\u4e00-\u9faf]').hasMatch(input);
    final bool hasHiragana = RegExp(r'[\u3040-\u309f]').hasMatch(input);
    final bool hasNumbers = RegExp(r'\d').hasMatch(input);
    
    // 漢字・ひらがな・数字のバランスをチェック
    int componentCount = 0;
    if (hasKanji) componentCount++;
    if (hasHiragana) componentCount++;
    if (hasNumbers) componentCount++;
    
    return componentCount >= 2; // 2種類以上の文字種を含む
  }

  /// 分析範囲の推奨値を取得（メートル）
  static int getRecommendedRadius(AddressType type, double confidence) {
    switch (type) {
      case AddressType.station:
        return confidence > 0.8 
          ? AppConstants.STATION_ANALYSIS_RADIUS 
          : AppConstants.UNCLEAR_ANALYSIS_RADIUS;

      case AddressType.address:
        return confidence > 0.8 
          ? AppConstants.DEFAULT_ANALYSIS_RADIUS 
          : AppConstants.UNCLEAR_ANALYSIS_RADIUS;

      case AddressType.landmark:
        return confidence > 0.7 
          ? AppConstants.LANDMARK_ANALYSIS_RADIUS 
          : AppConstants.UNCLEAR_ANALYSIS_RADIUS;

      case AddressType.unclear:
        return AppConstants.UNCLEAR_ANALYSIS_RADIUS;
    }
  }

  // === 住所候補の優先度付け ===
  
  /// 検索候補のスコアリング・ソート
  static List<T> prioritizeSuggestions<T>(
    List<T> suggestions,
    String input,
    String Function(T) getValue,
  ) {
    if (suggestions.isEmpty) return suggestions;

    final String normalizedInput = normalizeInput(input.toLowerCase());

    // スコア付きリストを作成
    List<MapEntry<T, double>> scoredSuggestions = suggestions.map((suggestion) {
      final String suggestionValue = getValue(suggestion).toLowerCase();
      final double score = _calculateSimilarityScore(normalizedInput, suggestionValue);
      return MapEntry(suggestion, score);
    }).toList();

    // スコア順でソート（降順）
    scoredSuggestions.sort((a, b) => b.value.compareTo(a.value));

    return scoredSuggestions.map((entry) => entry.key).toList();
  }

  /// 文字列の類似度スコア計算
  static double _calculateSimilarityScore(String input, String candidate) {
    if (candidate.isEmpty) return 0.0;
    if (input.isEmpty) return 0.0;

    // 完全一致
    if (candidate == input) return 1.0;

    // 前方一致（高スコア）
    if (candidate.startsWith(input)) return 0.9;

    // 部分一致（中スコア）
    if (candidate.contains(input)) return 0.7;

    // 文字レベルの類似度（低スコア）
    double characterMatch = 0.0;
    final List<String> inputChars = input.split('');
    final List<String> candidateChars = candidate.split('');

    for (String char in inputChars) {
      if (candidateChars.contains(char)) {
        characterMatch += 1.0 / input.length;
      }
    }

    return characterMatch * 0.4; // 最大0.4の部分スコア
  }

  // === 住所品質評価 ===
  
  /// 住所の品質グレードを判定
  static String getQualityGrade(double confidence) {
    if (confidence >= 0.9) return 'S'; // 優秀
    if (confidence >= 0.8) return 'A'; // 良好
    if (confidence >= 0.6) return 'B'; // 普通
    if (confidence >= 0.4) return 'C'; // 改善余地あり
    return 'D'; // 要改善
  }

  /// 品質グレードの説明文を取得
  static String getQualityDescription(String grade) {
    switch (grade) {
      case 'S': return '非常に正確な住所です';
      case 'A': return '正確な住所です';
      case 'B': return '利用可能な住所です';
      case 'C': return '住所の精度に注意が必要です';
      case 'D': return '住所の確認をお勧めします';
      default: return '住所を確認してください';
    }
  }

  // === デバッグ・開発支援 ===
  
  /// 住所分析の詳細情報を生成
  static Map<String, dynamic> generateAnalysisInfo(String input) {
    final String normalized = normalizeInput(input);
    final AddressType type = detectAddressType(input);
    final double confidence = calculateConfidenceScore(input, type);
    final String grade = getQualityGrade(confidence);
    final int radius = getRecommendedRadius(type, confidence);

    return {
      'original_input': input,
      'normalized_input': normalized,
      'address_type': type.toString().split('.').last,
      'confidence_score': confidence,
      'quality_grade': grade,
      'quality_description': getQualityDescription(grade),
      'recommended_radius': radius,
      'is_valid': isValidInput(input),
      'error_message': getValidationErrorMessage(input),
      'analysis_timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 住所タイプの日本語名を取得
  static String getAddressTypeDisplayName(AddressType type) {
    switch (type) {
      case AddressType.station: return '駅名';
      case AddressType.address: return '住所';
      case AddressType.landmark: return 'ランドマーク';
      case AddressType.unclear: return '不明';
    }
  }

  /// バリデーション設定の確認
  static bool validateConfiguration() {
    // 定数の整合性をチェック
    if (AppConstants.MIN_ADDRESS_LENGTH >= AppConstants.MAX_ADDRESS_LENGTH) {
      return false;
    }
    
    if (AppConstants.MIN_ADDRESS_CONFIDENCE >= AppConstants.HIGH_ADDRESS_CONFIDENCE) {
      return false;
    }
    
    return true;
  }
}