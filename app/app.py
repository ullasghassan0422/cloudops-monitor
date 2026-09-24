from flask import Flask, Response, g
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)

# Total requests
requests_total = Counter(
    "app_requests_total",
    "Total number of requests received by the application"
)

# Total application errors
errors_total = Counter(
    "app_errors_total",
    "Total number of application errors"
)

# Request response time
request_duration = Histogram(
    "app_request_duration_seconds",
    "Application request response time in seconds"
)


@app.before_request
def before_request():
    requests_total.inc()
    g.start_time = time.time()


@app.after_request
def after_request(response):
    duration = time.time() - g.start_time
    request_duration.observe(duration)

    if response.status_code >= 400:
        errors_total.inc()

    return response

@app.route("/")
def home():
    return "CloudOps Monitor Application is running!"


@app.route("/health")
def health():
    return "Healthy"


@app.route("/metrics")
def metrics():
    return Response(
        generate_latest(),
        mimetype=CONTENT_TYPE_LATEST
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)