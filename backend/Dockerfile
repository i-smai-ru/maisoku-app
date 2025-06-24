# Dockerfile - MaisokuAI v1.0 Backend (Cloud Run)

FROM python:3.11-slim

# 作業ディレクトリ設定
WORKDIR /app

# システム依存関係インストール
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Python依存関係インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードコピー
COPY . .

# ポート設定 - Cloud Run用
EXPOSE 8080

# 非rootユーザーで実行
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# アプリケーション起動 - Cloud Run対応
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]