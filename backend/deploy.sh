#!/bin/bash
# deploy.sh - MaisokuAI v1.0 デプロイスクリプト (Google Maps API対応)

set -e

# 設定
PROJECT_ID="maisoku-hackathon-2025"
SERVICE_NAME="real-estate-flyer-api"
REGION="asia-northeast1"

echo "🚀 MaisokuAI v1.0 Backend デプロイ開始 (Google Maps API統合版)"

# プロジェクト設定
echo "📋 Google Cloud プロジェクト設定: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# 必要なAPIの有効化
echo "🔧 必要なAPIを有効化中..."
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable aiplatform.googleapis.com
# Google Maps API (新規追加)
gcloud services enable places-backend.googleapis.com
gcloud services enable geocoding-backend.googleapis.com
gcloud services enable maps-backend.googleapis.com

# Firebase Service Account Key をSecret Managerに保存（初回のみ）
echo "🔐 Firebase認証設定確認中..."
if ! gcloud secrets describe firebase-service-account --quiet; then
    echo "Firebase Service Account キーをSecret Managerに保存してください:"
    echo "1. Firebase Console > プロジェクト設定 > サービスアカウント"
    echo "2. 新しい秘密鍵を生成してダウンロード"
    echo "3. 以下のコマンドで Secret Manager に保存:"
    echo "   gcloud secrets create firebase-service-account --data-file=path/to/service-account-key.json"
    echo "4. このスクリプトを再実行してください"
    exit 1
fi

# Google Maps API Key をSecret Managerに保存（初回のみ）
echo "🗺️ Google Maps API設定確認中..."
if ! gcloud secrets describe google-maps-api-key --quiet; then
    echo "❌ Google Maps API キーがSecret Managerに保存されていません"
    echo ""
    echo "🔧 Google Maps API キーを設定してください:"
    echo "1. Google Cloud Console > APIs & Services > Credentials"
    echo "2. 「CREATE CREDENTIALS」> 「API key」をクリック"
    echo "3. API keyを作成後、以下のAPIを制限で有効化:"
    echo "   - Places API (New)"
    echo "   - Geocoding API"
    echo "   - Maps JavaScript API (オプション)"
    echo "4. 以下のコマンドでSecret Managerに保存:"
    echo "   echo 'YOUR_GOOGLE_MAPS_API_KEY' | gcloud secrets create google-maps-api-key --data-file=-"
    echo "5. このスクリプトを再実行してください"
    echo ""
    exit 1
fi

# IAM権限確認・設定
echo "🔑 Cloud Run サービスアカウント権限設定中..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER:-1028018777784}-compute@developer.gserviceaccount.com" \
    --role="roles/aiplatform.user" \
    --quiet || true

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER:-1028018777784}-compute@developer.gserviceaccount.com" \
    --role="roles/ml.developer" \
    --quiet || true

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER:-1028018777784}-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor" \
    --quiet || true

# Cloud Build でビルド・デプロイ
echo "🏗️ Cloud Build でビルド・デプロイ実行中..."
gcloud builds submit \
    --config=cloudbuild.yaml \
    .

# デプロイ確認
echo "✅ デプロイ完了確認中..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)")

# パブリックアクセス権限設定
echo "🔓 パブリックアクセス権限設定中..."
gcloud run services add-iam-policy-binding $SERVICE_NAME \
    --region=$REGION \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --quiet

echo "🎉 デプロイ完了！"
echo "📱 API URL: $SERVICE_URL"
echo "🔍 ヘルスチェック: $SERVICE_URL/health"
echo "📚 API ドキュメント: $SERVICE_URL/docs"
echo "🔧 デバッグ情報: $SERVICE_URL/debug"

# 動作確認
echo "🧪 基本動作確認中..."
if curl -f "$SERVICE_URL/health" > /dev/null 2>&1; then
    echo "✅ ヘルスチェック成功"
    
    # 詳細確認
    echo "📊 サービス詳細確認:"
    curl -s "$SERVICE_URL/" | jq '.'
else
    echo "❌ ヘルスチェック失敗"
    echo "ログを確認してください:"
    echo "gcloud logs read --project=$PROJECT_ID --limit=50 --filter=\"resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME\""
    exit 1
fi

echo ""
echo "🚀 MaisokuAI v1.0 Backend デプロイ完了！"
echo ""
echo "📋 次のステップ:"
echo "1. Flutter側のAPI URLを更新: $SERVICE_URL"
echo "2. Firebase設定ファイルを配置"
echo "3. API テスト実行:"
echo "   curl -X POST $SERVICE_URL/api/area-analysis \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"address\": \"東京都渋谷区\"}'"
echo ""
echo "🎯 利用可能なエンドポイント:"
echo "   GET  $SERVICE_URL/ (サービス状態)"
echo "   GET  $SERVICE_URL/health (ヘルスチェック)"
echo "   GET  $SERVICE_URL/debug (デバッグ情報)"
echo "   POST $SERVICE_URL/api/camera-analysis (カメラ分析・認証必須)"
echo "   POST $SERVICE_URL/api/area-analysis (エリア分析・段階的認証)"
echo "   POST $SERVICE_URL/api/address-suggestions (住所候補取得・新規)"
echo "   POST $SERVICE_URL/api/geocoding (GPS→住所変換・新規)"
echo "   GET  $SERVICE_URL/api/analysis-history (履歴取得・認証必須)"
echo ""
echo "🗺️ Google Maps API機能:"
echo "   ✅ Places API (住所候補取得)"
echo "   ✅ Geocoding API (GPS座標⇔住所変換)"
echo "   🔐 APIキーは Secret Manager で安全に管理"