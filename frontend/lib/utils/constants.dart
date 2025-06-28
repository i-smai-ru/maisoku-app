/// Maisoku AI v1.0: 統一定数管理クラス
/// Cloud Run API統合・段階的認証・Material Design 3対応
class AppConstants {
  // === Maisoku AI v1.0 基本情報 ===

  static const String APP_NAME = 'Maisoku AI';
  static const String APP_VERSION = '1.0.0';
  static const String APP_BUILD_NUMBER = '1';
  static const String APP_DESCRIPTION = 'あなたの住まい選びをサポート';
  static const String DATA_FORMAT_VERSION = '1.0';
  static const String API_VERSION = 'v1';
  static const String SCHEMA_VERSION = '1.0.0';

  // === Cloud Run API設定 ===

  // Cloud Run Base URL (本番環境)
  static const String CLOUD_RUN_BASE_URL =
      'https://maisoku-api-1028018777784.asia-northeast1.run.app';

  // Cloud Run APIエンドポイント
  static const String ENDPOINT_CAMERA_ANALYSIS = '/api/camera-analysis';
  static const String ENDPOINT_AREA_ANALYSIS = '/api/area-analysis';
  static const String ENDPOINT_ADDRESS_SUGGESTIONS = '/api/address-suggestions';
  static const String ENDPOINT_GEOCODING = '/api/geocoding';
  static const String ENDPOINT_HEALTH_CHECK = '/health';

  // API タイムアウト設定（Cloud Run最適化）
  static const int CLOUD_RUN_TIMEOUT_SECONDS = 60;
  static const int CAMERA_ANALYSIS_TIMEOUT_SECONDS = 90;
  static const int AREA_ANALYSIS_TIMEOUT_SECONDS = 45;
  static const int ADDRESS_SUGGESTIONS_TIMEOUT_SECONDS = 10;
  static const int GEOCODING_TIMEOUT_SECONDS = 15;
  static const int HEALTH_CHECK_TIMEOUT_SECONDS = 10;

  // リトライ設定
  static const int MAX_RETRY_COUNT = 3;
  static const int RETRY_DELAY_SECONDS = 2;
  static const int EXPONENTIAL_BACKOFF_BASE = 2;

  // === 段階的認証設定 ===

  // 認証モード
  static const String AUTH_MODE_BASIC = 'basic';
  static const String AUTH_MODE_PERSONALIZED = 'personalized';

  // 認証必須機能
  static const List<String> AUTH_REQUIRED_FEATURES = [
    'camera_analysis',
    'personalized_area_analysis',
    'user_preferences',
  ];

  // 認証不要機能
  static const List<String> AUTH_OPTIONAL_FEATURES = [
    'home_screen',
    'basic_area_analysis',
    'address_input',
  ];

  // === 住所バリデーション設定 ===

  // 住所入力制限
  static const int MIN_ADDRESS_LENGTH = 2;
  static const int MAX_ADDRESS_LENGTH = 100;
  static const int MAX_ADDRESS_SUGGESTIONS = 5;

  // 住所信頼度設定
  static const double MIN_ADDRESS_CONFIDENCE = 0.5;
  static const double HIGH_ADDRESS_CONFIDENCE = 0.8;
  static const double EXCELLENT_ADDRESS_CONFIDENCE = 0.9;

  // === エリア分析設定 ===

  // 分析範囲（メートル）
  static const int DEFAULT_ANALYSIS_RADIUS = 500;
  static const int STATION_ANALYSIS_RADIUS = 800;
  static const int LANDMARK_ANALYSIS_RADIUS = 600;
  static const int UNCLEAR_ANALYSIS_RADIUS = 1000;

  // 交通アクセス設定
  static const int WALKING_SPEED_M_PER_MIN = 80;
  static const int HIGHWAY_SEARCH_RADIUS = 10000;
  static const int MAX_STATIONS_DISPLAY = 3;
  static const int MAX_BUS_STOPS_DISPLAY = 2;
  static const int MAX_HIGHWAYS_DISPLAY = 2;

