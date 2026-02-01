#!/usr/bin/env bash
set -euo pipefail

# Default port
PORT=${1:-3000}

echo "[Setup] Installing PM2 (cluster support)"
npm install -g pm2 >/dev/null 2>&1 || true
pm2 --version

echo "[Setup] Starting Kadmat API in cluster mode using PM2"
pm2 start backend/pm2.config.js --name kadmat-api

echo "[Status] PM2 processes:"
pm2 ls

echo "[Health] Quick health check (port $PORT)"
curl -sS http://localhost:$PORT/health || true

echo "Setup complete. Use 'pm2 logs kadmat-api' for logs and 'pm2 stop kadmat-api' to stop."
