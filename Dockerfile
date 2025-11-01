# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Avoid installing docs/manpages/locales to keep layers small
RUN set -eux; \
    echo 'path-exclude /usr/share/doc/*'         >  /etc/dpkg/dpkg.cfg.d/99_nodoc; \
    echo 'path-exclude /usr/share/man/*'         >> /etc/dpkg/dpkg.cfg.d/99_nodoc; \
    echo 'path-exclude /usr/share/locale/*'      >> /etc/dpkg/dpkg.cfg.d/99_nodoc; \
    echo 'path-include /usr/share/locale/en*'    >> /etc/dpkg/dpkg.cfg.d/99_nodoc

# Only what Tesseract + headless OpenCV typically need
# (libglib is required by many wheels; skip libgl1 since we use opencv-python-headless)
RUN apt-get update && apt-get install -y --no-install-recommends \
      tesseract-ocr \
      tesseract-ocr-eng \
      libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -m -u 10001 appuser
WORKDIR /app

# If your repo has "requirement.txt", copy it as requirements.txt for pip
COPY requirement.txt* requirements.txt

# Prefer headless OpenCV to avoid GL/Mesa pulls
# (If your requirements already pin it, this is a no-op)
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt opencv-python-headless

COPY . .
EXPOSE 8080
USER appuser
CMD ["python", "main.py"]
