from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import os
import json

# 最小限のFirebase Admin SDK設定
try:
    import firebase_admin
    from firebase_admin import credentials, auth
    
    # Firebase Admin SDK初期化
    if not firebase_admin._apps:
        # 環境変数からサービスアカウントキーを取得
        service_account_key = os.getenv('FIREBASE_SERVICE_ACCOUNT_KEY')
        if service_account_key:
            service_account_info = json.loads(service_account_key)
            cred = credentials.Certificate(service_account_info)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK 初期化完了")
        else:
            print("⚠️ Firebase設定なし - 認証機能は無効")
            firebase_admin = None
except ImportError:
    print("⚠️ Firebase Admin SDK未インストール - 認証機能は無効")
    firebase_admin = None

app = FastAPI(title="Maisoku API - 認証テスト版")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 開発用：本番では具体的なドメインを指定
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# セキュリティ設定
security = HTTPBearer(auto_error=False)

# 🔐 認証検証関数（最小実装）
async def verify_auth_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Firebase IDトークンを検証（認証必須）"""
    if not credentials:
        raise HTTPException(status_code=401, detail="認証トークンが必要です")
    
    if not firebase_admin:
        raise HTTPException(status_code=500, detail="Firebase設定が無効です")
    
    try:
        decoded_token = auth.verify_id_token(credentials.credentials)
        return {
            'uid': decoded_token['uid'],
            'email': decoded_token.get('email', 'unknown'),
            'name': decoded_token.get('name', 'unknown')
        }
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"認証エラー: {str(e)}")

# 🔓 オプショナル認証関数（段階的認証用）
async def get_optional_auth(request: Request):
    """段階的認証：認証があれば取得、なければNone"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return None
        
        if not firebase_admin:
            return None
        
        token = auth_header.split(' ')[1]
        decoded_token = auth.verify_id_token(token)
        return {
            'uid': decoded_token['uid'],
            'email': decoded_token.get('email', 'unknown'),
            'name': decoded_token.get('name', 'unknown')
        }
    except:
        return None

# 📋 ヘルスチェック（認証不要）
@app.get("/health")
async def health_check():
    firebase_status = "有効" if firebase_admin else "無効"
    return {
        "status": "healthy",
        "firebase_auth": firebase_status,
        "message": "Maisoku API - 認証テスト版"
    }

# 🔐 認証必須エンドポイント（カメラ分析想定）
@app.post("/api/test-auth-required")
async def test_auth_required(user: dict = Depends(verify_auth_token)):
    """認証必須APIのテスト"""
    return {
        "success": True,
        "message": "認証成功！カメラ分析（履歴保存）が利用可能です",
        "user": {
            "uid": user['uid'],
            "email": user['email'],
            "name": user['name']
        },
        "feature": "camera_analysis_with_history"
    }

# 🔓 段階的認証エンドポイント（エリア分析想定）
@app.post("/api/test-optional-auth")
async def test_optional_auth(user: dict = Depends(get_optional_auth)):
    """段階的認証APIのテスト"""
    if user:
        return {
            "success": True,
            "message": "個人化エリア分析が利用可能です",
            "is_personalized": True,
            "user": {
                "uid": user['uid'],
                "email": user['email'],
                "name": user['name']
            }
        }
    else:
        return {
            "success": True,
            "message": "基本エリア分析が利用可能です",
            "is_personalized": False,
            "user": None
        }

# 📊 ユーザー情報取得（認証必須）
@app.get("/api/user/profile")
async def get_user_profile(user: dict = Depends(verify_auth_token)):
    """ユーザープロフィール取得"""
    return {
        "uid": user['uid'],
        "email": user['email'],
        "name": user['name'],
        "auth_status": "authenticated"
    }

# 🏠 Hello World（認証不要）
@app.get("/")
async def hello_world():
    return {"message": "Hello World from Maisoku API! 認証テスト準備完了"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)