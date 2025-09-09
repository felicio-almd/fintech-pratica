# ---- Builder Stage: Installs dependencies ----
FROM python:3.11-slim as builder

# Create a virtual environment
RUN python -m venv /opt/venv

# Activate virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Final Stage: The actual image ----
FROM python:3.11-slim

# Create a non-root user
RUN groupadd -r appgroup && useradd --no-create-home --system --gid appgroup appuser

# Copy virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv

# Set the path to include the venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
WORKDIR /app
COPY main.py .

# Change ownership and switch to non-root user
RUN chown -R appuser:appgroup /app
USER appuser

# Expose port and run the application
EXPOSE 8081
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8081"]
