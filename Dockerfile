# Multi-stage Dockerfile for Tech Stack Advisor ML App

# Stage 1: Builder stage for training the model
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy training script and train the model
COPY train.py .
RUN python train.py

# Stage 2: Production runtime stage
FROM python:3.11-slim AS production

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash mluser

WORKDIR /app

# Copy Python packages from builder stage
COPY --from=builder /root/.local /home/mluser/.local

# Copy application files
COPY app.py .
COPY requirements.txt .

# Copy trained model from builder stage
COPY --from=builder /app/model.pkl .
COPY --from=builder /app/encoders.pkl .

# Set ownership and switch to non-root user
RUN chown -R mluser:mluser /app
USER mluser

# Make sure scripts in .local are usable
ENV PATH=/home/mluser/.local/bin:$PATH

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:7860', timeout=3)" || exit 1

EXPOSE 7860

CMD ["python", "app.py"]
