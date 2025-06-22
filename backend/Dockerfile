FROM python:3.11-slim

WORKDIR /app

# 依存関係インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードコピー
COPY . .

# Cloud Run用ポート設定
EXPOSE 8080

# アプリケーション実行
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
