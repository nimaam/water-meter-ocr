# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Trim locale/manpages
RUN set -eux; \
  echo 'path-exclude /usr/share/doc/*'      >  /etc/dpkg/dpkg.cfg.d/99_nodoc; \
  echo 'path-exclude /usr/share/man/*'      >> /etc/dpkg/dpkg.cfg.d/99_nodoc; \
  echo 'path-exclude /usr/share/locale/*'   >> /etc/dpkg/dpkg.cfg.d/99_nodoc; \
  echo 'path-include /usr/share/locale/en*' >> /etc/dpkg/dpkg.cfg.d/99_nodoc

# Only runtime libs you actually use (remove tesseract if not used)
RUN apt-get update && apt-get install -y --no-install-recommends \
      tesseract-ocr \
      tesseract-ocr-eng \
      libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -m -u 10001 appuser
WORKDIR /app

# Copy just requirement files first to leverage caching
# (accept either requirements.txt or requirement.txt)
COPY requirements.txt requirement.txt* ./
RUN set -eux; \
  req_file=""; \
  if [ -f requirements.txt ]; then req_file=requirements.txt; \
  elif [ -f requirement.txt ]; then req_file=requirement.txt; fi; \
  python -m pip install --upgrade pip; \
  if [ -n "$req_file" ]; then pip install --no-cache-dir -r "$req_file"; fi; \
  pip install --no-cache-dir opencv-python-headless

# Now copy only source code (not the whole repo history)
# Adjust the globs if your code lives elsewhere
COPY --chown=appuser:appuser main.py ./ 
# COPY other modules if you have them, e.g.:
# COPY --chown=appuser:appuser src/ ./src/
# COPY --chown=appuser:appuser app/ ./app/

EXPOSE 8080
USER appuser
CMD ["python", "main.py"]
