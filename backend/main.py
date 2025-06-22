from fastapi import FastAPI
import os

# FastAPI アプリ作成
app = FastAPI(title="Maisoku API", version="1.0.0")

# Hello World エンドポイント
@app.get("/")
async def hello_world():
    return {"message": "Hello World from Maisoku API!"}

# ヘルスチェック (Cloud Run用)
@app.get("/health")
async def health_check():
    return {"status": "healthy"}
