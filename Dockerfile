# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.11

FROM python:${PYTHON_VERSION}-slim AS runtime

# Avoid interactive tzdata prompts etc.
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# System deps often needed by OpenCV / Pillow / Tesseract-based OCR stacks.
# If your app doesn't need some of these, you can remove them later.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      pkg-config \
      libgl1 \
      libglib2.0-0 \
      tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 10001 appuser
WORKDIR /app

# Copy and install Python deps first (for better layer caching)
# Your repo said "requirement.txt"; to be robust, we accept either.
COPY requirement.txt* requirements.txt
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copy the rest of the application
COPY . .

# Expose the port your app listens on
EXPOSE 8080

# Drop privileges
USER appuser

# If your main entrypoint is "python3 main.py", keep it simple:
CMD ["python", "main.py"]