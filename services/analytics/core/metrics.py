"""
Prometheus Metrics Server

Simple HTTP server that exposes /metrics endpoint.
"""

from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread


class _Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            self.send_response(200)
            self.send_header("Content-Type", CONTENT_TYPE_LATEST)
            self.end_headers()
            self.wfile.write(generate_latest())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, *args):
        pass


class MetricsServer:
    def __init__(self, port: int = 9090):
        self.port = port
        self._server = None
        self._thread = None
    
    def start(self):
        self._server = HTTPServer(("0.0.0.0", self.port), _Handler)
        self._thread = Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()
    
    def stop(self):
        if self._server:
            self._server.shutdown()
