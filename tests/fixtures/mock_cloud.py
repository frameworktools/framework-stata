"""A minimal Framework Cloud for Framework for Stata's tests.

Standard library only. Serves the device login flow, /api/v1/me, token
revocation, document uploads, the ledger, and external artifact tracking. Tokens are fake.

    python3 mock_cloud.py <port> <log.jsonl>
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

USER_TOKEN = "fw_test_user_token_0123456789"
PROJECT_TOKEN = "fw_test_project_token_0123456789"
polls = {"count": 0}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _record(self, body: bytes):
        auth = self.headers.get("Authorization", "")
        entry = {
            "method": self.command,
            "path": self.path,
            "auth": "user" if auth == f"Bearer {USER_TOKEN}" else "project" if auth == f"Bearer {PROJECT_TOKEN}" else ("other" if auth else "none"),
            "content_type": self.headers.get("Content-Type", ""),
            "user_agent": self.headers.get("User-Agent", ""),
            "bytes": len(body),
        }
        if body and "json" in entry["content_type"]:
            entry["json"] = json.loads(body)
        if body and "multipart" in entry["content_type"]:
            text = body.decode("utf-8", "replace")
            fields = {}
            for part in text.split("Content-Disposition: form-data; name=\"")[1:]:
                name = part.split("\"", 1)[0]
                head, _, rest = part.partition("\r\n\r\n")
                value = rest.rsplit("\r\n--", 1)[0]
                fields[name] = value if "filename=" not in head else {"filename": head.split("filename=\"", 1)[1].split("\"", 1)[0], "bytes": len(value)}
            entry["form"] = fields
        with open(sys.argv[2], "a", encoding="utf-8") as log:
            log.write(json.dumps(entry) + "\n")
        return entry

    def _send(self, status: int, payload):
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        entry = self._record(b"")
        if self.path == "/api/v1/me":
            if entry["auth"] == "user":
                return self._send(200, {"user": {"name": "Test User", "email": "test@example.org"}})
            if entry["auth"] == "project":
                return self._send(200, {"project": {"slug": "example-study"}})
            return self._send(401, {"message": "Unauthenticated."})
        self._send(404, {"message": "Not found"})

    def do_DELETE(self):
        entry = self._record(b"")
        if self.path == "/api/v1/token":
            if entry["auth"] == "user":
                self.send_response(204)
                self.end_headers()
                return
            return self._send(401, {"message": "Unauthenticated."})
        self._send(404, {"message": "Not found"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or 0)
        body = self.rfile.read(length)
        entry = self._record(body)
        port = self.server.server_address[1]
        base = f"http://127.0.0.1:{port}"
        if self.path.startswith("/reject/"):
            return self._send(401, {"message": "Unauthenticated."})
        if self.path == "/api/v1/cli/device":
            return self._send(200, {
                "device_code": "dev-code-123", "user_code": "ABCD-EFGH",
                "verification_url": f"{base}/device",
                "verification_url_complete": f"{base}/device?code=ABCD-EFGH",
                "interval": 1, "expires_in": 60,
            })
        if self.path == "/api/v1/cli/device/token":
            polls["count"] += 1
            if polls["count"] < 2:
                return self._send(428, {"error": "authorization_pending"})
            return self._send(200, {"token": USER_TOKEN, "url": base})
        if entry["auth"] != "project":
            return self._send(401, {"message": "Unauthenticated."})
        if self.path == "/api/v1/documents":
            slug = entry.get("form", {}).get("slug", "doc")
            return self._send(201, {
                "id": 42, "slug": slug, "version": 3,
                "url": f"{base}/d/{slug}", "version_url": f"{base}/d/{slug}/v/3", "notice": None,
            })
        if self.path == "/api/v1/ledger":
            return self._send(201, {"sequence": 7})
        if self.path.startswith("/api/v1/projects/") and self.path.endswith("/artifacts/external"):
            return self._send(201, {"ok": True})
        self._send(404, {"message": "Not found"})


ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