  // 施設検索設定
  static const int MAX_FACILITY_RESULTS = 20;
  static const int TOP_FACILITY_DISPLAY_COUNT = 5;

  // === AI分析設定 ===

  // 基本分析（認証不要）
  static const int BASIC_ANALYSIS_LENGTH_MIN = 150;
  static const int BASIC_ANALYSIS_LENGTH_MAX = 250;

  // 個人化分析（ログイン時）
  static const int PERSONALIZED_ANALYSIS_LENGTH_MIN = 200;
  static const int PERSONALIZED_ANALYSIS_LENGTH_MAX = 350;

  // カメラ分析
  static const int CAMERA_ANALYSIS_LENGTH_MIN = 250;
  static const int CAMERA_ANALYSIS_LENGTH_MAX = 400;

  // 画像設定
  static const int MAX_IMAGE_SIZE_MB = 10;
  static const int MAX_IMAGE_WIDTH = 2048;
  static const int MAX_IMAGE_HEIGHT = 2048;
  static const List<String> SUPPORTED_IMAGE_FORMATS = ['jpg', 'jpeg', 'png'];

  // === ユーザー好み設定 ===

  // ライフスタイルタイプ
  static const Map<String, String> LIFESTYLE_TYPES = {
    '': '選択してください',
    'single': '一人暮らし',
    'couple': '夫婦・カップル',
    'family_small': '小さなお子様がいる家族',
    'family_school': '学校に通うお子様がいる家族',
    'senior': 'シニア世代',
    'student': '学生',
    'remote_worker': 'リモートワーカー',
    'commuter': '通勤者',
  };

  // 予算優先度
  static const Map<String, String> BUDGET_PRIORITIES = {
    '': '選択してください',
    'cost_first': 'とにかく安く',
    'value_balance': 'コストパフォーマンス重視',
    'quality_first': '品質重視',
    'premium': 'プレミアム志向',
    'no_limit': '予算制限なし',
  };

  // === UI/UX設定（Material Design 3準拠） ===

  // 4タブ構成
  static const int TAB_HOME = 0;
  static const int TAB_CAMERA = 1;
  static const int TAB_AREA = 2;
  static const int TAB_MY_PAGE = 3; // ログイン時
  static const int TAB_LOGIN = 3; // 未ログイン時

  static const List<String> TAB_LABELS_LOGGED_IN = [
    'ホーム',
    'カメラ',
    'エリア',
    'マイページ',
  ];

  static const List<String> TAB_LABELS_LOGGED_OUT = [
    'ホーム',
    'カメラ',
    'エリア',
    'ログイン',
  ];

  // カラーテーマ（機能別）
  static const String COLOR_THEME_HOME = 'green';
  static const String COLOR_THEME_CAMERA = 'blue';
  static const String COLOR_THEME_AREA = 'green';
  static const String COLOR_THEME_MY_PAGE = 'purple';

  // Material Design 3サイズ
  static const double CARD_BORDER_RADIUS = 12.0;
  static const double BUTTON_BORDER_RADIUS = 8.0;
  static const double SMALL_BORDER_RADIUS = 6.0;
  static const double CHIP_BORDER_RADIUS = 16.0;

  // パディング・マージン
  static const double PADDING_TINY = 4.0;
  static const double PADDING_SMALL = 8.0;
  static const double PADDING_MEDIUM = 16.0;
  static const double PADDING_LARGE = 24.0;
  static const double PADDING_EXTRA_LARGE = 32.0;

  // アイコンサイズ
  static const double ICON_SIZE_TINY = 12.0;
  static const double ICON_SIZE_SMALL = 16.0;
  static const double ICON_SIZE_MEDIUM = 24.0;
  static const double ICON_SIZE_LARGE = 32.0;
  static const double ICON_SIZE_EXTRA_LARGE = 48.0;

  // === アニメーション設定 ===

