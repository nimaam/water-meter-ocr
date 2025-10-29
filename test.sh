#!/bin/bash
# macOS: base64 without line breaks
IMG_B64=$(base64 < ./src/test/input.png | tr -d '\n')

curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d "{\"image_b64\":\"$IMG_B64\"}"
