# WHY: python:3.14-slim not python:3.14 — slim removes dev tools and
# cuts image size from ~1GB to ~150MB. Smaller image = faster pulls,
# less attack surface, lower ECR storage cost.
FROM python:3.14-slim

# WHY: Create a non-root user. Running as root in a container is a
# security risk — if the app is compromised, the attacker gets root
# inside the container which makes escaping easier.
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# WHY: Copy requirements first, then code. Docker caches layers —
# if you copy everything at once, any code change invalidates the
# pip install layer and reinstalls all dependencies. This order means
# pip install only reruns when requirements.txt changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# WHY: Switch to non-root before running the app, not before pip install.
# pip needs to write to system directories which requires root.
USER appuser

EXPOSE 8000

# WHY: --host 0.0.0.0 makes uvicorn listen on all interfaces inside
# the container. Default 127.0.0.1 would be unreachable from outside
# the container — K8s health checks would fail.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
