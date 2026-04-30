FROM python:3.14-slim

# WHY: Non-root user — if the app is compromised, attacker doesn't get root.
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# WHY: Copy requirements first — Docker caches layers so pip install
# only reruns when requirements.txt changes, not on every code change.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

USER appuser

EXPOSE 8000

# WHY: --host 0.0.0.0 makes uvicorn listen on all interfaces.
# Default 127.0.0.1 would be unreachable from outside the container.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
