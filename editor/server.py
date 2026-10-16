#!/usr/bin/env python3
"""E1 localhost transport. Content authority remains build/tls-content (Python 3.9)."""
import argparse
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import signal
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

SCENE = "oliver_obstacle"
CHAPTER = "oliver_flower_market"
MAX_BODY = 262144
WEB = Path(__file__).resolve().parent / "web"
STATIC = {"/": ("index.html", "text/html"),
          "/style.css": ("style.css", "text/css"),
          "/logic.js": ("logic.js", "text/javascript"),
          "/app.js": ("app.js", "text/javascript")}


class BridgeError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


class Bridge:
    def __init__(self, project_root):
        self.root = Path(project_root).resolve(strict=True)
        if not self.root.is_dir():
            raise ValueError("Project root must be a directory")
        self.token = secrets.token_urlsafe(32)
        self.project_key = hashlib.sha256(os.fsencode(self.root)).hexdigest()
        self.lock = threading.Lock()
        self.preview = None
        self.preview_log = None
        self.session = None

    def binary(self, name):
        path = self.root / "build" / name
        try:
            resolved = path.resolve(strict=True)
            resolved.relative_to(self.root)
            if not resolved.is_file() or not os.access(resolved, os.X_OK):
                raise ValueError()
        except (OSError, ValueError, RuntimeError):
            raise BridgeError(400, "Missing or unsafe build executable: " + name)
        return str(resolved)

    def content(self, command, request=None):
        argv = [self.binary("tls-content"), command, "--project-root", str(self.root)]
        # Request files are bridge-owned, never chosen by a client or scene data.
        with tempfile.TemporaryDirectory(prefix="tls-editor-request-") as directory:
            if command == "inspect-scene":
                argv += ["--scene", SCENE]
            elif command == "apply-edit":
                path = Path(directory) / "request.json"
                path.write_text(json.dumps(request, ensure_ascii=False, allow_nan=False), encoding="utf-8")
                argv += ["--request", str(path)]
            else:
                raise BridgeError(400, "Unknown content command")
            try:
                result = subprocess.run(argv, cwd=str(self.root), capture_output=True,
                                        timeout=20, check=False)
            except subprocess.TimeoutExpired:
                # An apply may have committed before interruption. Never encourage blind retry.
                raise BridgeError(504, "Command timed out; inspect disk/revision before retrying")
        try:
            response = json.loads(result.stdout.decode("utf-8"))
        except (ValueError, UnicodeError):
            raise BridgeError(502, "Content CLI returned an invalid response; inspect disk before retrying")
        return {"exit_code": result.returncode, "result": response,
                "stderr": result.stderr.decode("utf-8", errors="replace"),
                "project_key": self.project_key}

    def preview_status(self):
        log = ""
        if self.preview_log is not None:
            # pread avoids changing the offset inherited by the game process.
            size = os.fstat(self.preview_log.fileno()).st_size
            log = os.pread(self.preview_log.fileno(), min(size, 65536), max(0, size - 65536)).decode("utf-8", "replace")
        return {"session": self.session, "pid": self.preview.pid if self.preview else None,
                "running": self.preview is not None and self.preview.poll() is None,
                "exit_code": self.preview.poll() if self.preview else None, "log": log}

    def stop_preview(self):
        if self.preview is not None and self.preview.poll() is None:
            self.preview.terminate()
            try:
                self.preview.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.preview.kill()
                self.preview.wait(timeout=3)
        return self.preview_status()

    def command(self, body):
        if not isinstance(body, dict) or not isinstance(body.get("command"), str):
            raise BridgeError(400, "Expected a fixed command identifier")
        command = body["command"]
        allowed = {"inspect-scene", "apply-edit", "preview-scene", "preview-status", "stop-preview"}
        if command not in allowed:
            raise BridgeError(400, "Unknown command identifier")
        if set(body) != ({"command", "request"} if command == "apply-edit" else {"command"}):
            raise BridgeError(400, "Unsupported command arguments")
        with self.lock:
            if command == "apply-edit":
                request = body["request"]
                if (not isinstance(request, dict) or request.get("document") != SCENE
                        or request.get("chapter") != CHAPTER):
                    raise BridgeError(400, "E1 edits target only Oliver's scene")
                return self.content(command, request)
            if command == "inspect-scene":
                return self.content(command)
            if command == "stop-preview":
                return self.stop_preview()
            if command == "preview-status":
                return self.preview_status()
            executable = self.binary("the-last-stop-dev")
            self.stop_preview()
            if self.preview_log is not None:
                self.preview_log.close()
            self.session = "editor_" + secrets.token_hex(12)
            self.preview_log = tempfile.TemporaryFile()
            argv = [executable, "--project-root", str(self.root), "--preview-scene", SCENE,
                    "--preview-session", self.session, "--dump-scene"]
            self.preview = subprocess.Popen(argv, cwd=str(self.root), stdin=subprocess.DEVNULL,
                                            stdout=self.preview_log, stderr=self.preview_log)
            return self.preview_status()

    def close(self):
        with self.lock:
            self.stop_preview()
            if self.preview_log is not None:
                self.preview_log.close()
                self.preview_log = None