  static const int ANIMATION_DURATION_MS = 300;
  static const int LOADING_ANIMATION_DURATION_MS = 1500;
  static const int PROGRESS_ANIMATION_DURATION_MS = 500;
  static const int PAGE_TRANSITION_DURATION_MS = 250;
  static const int SNACKBAR_DURATION_MS = 4000;

  // プログレス表示
  static const int AREA_ANALYSIS_PROGRESS_STEPS = 2;
  static const List<String> AREA_ANALYSIS_STEP_LABELS = [
    '交通アクセス分析',
    '施設密度分析',
  ];

  static const int CAMERA_ANALYSIS_PROGRESS_STEPS = 3;
  static const List<String> CAMERA_ANALYSIS_STEP_LABELS = [
    '画像アップロード',
    'AI分析処理',
    '結果生成',
  ];

  // === エラーハンドリング設定 ===

  // エラー表示時間
  static const int ERROR_DISPLAY_DURATION_SECONDS = 5;
  static const int SUCCESS_DISPLAY_DURATION_SECONDS = 3;
  static const int WARNING_DISPLAY_DURATION_SECONDS = 4;

  // エラー再試行設定
  static const int MAX_ERROR_RETRY_COUNT = 3;
  static const int ERROR_RETRY_DELAY_MS = 1000;

  // 品質指標
  static const double MIN_ACCEPTABLE_SUCCESS_RATE = 0.5;
  static const double TARGET_SUCCESS_RATE = 0.9;
  static const int MIN_FACILITIES_FOR_RELIABLE_ANALYSIS = 5;
  static const int MIN_STATIONS_FOR_GOOD_ACCESS = 1;

  // === 音声読み上げ設定 ===

  static const bool DEFAULT_AUDIO_ENABLED = true;
  static const double DEFAULT_SPEECH_RATE = 1.0;
  static const double MIN_SPEECH_RATE = 0.5;
  static const double MAX_SPEECH_RATE = 2.0;
  static const double SPEECH_RATE_STEP = 0.1;
  static const String DEFAULT_SPEECH_LANGUAGE = 'ja-JP';

  // === Firebase設定 ===

  // Firestore コレクション名
  static const String COLLECTION_USERS = 'users';
  static const String COLLECTION_PREFERENCES = 'preferences';
  static const String DOCUMENT_CURRENT_PREFERENCES = 'current';

  // Crashlytics設定
  static const int PERFORMANCE_SAMPLE_RATE = 10; // 10%サンプリング
  static const int SLOW_API_THRESHOLD_MS = 5000;
  static const int SLOW_CAMERA_ANALYSIS_THRESHOLD_MS = 15000;

  // === キャッシュ設定 ===

  static const int CACHE_DURATION_HOURS = 24;
  static const int MAX_CACHE_ENTRIES = 100;

  // === データ検証 ===

  // 座標の有効範囲（日本国内）
  static const double MIN_LATITUDE = 20.0;
  static const double MAX_LATITUDE = 46.0;
  static const double MIN_LONGITUDE = 122.0;
  static const double MAX_LONGITUDE = 154.0;

  // 距離の有効範囲
  static const double MIN_WALKING_DISTANCE = 0.0;
  static const double MAX_WALKING_DISTANCE = 5000.0;
  static const double MIN_DRIVING_DISTANCE = 0.0;
  static const double MAX_DRIVING_DISTANCE = 50000.0;

  // === エラーメッセージ定数 ===

  // ネットワークエラー
  static const String ERROR_NETWORK = 'ネットワークエラーが発生しました';
  static const String ERROR_TIMEOUT = 'タイムアウトが発生しました';
  static const String ERROR_CONNECTION = 'サーバーに接続できませんでした';
  static const String ERROR_NO_INTERNET = 'インターネット接続を確認してください';

  // 認証エラー
  static const String ERROR_AUTH_REQUIRED = 'この機能にはログインが必要です';
  static const String ERROR_AUTH_FAILED = 'ログインに失敗しました';
  static const String ERROR_PERMISSION_DENIED = 'この機能を利用する権限がありません';

