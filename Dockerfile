# Use a specific, slim base image for reproducibility and reduced size
FROM python:3.12-slim-bookworm AS builder

# Set metadata labels for better documentation
LABEL maintainer="Sohel Mohammed <sohel879879@gmail.com>"
LABEL version="1.0"
LABEL description="EC2 Neon Pulse - A cyberpunk-style EC2 monitoring dashboard"

# Set working directory
WORKDIR /app

# Install build dependencies in a single layer, then clean up
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && pip install --no-cache-dir --upgrade pip \
    && apt-get purge -y --auto-remove build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy only requirements first to leverage caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Final stage - Multi-stage build for a lean runtime image
FROM python:3.12-slim-bookworm

# Install runtime dependencies (Redis) in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    redis-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy installed Python dependencies from builder stage
COPY --from=builder /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/

# Copy application code with correct ownership
COPY --chown=appuser:appuser app.py .
COPY --chown=appuser:appuser templates/ templates/
COPY --chown=appuser:appuser entrypoint.sh .

# Create a non-root user and set permissions *before* switching user
RUN useradd -m -r appuser && \
    chown appuser:appuser /app && \
    chmod +x entrypoint.sh

# Switch to non-root user
USER appuser

# Expose port 5001
EXPOSE 5001

# Set environment variables
ENV FLASK_APP=app.py
ENV FLASK_ENV=production
ENV PYTHONUNBUFFERED=1

# Healthcheck for container monitoring
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:5001/ || exit 1

# Use the entrypoint script
ENTRYPOINT ["./entrypoint.sh"]