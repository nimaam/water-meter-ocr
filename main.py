#!/usr/bin/env python3
# server.py — Python 3.9 compatible HTTP service for base64 → YOLO digits (JSON)

import os
import sys
import base64
from io import BytesIO
from pathlib import Path
import argparse

from flask import Flask, request, jsonify
import numpy as np
import cv2
from ultralytics import YOLO


# ---------------- Helpers ----------------
def resolve_path(default_rel, env_key, want_name=None, search_globs=None, override=None):
    """
    Resolve a file path with priority:
      1) CLI override (absolute or relative to project root)
      2) ENV var (absolute or relative to project)
      3) default_rel (relative to this script)
      4) search_globs (rglob under project)
    """
    base = Path(__file__).resolve().parent
    proj = base
    tried = []

    # CLI override
    if override:
        p = Path(override)
        if not p.is_absolute():
            p = proj / p
        tried.append(str(p))
        if p.exists():
            print(f"[OK] Using CLI for {want_name or default_rel.name}: {p}")
            return p

    # ENV
    env_val = os.getenv(env_key)
    if env_val:
        p = Path(env_val)
        if not p.is_absolute():
            p = proj / p
        tried.append(str(p))
        if p.exists():
            print(f"[OK] {env_key} -> {p}")
            return p
        else:
            print(f"[WARN] {env_key} set but not found: {p}")

    # default
    candidate = (proj / default_rel).resolve()
    tried.append(str(candidate))
    if candidate.exists():
        print(f"[OK] Using default {default_rel} -> {candidate}")
        return candidate
    else:
        print(f"[WARN] Not found at default: {candidate}")

    # search
    if search_globs:
        for pat in search_globs:
            matches = list(proj.rglob(pat))
            if matches:
                print(f"[OK] Found by search '{pat}': {matches[0]}")
                return matches[0]
            else:
                tried.append(f"{proj}/**/{pat}")

    # fail
    pretty = want_name or default_rel.name
    msg = [
        f"Could not locate {pretty}.",
        "Tried:",
        *("  - " + t for t in tried),
        f"Tip: set {env_key}=/absolute/path/to/{pretty} or start with --model <path>",
    ]
    raise FileNotFoundError("\n".join(msg))


def decode_base64_image(b64_str):
    """
    Accepts plain base64 or data URLs like 'data:image/png;base64,....'
    Returns a BGR numpy array suitable for OpenCV (cv2).
    """
    if not b64_str or not isinstance(b64_str, str):
        raise ValueError("image_b64 must be a base64 string")

    # Strip data URL header if present
    if "," in b64_str and ";base64" in b64_str[:64]:
        b64_str = b64_str.split(",", 1)[1]

    try:
        img_bytes = base64.b64decode(b64_str, validate=True)
    except Exception as e:
        raise ValueError(f"Invalid base64: {e}")

    nparr = np.frombuffer(img_bytes, dtype=np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Could not decode image from base64")
    return img


def detect_digits(model, img_bgr, labels=None):
    """
    Run YOLO on a BGR image and return the concatenated digit string.
    - Sort boxes left-to-right.
    """
    if labels is None:
        labels = [str(i) for i in range(10)]

    # NOTE: Ultralytics expects images as numpy arrays in BGR/RGB; works with BGR too
    results = model.predict(img_bgr, verbose=False)[0]

    boxes = []
    digits = []
    if results.boxes is not None and len(results.boxes) > 0:
        # results.boxes.data is (N, 6) [x1,y1,x2,y2,score,class_id]
        for r in results.boxes.data.tolist():
            x1, y1, x2, y2, score, class_id = r
            x1, y1, x2, y2, class_id = int(x1), int(y1), int(x2), int(y2), int(class_id)
            boxes.append([x1, y1, x2, y2, class_id])

    # sort left-to-right (x1), then top-to-bottom (y1)
    boxes.sort(key=lambda b: (b[0], b[1]))

    for (_, _, _, _, cid) in boxes:
        if 0 <= cid < len(labels):
            digits.append(labels[cid])
        else:
            digits.append(str(cid))

    return "".join(digits)


# ---------------- App Setup ----------------
def create_app(model_path):
    try:
        model = YOLO(str(model_path))
        print(f"[OK] YOLO model loaded: {model_path}")
    except Exception as e:
        raise RuntimeError(f"Failed to load YOLO weights from {model_path}: {e}")

    app = Flask(__name__)

    @app.route("/health", methods=["GET"])
    def health():
        return jsonify({"status": "ok"}), 200

    @app.route("/predict", methods=["POST"])
    def predict():
        """
        JSON body:
        {
          "image_b64": "<base64 or data URL>"
        }
        Response:
        {
          "result": "123456",
          "success": true
        }
        """
        try:
            payload = request.get_json(silent=True) or {}
            image_b64 = payload.get("image_b64")
            if not image_b64:
                return jsonify({"success": False, "error": "Missing 'image_b64'"}), 400

            img = decode_base64_image(image_b64)

            # If your training expects a certain size, you can resize here;
            # otherwise feed raw and let YOLO handle it.
            result_digits = detect_digits(model, img)

            return jsonify({"success": True, "result": result_digits}), 200

        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 400

    return app


def build_argparser():
    p = argparse.ArgumentParser(description="YOLO digits API server (base64 → JSON)")
    p.add_argument("--model", "-m", help="Path to YOLO .pt weights")
    p.add_argument("--port", "-p", type=int, default=8080, help="Port to listen on (default: 8080)")
    p.add_argument("--host", default="0.0.0.0", help="Host to bind (default: 0.0.0.0)")
    return p


def main():
    args = build_argparser().parse_args()

    model_path = resolve_path(
        default_rel=Path("src/models/model.pt"),
        env_key="MODEL_PATH",
        want_name="model.pt",
        search_globs=["**/model.pt", "**/*.pt"],
        override=args.model,
    )

    app = create_app(model_path)
    # threaded=True is fine here; use a proper WSGI server for production (gunicorn/uwsgi)
    app.run(host=args.host, port=args.port, threaded=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("[FATAL]", str(exc), file=sys.stderr)
        sys.exit(1)
