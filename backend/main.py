# main.py - MaisokuAI v1.0 Backend (FastAPI + Vertex AI + Firebase + Google Maps)

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import base64
import json
import logging
import time
import os
import traceback
from datetime import datetime

# Google Cloud & AI
from google.cloud import aiplatform
import vertexai
from vertexai.generative_models import GenerativeModel, Part, FinishReason
import vertexai.preview.generative_models as generative_models

# Google Maps API
import googlemaps
from googlemaps.exceptions import ApiError

# Firebase
import firebase_admin
from firebase_admin import credentials, auth, firestore
from firebase_admin.exceptions import FirebaseError

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# === App Configuration ===

app = FastAPI(
    title="Real Estate Flyer API v1.0",
    description="MaisokuAI - カメラ分析とエリア分析API + Google Maps統合",
    version="1.0.0"
)

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "https://maisoku-hackathon-2025.web.app",
        "https://maisoku-hackathon-2025.firebaseapp.com"
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# === Configuration ===
PROJECT_ID = os.getenv('GOOGLE_CLOUD_PROJECT', 'maisoku-hackathon-2025')
LOCATION = os.getenv('VERTEX_AI_LOCATION', 'us-central1')
GOOGLE_MAPS_API_KEY = os.getenv('GOOGLE_MAPS_API_KEY')

# Security
security = HTTPBearer()

# === Firebase初期化 ===
firebase_available = False
db = None

try:
    if not firebase_admin._apps:
        # 環境変数からサービスアカウントキーを取得
        service_account_info = json.loads(os.getenv('FIREBASE_SERVICE_ACCOUNT_KEY'))
        cred = credentials.Certificate(service_account_info)
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    firebase_available = True
    logger.info("✅ Firebase initialized successfully")
except Exception as e:
    logger.error(f"❌ Firebase initialization failed: {e}")
    firebase_available = False

# === Vertex AI初期化 ===
vertex_ai_available = False
gemini_model = None
init_error = None

try:
    logger.info(f"🔍 Starting Vertex AI initialization...")
    logger.info(f"Project ID: {PROJECT_ID}")
    logger.info(f"Location: {LOCATION}")
    
    # Vertex AI初期化
    vertexai.init(project=PROJECT_ID, location=LOCATION)
    
    # Geminiモデル初期化 - 最新の利用可能モデル
    gemini_model = GenerativeModel("gemini-2.0-flash")
    
    vertex_ai_available = True
    logger.info("✅ Vertex AI + Gemini initialized successfully")
    
except Exception as e:
    init_error = str(e)
    error_trace = traceback.format_exc()
    logger.error(f"❌ Vertex AI initialization failed: {e}")
    logger.error(f"Error trace: {error_trace}")
    vertex_ai_available = False

# === Data Models ===

class UserPreferences(BaseModel):
    """ユーザー好み設定"""
    transportation_priority: int = Field(ge=1, le=5, description="交通利便性の重要度")
    facilities_priority: int = Field(ge=1, le=5, description="周辺施設の重要度")
    lifestyle_priority: int = Field(ge=1, le=5, description="ライフスタイルの重要度")
    budget_priority: int = Field(ge=1, le=5, description="予算の重要度")
    specific_facilities: list = Field(default=[], description="重視する具体的施設")
    transportation_types: list = Field(default=[], description="利用する交通手段")

class CameraAnalysisRequest(BaseModel):
    """カメラ分析リクエスト"""
    image: str = Field(description="Base64エンコードされた画像")
    preferences: Optional[UserPreferences] = None
    user_id: Optional[str] = None

class AreaAnalysisRequest(BaseModel):
    """エリア分析リクエスト"""
    address: str = Field(description="分析対象の住所")
    preferences: Optional[UserPreferences] = None
    user_id: Optional[str] = None

class AddressSuggestionsRequest(BaseModel):
    """住所候補取得リクエスト"""
    input: str = Field(description="入力された住所の一部")
    types: str = Field(default="address", description="候補のタイプ")
    country: str = Field(default="jp", description="国コード")

class GeocodingRequest(BaseModel):
    """GPS座標から住所取得リクエスト"""
    latitude: float = Field(description="緯度")
    longitude: float = Field(description="経度")

class AnalysisResponse(BaseModel):
    """分析結果レスポンス"""
    analysis: str = Field(description="AI分析結果")
    processing_time: float = Field(description="処理時間（秒）")
    is_personalized: bool = Field(description="個人化分析かどうか")
    timestamp: str = Field(description="分析実行時刻")
    metadata: Optional[Dict[str, Any]] = None

