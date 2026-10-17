#!/usr/bin/env python3
"""Same-origin reverse proxy so impeccable live mode works over an HTTPS tunnel.

Why this exists
---------------
live.js hardcodes its helper origin as 'http://localhost:' + PORT for ~14
endpoints (/events SSE, /source, /status, /annotation, /agent-target-*,
/manual-edit-*, /design-system*). The helper sends Access-Control-Allow-Methods
and Allow-Headers but NO Access-Control-Allow-Origin, so cross-origin is
impossible; and on an HTTPS devtunnels page, http://localhost:8400 is blocked as
mixed content and points at the viewer's own machine anyway.

Fix: serve the static pages AND the helper endpoints from ONE origin, rewriting
live.js's hardcoded URLs to same-origin relative paths in flight. The HTML on
disk is untouched -- the rewrite happens on the served bytes only -- so
`impeccable live-inject` keeps working normally.
"""
import re
import sys
import urllib.request
import urllib.error
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = sys.argv[1] if len(sys.argv) > 1 else '"$ARENA_WORKSPACE"/rewind'
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
HELPER = 'http://127.0.0.1:8400'

# Helper endpoints to reverse-proxy. Anything not listed is served from disk.
PROXY_PATHS = {
    '/live.js', '/events', '/source', '/status', '/annotation',
    '/agent-target-claim', '/agent-target-result',
    '/manual-edit-stash', '/manual-edit-commit', '/manual-edit-discard',
    '/manual-edit-repair-decision',
    '/design-system.json', '/design-system/raw',
    '/detect.js', '/modern-screenshot.js', '/params.json',
    '/poll', '/poll-reply', '/inject', '/live-inject', '/variant',
    '/variants', '/screenshot', '/annotation-image', '/config',
}

HOP_BY_HOP = {
    'connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization',
    'te', 'trailers', 'transfer-encoding', 'upgrade', 'content-length',
}


def patch_live_js(text):
    """Rewrite hardcoded helper origins into same-origin relative URLs."""
    # concatenation form: 'http://localhost:' + PORT + '/path'  ->  '/path'
    text = re.sub(
        r"""['"]http://localhost:['"]\s*\+\s*PORT\s*\+\s*['"](/[^'"]*?)['"]""",
        lambda m: "'" + m.group(1) + "'",
        text,
    )
    # template-literal form: `http://localhost:${PORT}/path`  ->  `/path`
    # MUST stay a backtick literal so ${TOKEN} etc. keep interpolating.
    text = re.sub(
        r"""`http://localhost:\$\{PORT\}(/[^`]*?)`""",
        lambda m: "`" + m.group(1) + "`",
        text,
    )
    # any remaining absolute localhost:8400 reference
    text = text.replace('http://localhost:8400', '')
    return text


class Handler(SimpleHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def log_message(self, fmt, *args):
        sys.stderr.write('[proxy] %s\n' % (fmt % args))

    def _cors_preflight(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Access-Control-Max-Age', '86400')
        self.send_header('Content-Length', '0')
        self.end_headers()

    def _proxy(self, method):
        path = self.path
        url = HELPER + path
        length = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(length) if length else None

        req = urllib.request.Request(url, data=body, method=method)
        for h, v in self.headers.items():
            if h.lower() in HOP_BY_HOP or h.lower() == 'host':
                continue
            req.add_header(h, v)

        try:
            r = urllib.request.urlopen(req, timeout=None)
        except urllib.error.HTTPError as e:
            r = e
        except Exception as e:
            self.send_error(502, 'helper unreachable: %s' % e)
            return

        ctype = r.headers.get('Content-Type', '')
        self.send_response(r.status)
        for h, v in r.headers.items():
            if h.lower() in HOP_BY_HOP:
                continue
            self.send_header(h, v)
        self.send_header('Access-Control-Allow-Origin', '*')

        # SSE: stream without buffering, keep the connection open.
        if 'text/event-stream' in ctype:
            self.send_header('Transfer-Encoding', 'chunked')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('X-Accel-Buffering', 'no')
            self.end_headers()
            try:
                while True:
                    chunk = r.read1(4096) if hasattr(r, 'read1') else r.read(4096)
                    if not chunk:
                        break
                    self.wfile.write(b'%x\r\n' % len(chunk))
                    self.wfile.write(chunk)
                    self.wfile.write(b'\r\n')
                    self.wfile.flush()
                self.wfile.write(b'0\r\n\r\n')
                self.wfile.flush()
            except Exception:
                pass
            finally:
                try:
                    r.close()
                except Exception:
                    pass
            return

        data = r.read()
        if path.split('?')[0] == '/live.js':
            text = data.decode('utf-8', 'replace')
            patched = patch_live_js(text)
            n = text.count('http://localhost:') - patched.count('http://localhost:')
            sys.stderr.write('[proxy] live.js patched: %d localhost refs removed, '
                             '%d remain\n' % (n, patched.count('http://localhost:')))
            data = patched.encode('utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except Exception:
            pass

    def do_OPTIONS(self):
        self._cors_preflight()

    def do_GET(self):
        if self.path.split('?')[0] in PROXY_PATHS:
            return self._proxy('GET')
        return self._serve_html_or_static()

    def do_POST(self):
        if self.path.split('?')[0] in PROXY_PATHS:
            return self._proxy('POST')
        self.send_error(405)

    def _serve_html_or_static(self):
        """Serve from disk; rewrite the injected script src to same-origin."""
        path = self.path.split('?')[0]
        if not path.endswith('.html') and path != '/':
            return super().do_GET()
        target = path if path != '/' else '/index.html'
        try:
            with open(ROOT + target, 'rb') as f:
                data = f.read()
        except OSError:
            return super().do_GET()
        text = data.decode('utf-8', 'replace')
        new = re.sub(r'src="http://localhost:8400(/live\.js\?[^"]*)"',
                     r'src="\1"', text)
        changed = new != text
        data = new.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except Exception:
            pass
        if changed:
            sys.stderr.write('[proxy] rewrote script src in %s\n' % target)


if __name__ == '__main__':
    sys.stderr.write('[proxy] root=%s port=%d helper=%s\n' % (ROOT, PORT, HELPER))
    ThreadingHTTPServer(('0.0.0.0', PORT), Handler).serve_forever()
