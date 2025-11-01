# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Keep apt small: no docs/manpages/locales
RUN set -eux; \
  echo 'path-exclude /usr/share/doc/*'      >  /etc/dpkg/dpkg.cfg.d/99_nodoc; \
  echo 'path-exclude /usr/share/man/*'      >> /etc/dpkg/dpkg.cfg.d/99_nodoc; \
  echo 'path-exclude /usr/share/locale/*'   >> /etc/dpkg/dpkg.cfg.d/99_nodoc; \
  echo 'path-include /usr/share/locale/en*' >> /etc/dpkg/dpkg.cfg.d/99_nodoc

# Minimal runtime deps (headless)
RUN apt-get update && apt-get install -y --no-install-recommends \
      tesseract-ocr \
      tesseract-ocr-eng \
      libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# App setup
RUN useradd -m -u 10001 appuser
WORKDIR /app

# Bring the repo in first so we can see whichever requirements file you have
COPY . .

# Install Python deps, tolerating either filename (or none)
RUN set -eux; \
  REQ=""; \
  if [ -f requirements.txt ]; then REQ=requirements.txt; \
  elif [ -f requirement.txt ]; then REQ=requirement.txt; fi; \
  python -m pip install --upgrade pip; \
  if [ -n "$REQ" ]; then pip install --no-cache-dir -r "$REQ"; fi; \
  pip install --no-cache-dir opencv-python-headless

EXPOSE 8080
USER appuser
CMD ["python", "main.py"]
