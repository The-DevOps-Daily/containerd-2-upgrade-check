# A stand-in registry mirror that only records the paths containerd asks for
# and answers 404, so containerd falls back to the upstream registry.
import http.server
import sys

log = open(sys.argv[2], "a", buffering=1)


class Handler(http.server.BaseHTTPRequestHandler):
    def handle_any(self):
        log.write(f"{self.command} {self.path}\n")
        self.send_response(404)
        self.end_headers()

    do_GET = do_HEAD = handle_any

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
