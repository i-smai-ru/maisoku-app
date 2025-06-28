# Maisoku AI v1.0

## 📱 プロジェクト概要

**Maisoku AI**（まいそくAI）は、AI技術を活用して住まい選びをサポートする不動産分析アプリです。カメラ撮影による物件分析とエリア別の住環境分析を組み合わせ、段階的認証システムであなたの理想の住まい探しをサポートします。

### ✨ 主要機能

- 📷 **カメラ分析**: 物件写真をAIが詳細分析（個人化分析・音声読み上げ・テキストコピー機能）
- 🗺️ **エリア分析**: 住所・駅名入力で交通・施設を包括分析（段階的個人化）
- 🔐 **段階的認証**: 基本分析（認証不要） → 個人化分析（ログイン時）
- 🔊 **音声読み上げ**: 分析結果の自動読み上げ（アクセシビリティ対応）
- 📋 **テキストコピー**: 分析結果をクリップボードにコピー（共有・保存用）
- 📊 **高品質フォーマット**: マークダウン形式の美しい分析結果表示

## 🏗️ アーキテクチャ

### 技術構成
```
Flutter App → Cloud Run (FastAPI) → Vertex AI Gemini → Firebase
```

### 技術スタック
- **Frontend**: Flutter 3.29+ (iOS 16.0+)
- **Backend**: FastAPI + Cloud Run
- **AI**: Vertex AI Gemini Pro Vision
- **Auth/Database**: Firebase (Auth + Firestore)
- **Infrastructure**: Google Cloud Platform
- **Audio**: Flutter TTS（音声読み上げ）

#### **Backend (Cloud Run)**
- **✅ 本番環境稼働中**: `https://maisoku-api-1028018777784.asia-northeast1.run.app`
- **✅ Vertex AI Gemini統合**: 画像・テキスト分析API
- **✅ 段階的認証システム**: Firebase Auth + JWT検証
- **✅ エラーハンドリング**: 包括的なAPI例外処理
- **✅ 画像最適化**: HEIF/HEIC → JPEG自動変換（最大2MB）
