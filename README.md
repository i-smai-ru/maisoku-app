# Maisoku AI v1.0

## 📱 プロジェクト概要

**Maisoku AI**（まいそくAI）は、AI技術を活用して住まい選びをサポートする次不動産分析アプリです。カメラ撮影による物件分析とエリア別の住環境分析を組み合わせ、段階的認証システムであなたの理想の住まい探しをサポートします。

### ✨ 主要機能

- 📷 **カメラ分析**: 物件写真をAIが詳細分析（好み設定反映・履歴保存）
- 🗺️ **エリア分析**: 住所・駅名入力で交通・施設を包括分析（段階的個人化）
- 🔐 **段階的認証**: 基本分析（認証不要） → 個人化分析（ログイン時）
- 🔊 **音声読み上げ**: 分析結果の自動読み上げ（アクセシビリティ対応）

## 🏗️ アーキテクチャ

### 技術構成
```
Flutter App → Cloud Run (FastAPI) → Vertex AI Gemini → Firebase
```

### 技術スタック
- **Frontend**: Flutter 3.29+ (iOS)
- **Backend**: FastAPI + Cloud Run (本番環境稼働中)
- **AI**: Vertex AI Gemini Pro
- **Auth/Database**: Firebase (Auth + Firestore + Storage + Crashlytics)
- **Infrastructure**: Google Cloud Platform

#### **Backend (Cloud Run)**
- **✅ 本番環境稼働中**: `https://maisoku-api-1028018777784.asia-northeast1.run.app`
- **✅ Vertex AI Gemini統合**: 画像・テキスト分析API
- **✅ 段階的認証システム**: Firebase Auth + JWT検証
- **✅ エラーハンドリング**: 包括的なAPI例外処理

## 🚀 開発環境構築

### 前提条件

#### 必要なアカウント・設定
- Google Cloud Console アカウント
- Firebase プロジェクト設定済み
- 以下のAPI有効化済み:
  - Vertex AI API
  - Firebase APIs (Auth/Firestore/Storage)
  - Google Maps API (Geocoding + Places)


#### 1. Flutter環境確認
```bash
# Flutter バージョン確認
flutter --version

# システム状態チェック
flutter doctor

# 利用可能デバイス確認
flutter devices
```

#### 2. プロジェクトセットアップ
```bash
# プロジェクトクローン
git clone [repository-url]
cd maisoku-app/frontend

# 依存関係インストール
flutter pub get

# Firebase設定ファイル確認
ls ios/Runner/GoogleService-Info.plist    # iOS
```

#### 3. API設定
```bash
# lib/config/api_config.dart を作成
# 以下の内容で設定:
```

```dart
class ApiConfig {
  // Cloud Run API (本番環境)
  static const String cloudRunBaseUrl = 
    'https://your-api-xxxxxxxxx.asia-northeast1.run.app';
}
```

#### 4. アプリ起動
```bash
# 開発サーバー起動
flutter run

# 特定デバイスでの起動
flutter run -d macos                    # macOS
flutter run -d chrome                   # Web
flutter run -d [DEVICE_ID]              # iPhone実機

# リリースモード起動
flutter run --release -d [DEVICE_ID]
```

### 📷 カメラ分析フロー
1. **写真撮影 / ギャラリー選択**
2. **Cloud Run API → Vertex AI Gemini分析**
3. **個人化分析 (ログイン時: 好み設定反映)**
4. **音声読み上げ + 履歴保存**

### 🗺️ エリア分析フロー
1. **住所入力 (GPS取得 / 手動入力 / 候補選択)**
2. **段階的分析**:
   - 🔓 **未ログイン**: 基本分析 (客観的評価)
   - 🔐 **ログイン時**: 個人化分析 (好み設定反映)
3. **交通アクセス + 施設密度の統合分析**
4. **音声読み上げ (履歴保存なし)**

### 🔐 段階的認証システム
- **認証不要**: ホーム・基本分析・住所入力
- **認証必須**: 履歴保存・個人化分析・設定管理