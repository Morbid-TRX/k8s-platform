import time
import os
import signal
import logging
from prometheus_client import Counter, start_http_server

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s"
)
log = logging.getLogger("worker-service")

JOBS_PROCESSED = Counter(
    "worker_jobs_processed_total",
    "Total jobs processed",
    ["status", "tenant"]
)

TENANT = os.getenv("TENANT", "unknown")
ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")
SHUTDOWN = False


def handle_shutdown(signum, frame):
    # WHY: Graceful shutdown — finish the current job before exiting.
    # Without this, jobs get cut off mid-processing on every deploy.
    global SHUTDOWN
    log.info("Received shutdown signal, finishing current job...")
    SHUTDOWN = True


signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)


def process_job(job_id: int):
    log.info(f"Processing job {job_id} for tenant {TENANT}")
    time.sleep(2)
    JOBS_PROCESSED.labels(status="success", tenant=TENANT).inc()
    log.info(f"Job {job_id} completed")


if __name__ == "__main__":
    # WHY: Expose metrics on port 9000 so Prometheus can scrape the worker.
    start_http_server(9000)
    log.info(f"Worker started — tenant={TENANT} environment={ENVIRONMENT}")

    job_id = 0
    while not SHUTDOWN:
        job_id += 1
        try:
            process_job(job_id)
        except Exception as e:
            JOBS_PROCESSED.labels(status="error", tenant=TENANT).inc()
            log.error(f"Job {job_id} failed: {e}")
        time.sleep(5)

    log.info("Worker shutdown complete")