class AddressSuggestionsResponse(BaseModel):
    """住所候補レスポンス"""
    predictions: list = Field(description="住所候補リスト")
    status: str = Field(description="API呼び出し結果")

class GeocodingResponse(BaseModel):
    """住所取得レスポンス"""
    formatted_address: str = Field(description="整形された住所")
    latitude: float = Field(description="緯度")
    longitude: float = Field(description="経度")
    confidence: float = Field(description="信頼度")

# === Authentication ===

async def verify_firebase_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Firebase ID tokenの検証（認証必須）"""
    if not firebase_available:
        raise HTTPException(status_code=503, detail="Firebase service unavailable")
    
    try:
        token = credentials.credentials
        decoded_token = auth.verify_id_token(token)
        logger.info(f"Authenticated user: {decoded_token['uid']}")
        return decoded_token
        
    except Exception as e:
        logger.error(f"Authentication failed: {str(e)}")
        raise HTTPException(status_code=401, detail="Invalid authentication token")

async def get_optional_auth(authorization: Optional[str] = None) -> Optional[dict]:
    """段階的認証（認証任意）"""
    if not authorization or not firebase_available:
        return None
        
    try:
        if authorization.startswith('Bearer '):
            token = authorization[7:]
            decoded_token = auth.verify_id_token(token)
            logger.info(f"Optional auth successful: {decoded_token['uid']}")
            return decoded_token
        else:
            return None
    except Exception as e:
        logger.warning(f"Optional auth failed: {str(e)}")
        return None

# === Google Maps Service ===

class GoogleMapsService:
    """Google Maps API統合サービス"""
    
    def __init__(self):
        if not GOOGLE_MAPS_API_KEY:
            raise ValueError("Google Maps API key not found")
        self.client = googlemaps.Client(key=GOOGLE_MAPS_API_KEY)
    
    async def get_address_suggestions(self, input_text: str, types: str = "address", country: str = "jp"):
        """住所候補を取得"""
        try:
            result = self.client.places_autocomplete(
                input_text=input_text,
                types=types,
                components={'country': country},
                language='ja'
            )
            return result
        except ApiError as e:
            logger.error(f"Google Maps API error: {e}")
            raise HTTPException(status_code=500, detail="住所候補取得に失敗しました")
    
    async def reverse_geocode(self, latitude: float, longitude: float):
        """GPS座標から住所を取得"""
        try:
            result = self.client.reverse_geocode((latitude, longitude), language='ja')
            if result:
                return result[0]
            else:
                raise HTTPException(status_code=404, detail="住所が見つかりませんでした")
        except ApiError as e:
            logger.error(f"Reverse geocoding error: {e}")
            raise HTTPException(status_code=500, detail="住所取得に失敗しました")

# === Vertex AI Gemini Service ===

class GeminiService:
    """Vertex AI Gemini統合サービス"""
    
    def __init__(self):
        self.model = gemini_model
        
        # 安全設定
        self.safety_settings = {
            generative_models.HarmCategory.HARM_CATEGORY_HATE_SPEECH: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
            generative_models.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
            generative_models.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
            generative_models.HarmCategory.HARM_CATEGORY_HARASSMENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        }
        
        # 生成設定
        self.generation_config = {
            "max_output_tokens": 2048,
            "temperature": 0.7,
            "top_p": 0.8,
        }
    
    async def analyze_image(self, base64_image: str, preferences: Optional[UserPreferences] = None) -> str:
        """カメラ分析：画像から不動産チラシ情報を抽出・分析"""
        if not vertex_ai_available or not self.model:
            return "現在、AI分析サービスは利用できません。システム管理者にお問い合わせください。"
        
        try:
            # Base64デコードして画像データに変換
            image_data = base64.b64decode(base64_image)
            image_part = Part.from_data(mime_type="image/jpeg", data=image_data)
            
            # プロンプト生成
            prompt = self._create_camera_analysis_prompt(preferences)
            
            # Gemini Vision APIで分析
            response = self.model.generate_content(
                [image_part, prompt],
                generation_config=self.generation_config,
                safety_settings=self.safety_settings,
            )
            
            if response.candidates and response.candidates[0].finish_reason == FinishReason.STOP:
                return response.text
            else:
                logger.warning(f"Generation stopped due to: {response.candidates[0].finish_reason if response.candidates else 'No candidates'}")
                return "申し訳ございませんが、この画像の分析を完了できませんでした。別の画像でお試しください。"
                
        except Exception as e:
            logger.error(f"Image analysis error: {str(e)}")
            return f"画像分析中にエラーが発生しました: {str(e)}"
    
    async def analyze_area_basic(self, address: str) -> str:
        """基本エリア分析（認証不要）"""
        if not vertex_ai_available or not self.model:
            return "現在、エリア分析サービスは利用できません。"
        
        try:
            prompt = self._create_area_analysis_prompt_basic(address)
            
            response = self.model.generate_content(
                prompt,
                generation_config=self.generation_config,
                safety_settings=self.safety_settings,
            )
            
            if response.candidates and response.candidates[0].finish_reason == FinishReason.STOP:
                return response.text
            else:
                return "申し訳ございませんが、このエリアの分析を完了できませんでした。"
                
        except Exception as e:
            logger.error(f"Basic area analysis error: {str(e)}")
            return f"エリア分析中にエラーが発生しました: {str(e)}"
    
    async def analyze_area_personalized(self, address: str, preferences: UserPreferences) -> str:
        """個人化エリア分析（ログイン時）"""
        if not vertex_ai_available or not self.model:
            return "現在、個人化エリア分析サービスは利用できません。"
        
        try:
            prompt = self._create_area_analysis_prompt_personalized(address, preferences)
            
            response = self.model.generate_content(
                prompt,
                generation_config=self.generation_config,
                safety_settings=self.safety_settings,
            )
            
            if response.candidates and response.candidates[0].finish_reason == FinishReason.STOP:
                return response.text
            else:
                return "申し訳ございませんが、このエリアの個人化分析を完了できませんでした。"
                
        except Exception as e:
            logger.error(f"Personalized area analysis error: {str(e)}")
            return f"個人化エリア分析中にエラーが発生しました: {str(e)}"
    
    def _create_camera_analysis_prompt(self, preferences: Optional[UserPreferences]) -> str:
        """カメラ分析プロンプト生成"""
        base_prompt = """
