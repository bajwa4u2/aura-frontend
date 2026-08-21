"""Serve the harness build and capture its report.

Same-origin on purpose: the page POSTs its report back to the server that
served it, so there is no CORS surface and no dependence on console
forwarding. The report is rewritten on every POST, so a run that dies late
still leaves every case that already finished on disk.
"""
import http.server
import json
import os
import sys
import threading

ROOT = sys.argv[1]
PORT = int(sys.argv[2])
OUT = sys.argv[3]

lock = threading.Lock()


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def do_POST(self):
        if self.path.rstrip('/').endswith('report'):
            length = int(self.headers.get('content-length', 0))
            body = self.rfile.read(length)
            with lock:
                with open(OUT, 'wb') as fh:
                    fh.write(body)
            try:
                data = json.loads(body)
                cases = data.get('cases', [])
                done = data.get('complete')
                sys.stderr.write(
                    'REPORT cases=%d complete=%s last=%s\n'
                    % (len(cases), done, cases[-1]['id'] if cases else '-')
                )
                sys.stderr.flush()
            except Exception as exc:  # pragma: no cover
                sys.stderr.write('report parse failed: %s\n' % exc)
            self.send_response(204)
            self.send_header('access-control-allow-origin', '*')
            self.end_headers()
            return
        self.send_error(404)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('access-control-allow-origin', '*')
        self.send_header('access-control-allow-headers', 'content-type')
        self.end_headers()

    def end_headers(self):
        # Never let a previous build's main.dart.js be reused: a stale bundle
        # attributed to the wrong design would be the worst possible failure
        # mode for a certification run.
        self.send_header('cache-control', 'no-store')
        super().end_headers()

    def log_message(self, fmt, *a):
        sys.stderr.write('GET ' + (fmt % a) + chr(10))
        sys.stderr.flush()


if os.path.exists(OUT):
    os.remove(OUT)

server = http.server.ThreadingHTTPServer(('127.0.0.1', PORT), Handler)
sys.stderr.write('serving %s on %d -> %s\n' % (ROOT, PORT, OUT))
sys.stderr.flush()
server.serve_forever()