class Handler(BaseHTTPRequestHandler):
    server_version = "TLS-Editor/1"

    def setup(self):
        super().setup()
        self.connection.settimeout(10)

    def log_message(self, *_args):
        pass  # Tokens/request contents never enter access logs.

    def send_data(self, status, data, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(data)

    def json_response(self, status, value):
        self.send_data(status, json.dumps(value, ensure_ascii=False).encode("utf-8"))

    def guard(self, api=False, mutation=False):
        expected = "127.0.0.1:" + str(self.server.server_port)
        if self.headers.get_all("Host") != [expected]:
            raise BridgeError(403, "Rejected Host")
        origins = self.headers.get_all("Origin", [])
        if (origins and origins != ["http://" + expected]) or (mutation and not origins):
            raise BridgeError(403, "Rejected Origin")
        if self.headers.get("Sec-Fetch-Site") == "cross-site":
            raise BridgeError(403, "Rejected cross-site request")
        path = unquote(urlsplit(self.path).path)
        if "\\" in path or "\x00" in path or any(p in (".", "..") for p in path.split("/")):
            raise BridgeError(400, "Rejected traversal")
        if urlsplit(self.path).query:
            raise BridgeError(400, "Query arguments are not supported")
        if api:
            tokens = self.headers.get_all("X-Editor-Token", [])
            if len(tokens) != 1 or not hmac.compare_digest(tokens[0].encode("utf-8"), self.server.bridge.token.encode("ascii")):
                raise BridgeError(401, "Editor token required; open the launch URL")
        return path

    def dispatch(self, post=False):
        try:
            path = self.guard(mutation=post)
            if path.startswith("/api/"):
                self.guard(api=True, mutation=post)
                if not post and path == "/api/scene":
                    value = self.server.bridge.command({"command": "inspect-scene"})
                elif post and path == "/api/command":
                    if self.headers.get_content_type() != "application/json" or self.headers.get("Transfer-Encoding"):
                        raise BridgeError(400, "Expected bounded JSON body")
                    try:
                        size = int(self.headers.get("Content-Length", "-1"))
                    except ValueError:
                        size = -1
                    if size < 1 or size > MAX_BODY:
                        raise BridgeError(413, "Body must be 1..262144 bytes")
                    try:
                        def invalid_number(_value):
                            raise ValueError("Non-finite number")
                        def unique_pairs(pairs):
                            result = {}
                            for key, val in pairs:
                                if key in result:
                                    raise ValueError("Duplicate key")
                                result[key] = val
                            return result
                        body = json.loads(self.rfile.read(size).decode("utf-8"),
                                          parse_constant=invalid_number, object_pairs_hook=unique_pairs)
                    except (ValueError, UnicodeError, RecursionError):
                        raise BridgeError(400, "Malformed JSON")
                    value = self.server.bridge.command(body)
                else:
                    raise BridgeError(404, "Unknown API endpoint")
                self.json_response(200, value)  # CLI exit codes stay explicit in the envelope.
            elif not post and path in STATIC:
                name, mime = STATIC[path]
                target = (WEB / name).resolve(strict=True)
                try:
                    target.relative_to(WEB.resolve())
                except ValueError:
                    raise BridgeError(403, "Rejected static symlink escape")
                self.send_data(200, target.read_bytes(), mime)
            else:
                raise BridgeError(404, "Unknown endpoint")
        except BridgeError as error:
            self.json_response(error.status, {"error": error.message})
        except (OSError, ValueError) as error:
            self.json_response(500, {"error": "Bridge I/O failure: " + str(error)})

    def do_GET(self):
        self.dispatch()

    def do_POST(self):
        self.dispatch(post=True)

    def do_OPTIONS(self):
        self.json_response(403, {"error": "Cross-origin access is disabled"})


def make_server(project_root, port=0):
    bridge = Bridge(project_root)
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    server.bridge = bridge
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args()
    server = make_server(args.project_root)
    def stop(_signum, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, stop)
    print("http://127.0.0.1:{}/#token={}".format(server.server_port, server.bridge.token), flush=True)
    try:
        server.serve_forever(poll_interval=0.2)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        server.bridge.close()


if __name__ == "__main__":
    main()