この不動産チラシの画像を詳しく分析してください。

分析項目：
1. 間取り・部屋の構造
2. 設備・仕様（キッチン、バス、トイレ、収納等）
3. 内装・状態（壁紙、床材、清潔さ等）
4. 採光・通風
5. 住みやすさの総合評価

"""
        
        if preferences:
            personalized_prompt = f"""
【個人化分析】
ユーザーの好み設定：
- 交通利便性重要度: {preferences.transportation_priority}/5
- 周辺施設重要度: {preferences.facilities_priority}/5  
- ライフスタイル重要度: {preferences.lifestyle_priority}/5
- 予算重要度: {preferences.budget_priority}/5

この好み設定を考慮して、「あなたの価値観に合った」観点から物件を評価してください。
"""
            return base_prompt + personalized_prompt
        else:
            return base_prompt + "\n一般的な観点から客観的に分析してください。"
    
    def _create_area_analysis_prompt_basic(self, address: str) -> str:
        """基本エリア分析プロンプト"""
        return f"""
住所「{address}」の住環境を客観的に分析してください。

分析項目：
1. 交通アクセス（最寄り駅、バス路線、主要エリアへのアクセス）
2. 生活施設（スーパー、コンビニ、銀行、郵便局）
3. 医療・教育施設（病院、学校、図書館）
4. 商業・娯楽施設（商業施設、レストラン、公園）
5. 治安・環境（住宅地の特徴、騒音レベル）
6. 総合住みやすさ評価

一般的な住民の視点で、客観的で分かりやすい分析をお願いします。
"""
    
    def _create_area_analysis_prompt_personalized(self, address: str, preferences: UserPreferences) -> str:
        """個人化エリア分析プロンプト"""
        preference_text = f"""
【あなた専用の個人化分析】
あなたの重視する要素：
- 交通利便性: {preferences.transportation_priority}/5 {'(最重要)' if preferences.transportation_priority >= 4 else ''}
- 周辺施設: {preferences.facilities_priority}/5 {'(最重要)' if preferences.facilities_priority >= 4 else ''}
- ライフスタイル: {preferences.lifestyle_priority}/5 {'(最重要)' if preferences.lifestyle_priority >= 4 else ''}
- 予算: {preferences.budget_priority}/5 {'(最重要)' if preferences.budget_priority >= 4 else ''}
"""
        
        if preferences.specific_facilities:
            preference_text += f"- 特に重視する施設: {', '.join(preferences.specific_facilities)}\n"
        
        if preferences.transportation_types:
            preference_text += f"- よく利用する交通手段: {', '.join(preferences.transportation_types)}\n"
        
        return f"""
