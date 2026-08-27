from flask import Flask, Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

requests_total = Counter(
    "app_requests_total",
    "Total number of requests received by the application"
)


@app.before_request
def count_request():
    requests_total.inc()


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

