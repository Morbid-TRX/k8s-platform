FROM python:3.14-slim

RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

USER appuser

# WHY: No EXPOSE needed — worker doesn't accept inbound connections.
# Port 9000 for metrics is opened by prometheus_client internally.

CMD ["python", "main.py"]
