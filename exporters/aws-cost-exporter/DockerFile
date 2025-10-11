# exporters/aws-cost-exporter/Dockerfile

FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy exporter script
COPY exporter.py .

# Create non-root user
RUN useradd -m -u 1000 exporter && \
    chown -R exporter:exporter /app

USER exporter

# Expose metrics port
EXPOSE 9101

# Run exporter
CMD ["python", "-u", "exporter.py"]