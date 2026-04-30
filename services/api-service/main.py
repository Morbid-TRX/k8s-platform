from fastapi import FastAPI
from prometheus_client import Counter, Histogram, generate_latest
from prometheus_client import CONTENT_TYPE_LATEST
from starlette.responses import Response
import time
import os

app = FastAPI(title="API Service", version="1.0.0")

REQUEST_COUNT = Counter(
    "api_requests_total",
    "Total request count",
    ["method", "endpoint", "status"]
)
REQUEST_LATENCY = Histogram(
    "api_request_latency_seconds",
    "Request latency in seconds",
    ["endpoint"]
)

TENANT = os.getenv("TENANT", "unknown")
ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")


@app.get("/")
async def root():
    start = time.time()
    REQUEST_COUNT.labels(method="GET", endpoint="/", status="200").inc()
    REQUEST_LATENCY.labels(endpoint="/").observe(time.time() - start)
    return {
        "service": "api-service",
        "tenant": TENANT,
        "environment": ENVIRONMENT,
        "status": "ok"
    }


@app.get("/health")
async def health():
    # WHY: Liveness probe — if non-200, K8s restarts the pod.
    return {"status": "healthy"}


@app.get("/ready")
async def ready():
    # WHY: Readiness probe — K8s only sends traffic to pods that pass this.
    return {"status": "ready"}


@app.get("/metrics")
async def metrics():
    # WHY: Prometheus scrapes this endpoint for custom app metrics.
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/info")
async def info():
    return {
        "service": "api-service",
        "version": os.getenv("APP_VERSION", "unknown"),
        "tenant": TENANT,
        "environment": ENVIRONMENT,
    }
