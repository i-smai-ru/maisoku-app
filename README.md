# maisoku-app

AI搭載の住まい分析アプリ - Google Cloud AI Agent Hackathon 2025 提出作品

## 📱 プロジェクト概要

**Maisoku**（まいそく）は、AI技術を活用して住まい選びをサポートする次世代不動産分析アプリです。カメラ撮影による物件分析とエリア別の住環境分析を組み合わせ、あなたの理想の住まい探しを科学的にサポートします。

### ✨ 主要機能

- 📷 **カメラ分析**: 物件写真をAIが詳細分析（好み設定反映・履歴保存）
- 🗺️ **エリア分析**: 住所・駅名入力で交通・施設を包括分析（段階的個人化）
- 🔐 **段階的個人化**: 基本分析（認証不要） → 個人化分析（ログイン時）

## 🏗️ アーキテクチャ

### 技術構成
```
Flutter App → Cloud Run (FastAPI) → Vertex AI Gemini → Firebase
```

### 技術スタック
- **Frontend**: Flutter 3.29+ (iOS/Android)
- **Backend**: FastAPI + Cloud Run
- **AI**: Vertex AI Gemini
- **Auth/Database**: Firebase (Auth + Firestore + Storage)
- **Infrastructure**: Google Cloud Platform

### プロジェクト構成
```
maisoku-app/
├── frontend/                    # Flutter アプリ
│   ├── lib/
│   │   ├── main.dart           # エントリポイント
│   │   ├── services/           # API・Firebase連携
│   │   ├── screens/            # UI画面
│   │   └── models/             # データモデル
│   ├── ios/                    # iOS設定
│   ├── android/                # Android設定
│   └── pubspec.yaml            # Flutter依存関係
├── backend/                     # FastAPI API
│   ├── main.py                 # FastAPI エントリポイント
│   ├── requirements.txt        # Python依存関係
│   ├── Dockerfile              # Cloud Run用
│   ├── docker-compose.yml      # 開発用
│   └── cloudbuild.yaml         # デプロイ設定
├── README.md                    # プロジェクト説明
└── .gitignore                   # Git除外設定
```

## 🚀 開発環境構築

### 前提条件

#### システム要件
- **OS**: macOS 14+ / Windows 10+ / Ubuntu 20.04+
- **Git**: 最新版
- **Docker**: 20.10+ & Docker Compose
- **Flutter**: 3.3.0+ (推奨: 3.29+)
- **VS Code**: 最新版 (推奨エディタ)

#### Google Cloud 要件
- Google Cloud Console アカウント
- 以下のAPI有効化:
  - Vertex AI API
  - Cloud Run API  
  - Firebase APIs

### 🐳 Backend (FastAPI) セットアップ

#### 1. Docker環境確認
```bash
# Docker バージョン確認
docker --version
docker-compose --version

# 期待される出力例:
# Docker version 24.0.x
# Docker Compose version v2.x.x
```

#### 2. Backend起動
```bash
# プロジェクトルートから backend ディレクトリに移動
cd backend

# 開発サーバー起動 (ホットリロード付き)
docker-compose up --build

# バックグラウンド実行の場合
docker-compose up --build -d

# ログ確認
docker-compose logs -f maisoku-api

# 停止
docker-compose down
```

#### 3. API動作確認
```bash
# ヘルスチェック
curl http://localhost:8080/health

# 期待される出力:
# {"status":"healthy"}

# ブラウザでAPI仕様確認
# http://localhost:8080/docs
```

#### 4. 本番環境テスト
```bash
# 本番用Dockerイメージビルド
docker build -t maisoku-api .

# 本番環境シミュレーション
docker run -p 8080:8080 maisoku-api
```

### 📱 Frontend (Flutter) セットアップ

#### 1. Flutter環境確認
```bash
# Flutter バージョン確認
flutter --version

# システム状態チェック
flutter doctor

# 利用可能デバイス確認
flutter devices

# 期待される出力:
# ✅ Flutter (Channel stable, 3.29.3+)
# ✅ Android toolchain
# ✅ Xcode (macOSの場合)
# ✅ VS Code
# ✅ Connected devices
```

#### 2. Frontend起動
```bash
# frontend ディレクトリに移動
cd frontend

# 依存関係インストール
flutter pub get

# 開発サーバー起動 (複数デバイス対応)
flutter run

# 特定デバイスでの起動例
flutter run -d macos                    # macOS
flutter run -d chrome                   # Web
flutter run -d [DEVICE_ID]              # iPhone/Android実機
```

## 🧪 開発ワークフロー

### 日常開発手順
```bash
# 1. Backend API サーバー起動
cd backend && docker-compose up -d

# 2. Flutter アプリ起動 (別ターミナル)
cd frontend && flutter run

# 3. 開発中...
# - Flutter: ホットリロードで即座反映
# - FastAPI: ファイル変更で自動再起動

# 4. 停止
docker-compose down  # Backend停止
# Flutter: ターミナルで 'q' 入力
```

### コード変更時の確認
```bash
# API 変更後の確認
curl http://localhost:8080/health

# Flutter 変更後の確認  
# アプリ内で 'r' (ホットリロード) または 'R' (ホットリスタート)
```

## 🚀 デプロイメント

### Cloud Run デプロイ
```bash
# Google Cloud CLI でログイン
gcloud auth login

# プロジェクト設定
gcloud config set project YOUR_PROJECT_ID

# Backend デプロイ
cd backend
gcloud run deploy maisoku-api \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

## 🔍 トラブルシューティング

### よくある問題と解決法

#### Docker 関連
```bash
# ポート競合エラー
docker-compose down
lsof -ti:8080 | xargs kill -9

# Docker イメージキャッシュ問題
docker-compose down
docker system prune -f
docker-compose up --build
```