住所「{address}」をあなたの好みに合わせて詳細分析します。

{preference_text}

【あなた向けカスタム分析】
上記の好み設定を最重視して、以下の視点で分析してください：

1. あなたが重視する交通手段でのアクセス性
2. あなたが必要とする施設の充実度
3. あなたのライフスタイルに合った環境
4. あなたの予算感覚に見合った価値
5. 「あなたにとっての」住みやすさ総合評価

分析は「あなたの○○重視の好みにぴったり」「あなたのライフスタイルには」といった個人化された表現で行ってください。
"""

# サービスインスタンス
gemini_service = GeminiService()

# === API Endpoints ===

@app.get("/")
def root():
    return {
        "message": "Real Estate Flyer API v1.0 + Google Maps",
        "status": "running",
        "vertex_ai_available": vertex_ai_available,
        "firebase_available": firebase_available,
        "google_maps_available": GOOGLE_MAPS_API_KEY is not None,
        "project_id": PROJECT_ID,
        "location": LOCATION,
        "init_error": init_error,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
def health_check():
    """ヘルスチェック"""
    return {
        "status": "healthy",
        "service": "Real Estate Flyer API v1.0 + Google Maps",
        "vertex_ai_available": vertex_ai_available,
        "firebase_available": firebase_available,
        "google_maps_available": GOOGLE_MAPS_API_KEY is not None,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/debug")
def debug_info():
    """デバッグ情報エンドポイント"""
    import sys
    return {
        "vertex_ai_available": vertex_ai_available,
        "firebase_available": firebase_available,
        "google_maps_available": GOOGLE_MAPS_API_KEY is not None,
        "init_error": init_error,
        "project_id": PROJECT_ID,
        "location": LOCATION,
        "python_version": sys.version,
        "environment_vars": {
            "GOOGLE_CLOUD_PROJECT": os.getenv('GOOGLE_CLOUD_PROJECT'),
            "VERTEX_AI_LOCATION": os.getenv('VERTEX_AI_LOCATION'),
            "FIREBASE_SERVICE_ACCOUNT_KEY": "***" if os.getenv('FIREBASE_SERVICE_ACCOUNT_KEY') else None,
            "GOOGLE_MAPS_API_KEY": "***" if GOOGLE_MAPS_API_KEY else None,
        },
        "timestamp": datetime.now().isoformat()
    }

@app.post("/api/camera-analysis", response_model=AnalysisResponse)
async def camera_analysis(
    request: CameraAnalysisRequest,
    user: dict = Depends(verify_firebase_token)
):
    """カメラ分析API（認証必須）"""
    start_time = time.time()
    
    try:
        logger.info(f"Camera analysis request from user: {user['uid']}")
        
        # AI分析実行
        analysis_result = await gemini_service.analyze_image(
            request.image, 
            request.preferences
        )
        
        processing_time = time.time() - start_time
        
        # 履歴保存（Firestore）
        if firebase_available and db:
            try:
                history_data = {
                    "user_id": user["uid"],
                    "analysis": analysis_result,
                    "preferences": request.preferences.dict() if request.preferences else None,
                    "timestamp": datetime.now().isoformat(),
                    "processing_time": processing_time,
                    "analysis_type": "camera",
                    "app_version": "v1.0"
                }
                
                doc_ref = db.collection("users").document(user["uid"]).collection("analysisHistory").document()
                doc_ref.set(history_data)
                logger.info(f"History saved with ID: {doc_ref.id}")
                
            except Exception as e:
                logger.error(f"Failed to save history: {e}")
        
        logger.info(f"Camera analysis completed in {processing_time:.2f}s")
        
        return AnalysisResponse(
            analysis=analysis_result,
            processing_time=processing_time,
            is_personalized=request.preferences is not None,
            timestamp=datetime.now().isoformat(),
            metadata={
                "user_id": user["uid"],
                "firebase_available": firebase_available
            }
        )
        
    except Exception as e:
        logger.error(f"Camera analysis failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"カメラ分析に失敗しました: {str(e)}")

@app.post("/api/area-analysis", response_model=AnalysisResponse)
async def area_analysis(
    request: AreaAnalysisRequest,
    authorization: Optional[str] = None
):
    """エリア分析API（段階的認証）"""
    start_time = time.time()
    
    try:
        # 段階的認証チェック
        user = await get_optional_auth(authorization)
        
        if user and request.preferences:
            # ログイン時 + 好み設定あり → 個人化分析
            logger.info(f"Personalized area analysis for user: {user['uid']}")
            analysis_result = await gemini_service.analyze_area_personalized(
                request.address,
                request.preferences
            )
            is_personalized = True
        else:
            # 未ログイン or 好み設定なし → 基本分析
            logger.info("Basic area analysis (no auth or preferences)")
            analysis_result = await gemini_service.analyze_area_basic(request.address)
            is_personalized = False
        
        processing_time = time.time() - start_time
        
        logger.info(f"Area analysis completed in {processing_time:.2f}s")
        
        return AnalysisResponse(
            analysis=analysis_result,
            processing_time=processing_time,
            is_personalized=is_personalized,
            timestamp=datetime.now().isoformat(),
            metadata={
                "address": request.address,
                "user_id": user["uid"] if user else None
            }
        )
        
    except Exception as e:
        logger.error(f"Area analysis failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"エリア分析に失敗しました: {str(e)}")

@app.post("/api/address-suggestions", response_model=AddressSuggestionsResponse)
async def address_suggestions(request: AddressSuggestionsRequest):
    """住所候補取得API"""
    try:
        if not GOOGLE_MAPS_API_KEY:
            raise HTTPException(status_code=503, detail="Google Maps API is not configured")
        
        gmaps_service = GoogleMapsService()
        predictions = await gmaps_service.get_address_suggestions(
            request.input,
            request.types,
            request.country
        )
        
        return AddressSuggestionsResponse(
            predictions=predictions,
            status="success"
        )
    except Exception as e:
        logger.error(f"Address suggestions failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"住所候補取得に失敗しました: {str(e)}")

@app.post("/api/geocoding", response_model=GeocodingResponse)
async def geocoding(request: GeocodingRequest):
    """GPS座標から住所取得API"""
    try:
        if not GOOGLE_MAPS_API_KEY:
            raise HTTPException(status_code=503, detail="Google Maps API is not configured")
        
        gmaps_service = GoogleMapsService()
        result = await gmaps_service.reverse_geocode(
            request.latitude,
            request.longitude
        )
        
        return GeocodingResponse(
            formatted_address=result['formatted_address'],
            latitude=request.latitude,
            longitude=request.longitude,
            confidence=1.0
        )
    except Exception as e:
        logger.error(f"Geocoding failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"住所取得に失敗しました: {str(e)}")

@app.get("/api/analysis-history")
async def get_analysis_history(
    user: dict = Depends(verify_firebase_token),
    limit: int = 20
):
    """分析履歴取得API（認証必須）"""
    if not firebase_available or not db:
        raise HTTPException(status_code=503, detail="Firebase service unavailable")
    
    try:
        # Firestoreから履歴取得
        history_ref = (
            db.collection("users")
            .document(user["uid"])
            .collection("analysisHistory")
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )
        
        docs = history_ref.stream()
        history = []
        
        for doc in docs:
            doc_data = doc.to_dict()
            doc_data["id"] = doc.id
            history.append(doc_data)
        
        return {
            "history": history,
            "count": len(history),
            "user_id": user["uid"]
        }
        
    except Exception as e:
        logger.error(f"Failed to get analysis history: {str(e)}")
        raise HTTPException(status_code=500, detail="履歴取得に失敗しました")

@app.delete("/api/analysis-history/{history_id}")
async def delete_analysis_history(
    history_id: str,
    user: dict = Depends(verify_firebase_token)
):
    """分析履歴削除API（認証必須）"""
    if not firebase_available or not db:
        raise HTTPException(status_code=503, detail="Firebase service unavailable")
    
    try:
        doc_ref = (
            db.collection("users")
            .document(user["uid"])
            .collection("analysisHistory")
            .document(history_id)
        )
        
        doc_ref.delete()
        
        return {
            "message": "履歴を削除しました",
            "deleted_id": history_id
        }
        
    except Exception as e:
        logger.error(f"Failed to delete analysis history: {str(e)}")
        raise HTTPException(status_code=500, detail="履歴削除に失敗しました")

# === Startup Events ===

@app.on_event("startup")
async def startup_event():
    """アプリケーション起動時の処理"""
    logger.info("Real Estate Flyer API v1.0 + Google Maps started successfully")
    logger.info(f"Project ID: {PROJECT_ID}")
    logger.info(f"Vertex AI Location: {LOCATION}")
    logger.info(f"Vertex AI Available: {vertex_ai_available}")
    logger.info(f"Firebase Available: {firebase_available}")
    logger.info(f"Google Maps Available: {GOOGLE_MAPS_API_KEY is not None}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    logger.info(f"Starting server on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)