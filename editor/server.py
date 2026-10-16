#!/usr/bin/env python3
"""E1 localhost transport. Content authority remains build/tls-content (Python 3.9)."""
import argparse
import base64
import importlib.util
import re
import struct
import zlib
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
DRAFT_MAX_BODY = 8 * 1024 * 1024
WEB = Path(__file__).resolve().parent / "web"
STATIC = {"/": ("index.html", "text/html"),
          "/style.css": ("style.css", "text/css"),
          "/logic.js": ("logic.js", "text/javascript"),
          "/app.js": ("app.js", "text/javascript"),
          "/drafts.js": ("drafts.js", "text/javascript"),
          "/studio.js": ("studio.js", "text/javascript")}


workspace_spec = importlib.util.spec_from_file_location("tls_workspace", Path(__file__).with_name("workspace.py"))
workspace_module = importlib.util.module_from_spec(workspace_spec)
workspace_spec.loader.exec_module(workspace_module)


class BridgeError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


class Bridge:
    def __init__(self, project_root, reservations=()):
        self.root = Path(project_root).resolve(strict=True)
        if not self.root.is_dir():
            raise ValueError("Project root must be a directory")
        self.token = secrets.token_urlsafe(32)
        self.project_key = hashlib.sha256(os.fsencode(self.root)).hexdigest()
        self.lock = threading.Lock()
        self.preview = None
        self.preview_log = None
        self.session = None
        self.workspace = workspace_module.Workspace(self, BridgeError, reservations)

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

    def content(self, command, request=None, document=None):
        executable = self.workspace.artifact_path("build-content")["artifact"] if "build-content" in self.workspace.latest else self.binary("tls-content")
        argv = [executable, command, "--project-root", str(self.root)]
        # Request files are bridge-owned, never chosen by a client or scene data.
        with tempfile.TemporaryDirectory(prefix="tls-editor-request-") as directory:
            if command == "inspect-scene":
                argv += ["--scene", SCENE]
            elif command == "inspect-document":
                argv += ["--document", document]
            elif command == "validate-content":
                pass
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
                "project_key": self.project_key, "executable": executable}

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

    def documents(self):
        chapter = self.content("inspect-document", document=CHAPTER)
        if chapter["exit_code"] != 0:
            raise BridgeError(409, "Chapter graph is invalid; existing drafts are kept")
        authored = chapter["result"]["authored"]
        ids = {CHAPTER, authored["assets"]["id"]}
        ids.update(ref["id"] for ref in authored["scenes"])
        ids.update(ref["id"] for ref in authored["dialogues"].values())
        return authored, ids

    def read_asset(self, asset_id):
        chapter, _ = self.documents()
        manifest = self.content("inspect-document", document=chapter["assets"]["id"])
        if manifest["exit_code"] != 0:
            raise BridgeError(409, "Asset manifest failed validation")
        assets = manifest["result"]["authored"]["assets"]
        if not isinstance(asset_id, str) or asset_id not in assets:
            raise BridgeError(400, "Unknown registered asset ID")
        asset = assets[asset_id]
        if not asset["path"].startswith("assets/") or not asset["path"].endswith(".png"):
            raise BridgeError(400, "Only registered PNG bytes are supported")
        data, _ = self.workspace.bytes(asset["path"], internal=True, limit=16 * 1024 * 1024)
        if hashlib.sha256(data).hexdigest() != asset["sha256"]:
            raise BridgeError(409, "Asset hash differs from manifest")
        # Check PNG framing, IHDR and CRCs before handing bytes to the browser decoder.
        if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 33 or data[12:16] != b"IHDR":
            raise BridgeError(400, "Asset is not a PNG")
        width, height = struct.unpack('>II', data[16:24])
        if not 0 < width <= 16384 or not 0 < height <= 16384 or width * height > 64000000:
            raise BridgeError(400, "PNG dimensions exceed preview bounds")
        offset, ended = 8, False
        while offset + 12 <= len(data):
            length = struct.unpack('>I', data[offset:offset+4])[0]
            chunk = data[offset+4:offset+8+length]
            if offset + length + 12 > len(data) or zlib.crc32(chunk) & 0xffffffff != struct.unpack('>I', data[offset+8+length:offset+12+length])[0]:
                raise BridgeError(400, "Corrupt PNG chunk")
            offset += length + 12
            if chunk[:4] == b'IEND':
                ended = offset == len(data)
                break
        if not ended:
            raise BridgeError(400, "Incomplete PNG")
        return {"asset_id": asset_id, "asset": asset, "mime_type": "image/png", "width": width, "height": height,
                "base64": base64.b64encode(data).decode("ascii"), "graph_revision": manifest["result"]["graph_revision"]}

    def launch_preview(self, executable, entry="scene"):
        self.stop_preview()
        if self.preview_log is not None:
            self.preview_log.close()
        self.session = "editor_" + secrets.token_hex(12)
        self.preview_log = tempfile.TemporaryFile()
        argv = [executable, "--project-root", str(self.root), "--preview-scene", SCENE,
                "--preview-session", self.session, "--preview-entry", entry, "--dump-scene"]
        self.preview = subprocess.Popen(argv, cwd=str(self.root), stdin=subprocess.DEVNULL,
                                        stdout=self.preview_log, stderr=self.preview_log)
        return self.preview_status()

    def command(self, body):
        if not isinstance(body, dict) or not isinstance(body.get("command"), str):
            raise BridgeError(400, "Expected a fixed command identifier")
        command = body["command"]
        schemas = {"inspect-scene": set(), "inspect-document": {"document"}, "validate-content": set(),
                   "apply-edit": {"request"}, "read-asset": {"asset_id"},
                   "preview-scene": set(), "preview-status": set(), "stop-preview": set(),
                   "list-project": set(), "read-file": {"path"},
                   "write-source": {"path", "expected_sha256", "text", "request_id"},
                   "search-project": {"text", "limit"}, "diff-head": {"path"},
                   "run-scene": set(), "run-journey": set(), "job-status": {"job_id", "cursor"},
                   "stop-job": {"job_id"}, "task-status": set(),
                   "read-draft": {"kind", "id"},
                   "write-draft": {"kind", "id", "expected_sha256", "value"}}
        schemas.update({name: set() for name in workspace_module.COMMANDS})
        if command not in schemas or set(body) != schemas[command] | {"command"}:
            raise BridgeError(400, "Unknown command or unsupported command arguments")
        w = self.workspace
        if command == "read-draft":
            return w.read_draft(body["kind"], body["id"])
        if command == "write-draft":
            return w.write_draft(body["kind"], body["id"], body["expected_sha256"], body["value"])
        # Long-running commands execute on worker threads, never under the transport lock.
        if command in workspace_module.COMMANDS:
            return w.start_job(command)
        if command == "job-status":
            return w.job_status(body["job_id"], body["cursor"])
        if command == "stop-job":
            return w.stop_job(body["job_id"])
        if command == "list-project":
            return dict(w.tree(), project_key=self.project_key)
        if command == "read-file":
            return w.read(body["path"])
        if command == "write-source":
            return w.write(body["path"], body["expected_sha256"], body["text"], body["request_id"])
        if command == "search-project":
            return w.search(body["text"], body["limit"])
        if command == "diff-head":
            return w.diff(body["path"])
        if command == "task-status":
            return w.tasks()
        with self.lock:
            if command == "apply-edit":
                request = body["request"]
                if not isinstance(request, dict) or not isinstance(request.get("document"), str) or request.get("chapter") != CHAPTER:
                    raise BridgeError(400, "Edits must target the Chapter 1 graph")
                # Preserve E1's direct scene route; dialogue/chapter targets come from the validated graph.
                if request.get("document") != SCENE:
                    chapter, ids = self.documents()
                    allowed = {CHAPTER} | {ref["id"] for ref in chapter["dialogues"].values()}
                    if request.get("document") not in allowed:
                        raise BridgeError(400, "Document is not an editable Chapter 1 target")
                return self.content(command, request)
            if command == "inspect-document":
                document = body["document"]
                if not isinstance(document, str):
                    raise BridgeError(400, "Expected document ID")
                _, ids = self.documents()
                if document not in ids:
                    raise BridgeError(400, "Unknown validated document ID")
                return self.content(command, document=document)
            if command in ("inspect-scene", "validate-content"):
                return self.content(command)
            if command == "read-asset":
                return self.read_asset(body["asset_id"])
            if command == "stop-preview":
                return self.stop_preview()
            if command == "preview-status":
                return self.preview_status()
            if command in ("run-scene", "run-journey"):
                return w.run_scene("chapter" if command == "run-journey" else "scene")
            # E1 compatibility name now goes through the same stale-build guard.
            return w.run_scene()

    def close(self):
        self.workspace.close()
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
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' blob:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
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
                elif post and path in ("/api/command", "/api/draft"):
                    if self.headers.get_content_type() != "application/json" or self.headers.get("Transfer-Encoding"):
                        raise BridgeError(400, "Expected bounded JSON body")
                    try:
                        size = int(self.headers.get("Content-Length", "-1"))
                    except ValueError:
                        size = -1
                    limit = DRAFT_MAX_BODY if path == "/api/draft" else MAX_BODY
                    if size < 1 or size > limit:
                        raise BridgeError(413, "Body must be 1..{} bytes".format(limit))
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
                    if path == "/api/draft" and (not isinstance(body, dict) or body.get("command") != "write-draft"):
                        raise BridgeError(400, "Recovery endpoint accepts only write-draft")
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
        except (BrokenPipeError, ConnectionResetError):
            pass  # Client may have lost a committed response; never retry a mutation.
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


def make_server(project_root, port=0, reservations=()):
    bridge = Bridge(project_root, reservations)
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    server.bridge = bridge
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--read-only", action="append", default=[], help="Server-owned source reservation, repeatable")
    args = parser.parse_args()
    server = make_server(args.project_root, reservations=args.read_only)
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