  // Cloud Run APIエラー
  static const String ERROR_CLOUD_RUN_UNAVAILABLE = 'サービスが一時的に利用できません';
  static const String ERROR_ANALYSIS_FAILED = '分析に失敗しました';
  static const String ERROR_INVALID_REQUEST = 'リクエストの形式に問題があります';

  // データエラー
  static const String ERROR_INVALID_IMAGE = '画像が読み込めませんでした';
  static const String ERROR_IMAGE_TOO_LARGE = '画像サイズが制限を超えています';
  static const String ERROR_INVALID_ADDRESS = '有効な住所を入力してください';
  static const String ERROR_ADDRESS_NOT_FOUND = '住所が見つかりませんでした';

  // 権限エラー
  static const String ERROR_CAMERA_PERMISSION = 'カメラの使用許可が必要です';
  static const String ERROR_STORAGE_PERMISSION = 'ストレージの使用許可が必要です';
  static const String ERROR_LOCATION_PERMISSION = '位置情報の使用許可が必要です';

  // === 成功メッセージ定数 ===

  static const String SUCCESS_ANALYSIS_COMPLETED = '分析が完了しました';
  static const String SUCCESS_CAMERA_ANALYSIS_COMPLETED = 'カメラ分析が完了しました';
  static const String SUCCESS_AREA_ANALYSIS_COMPLETED = 'エリア分析が完了しました';
  static const String SUCCESS_PREFERENCES_SAVED = '設定を保存しました';
  static const String SUCCESS_LOGIN = 'ログインしました';
  static const String SUCCESS_LOGOUT = 'ログアウトしました';
  static const String SUCCESS_DATA_UPDATED = 'データを更新しました';

  // === 分析タイプ定数 ===

  static const String ANALYSIS_TYPE_CAMERA = 'camera_analysis';
  static const String ANALYSIS_TYPE_AREA = 'area_analysis';
  static const String ANALYSIS_MODE_BASIC = 'basic';
  static const String ANALYSIS_MODE_PERSONALIZED = 'personalized';

  // === ディープリンク設定 ===

  static const String DEEP_LINK_SCHEME = 'maisoku';
  static const String DEEP_LINK_CAMERA = '/camera';
  static const String DEEP_LINK_AREA = '/area';
  static const String DEEP_LINK_PREFERENCES = '/preferences';

  // === サポート・ヘルプ ===

  static const String SUPPORT_EMAIL = 'support@maisoku.ai';
  static const String HELP_URL = 'https://maisoku.ai/help';
  static const String PRIVACY_POLICY_URL = 'https://maisoku.ai/privacy';
  static const String TERMS_OF_SERVICE_URL = 'https://maisoku.ai/terms';
  static const String FEEDBACK_URL = 'https://maisoku.ai/feedback';

  // === 開発・デバッグ設定 ===

  static const bool IS_DEVELOPMENT = false;
  static const bool ENABLE_DEBUG_LOGGING = false;
  static const bool ENABLE_MOCK_DATA = false;
  static const bool ENABLE_PERFORMANCE_MONITORING = true;
  static const bool ENABLE_ANALYTICS = true;
  static const bool ENABLE_CRASH_REPORTING = true;

  // === 機能フラグ ===

  static const bool ENABLE_CAMERA_ANALYSIS = true;
  static const bool ENABLE_AREA_ANALYSIS = true;
  static const bool ENABLE_AUDIO_PLAYBACK = true;
  static const bool ENABLE_PUSH_NOTIFICATIONS = false;
  static const bool ENABLE_OFFLINE_MODE = false;

  // === レスポンシブデザイン ===

  static const double MOBILE_BREAKPOINT = 600.0;
  static const double TABLET_BREAKPOINT = 900.0;
  static const double DESKTOP_BREAKPOINT = 1200.0;

  // === ログレベル ===

