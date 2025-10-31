#!/bin/bash
# macOS: base64 without line breaks
IMG_B64=$(base64 < ./src/test/input.png | tr -d '\n')

# Read token from .env (if it exists)
if [ -f ".env" ]; then
  TOKEN=$(grep '^TOKEN=' .env | cut -d '=' -f2-)
else
  TOKEN="your_secret_api_token_here"
fi

# Send request
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"image_b64\":\"$IMG_B64\"}"