  static const String LOG_LEVEL_DEBUG = 'DEBUG';
  static const String LOG_LEVEL_INFO = 'INFO';
  static const String LOG_LEVEL_WARNING = 'WARNING';
  static const String LOG_LEVEL_ERROR = 'ERROR';
  static const String LOG_LEVEL_CRITICAL = 'CRITICAL';

  // === 文字列ユーティリティ ===

  static const String UNIT_METERS = 'm';
  static const String UNIT_KILOMETERS = 'km';
  static const String UNIT_MINUTES = '分';
  static const String UNIT_SECONDS = '秒';
  static const String UNIT_COUNT = '件';
  static const String UNIT_PERCENT = '%';
  static const String UNIT_SCORE = '点';

  // === バリデーション設定 ===

  // 設定検証
  static List<String> validateAppConfiguration() {
    List<String> errors = [];

    // 基本設定検証
    if (AREA_ANALYSIS_PROGRESS_STEPS <= 0) {
      errors.add('無効なエリア分析ステップ数');
    }

    if (CAMERA_ANALYSIS_PROGRESS_STEPS <= 0) {
      errors.add('無効なカメラ分析ステップ数');
    }

    // 文字数設定検証
    if (BASIC_ANALYSIS_LENGTH_MIN >= BASIC_ANALYSIS_LENGTH_MAX) {
      errors.add('基本分析文字数設定が無効');
    }

    if (PERSONALIZED_ANALYSIS_LENGTH_MIN >= PERSONALIZED_ANALYSIS_LENGTH_MAX) {
      errors.add('個人化分析文字数設定が無効');
    }

    if (CAMERA_ANALYSIS_LENGTH_MIN >= CAMERA_ANALYSIS_LENGTH_MAX) {
      errors.add('カメラ分析文字数設定が無効');
    }

    // 住所バリデーション設定検証
    if (MIN_ADDRESS_LENGTH >= MAX_ADDRESS_LENGTH) {
      errors.add('住所長さ設定が無効');
    }

    // 閾値検証
    if (MIN_ADDRESS_CONFIDENCE >= HIGH_ADDRESS_CONFIDENCE) {
      errors.add('住所信頼度閾値設定が無効');
    }

    if (HIGH_ADDRESS_CONFIDENCE >= EXCELLENT_ADDRESS_CONFIDENCE) {
      errors.add('住所信頼度上位閾値設定が無効');
    }

    // 画像設定検証
    if (MAX_IMAGE_SIZE_MB <= 0) {
      errors.add('無効な画像サイズ制限');
    }

    if (MAX_IMAGE_WIDTH <= 0 || MAX_IMAGE_HEIGHT <= 0) {
      errors.add('無効な画像解像度制限');
    }

    // Cloud Run設定検証
    if (CLOUD_RUN_BASE_URL.isEmpty) {
      errors.add('Cloud Run Base URLが設定されていません');
    }

    if (CLOUD_RUN_TIMEOUT_SECONDS <= 0) {
      errors.add('無効なCloud Runタイムアウト設定');
    }

    return errors;
  }

  // 設定情報のサマリー生成
  static Map<String, dynamic> getConfigurationSummary() {
    return {
      'app_name': APP_NAME,
      'app_version': APP_VERSION,
      'api_version': API_VERSION,
      'cloud_run_url': CLOUD_RUN_BASE_URL,
      'auth_required_features': AUTH_REQUIRED_FEATURES.length,
      'auth_optional_features': AUTH_OPTIONAL_FEATURES.length,
      'supported_image_formats': SUPPORTED_IMAGE_FORMATS,
      'max_image_size_mb': MAX_IMAGE_SIZE_MB,
      'area_analysis_steps': AREA_ANALYSIS_PROGRESS_STEPS,
      'camera_analysis_steps': CAMERA_ANALYSIS_PROGRESS_STEPS,
      'min_address_length': MIN_ADDRESS_LENGTH,
      'max_address_length': MAX_ADDRESS_LENGTH,
      'tab_count': 4,
      'configuration_valid': validateAppConfiguration().isEmpty,
    };
  }
}
