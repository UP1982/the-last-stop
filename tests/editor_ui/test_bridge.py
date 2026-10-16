"""Run: python3 -B -m unittest discover -s tests/editor_ui -v"""
import ctypes
import http.client
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("editor_server", ROOT / "editor/server.py")
server_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server_module)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tls-e1-test-")
        self.root = Path(self.temp.name).resolve()
        (self.root / "build").mkdir()
        for name in ("tls-content", "the-last-stop-dev"):
            path = self.root / "build" / name
            path.write_text("bridge test placeholder")
            path.chmod(0o700)
        self.server = server_module.make_server(self.root)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.bridge = self.server.bridge
        self.host = "127.0.0.1:" + str(self.server.server_port)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.bridge.close()
        self.temp.cleanup()

    def request(self, path="/api/scene", body=None, headers=None, token=True, method=None):
        request_headers = {"Origin": "http://" + self.host}
        if token:
            request_headers["X-Editor-Token"] = self.bridge.token
        if body is not None:
            request_headers["Content-Type"] = "application/json"
        request_headers.update(headers or {})
        connection = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        encoded = json.dumps(body).encode() if body is not None else None
        connection.request(method or ("POST" if body is not None else "GET"), path, encoded, request_headers)
        response = connection.getresponse()
        result = (response.status, response.read(), dict(response.getheaders()))
        connection.close()
        return result

    def command(self, body, **kwargs):
        status, data, headers = self.request("/api/command", body, **kwargs)
        return status, json.loads(data), headers

    def edit(self):
        return {"protocol_version": 1, "request_id": "editor_test", "chapter": server_module.CHAPTER,
                "document": server_module.SCENE, "expected_revision": "sha256:" + "a" * 64,
                "operations": [{"op": "set_property", "collection": "objects", "id": "crank_handle",
                                "property": "position", "value": [596, 128]}]}

    def test_api_token_required_and_wrong_token_rejected(self):
        self.assertEqual(self.request(token=False)[0], 401)
        self.assertEqual(self.request(headers={"X-Editor-Token": "wrong"})[0], 401)
        self.assertEqual(self.request(headers={"X-Editor-Token": "é"})[0], 401)

    def test_bad_host_origin_and_cross_site_rejected(self):
        for headers in ({"Host": "evil.invalid"}, {"Host": "localhost:" + str(self.server.server_port)},
                        {"Origin": "https://evil.invalid"}, {"Origin": "null"}, {"Sec-Fetch-Site": "cross-site"}):
            with self.subTest(headers=headers):
                self.assertEqual(self.request(headers=headers)[0], 403)
        self.assertEqual(self.command({"command": "preview-scene"}, headers={"Origin": ""})[0], 403)
        self.assertEqual(self.request(method="OPTIONS")[0], 403)

    def test_traversal_query_and_unknown_routes_rejected(self):
        for path in ("/../server.py", "/%2e%2e/server.py", "/api/../scene", "/a%5c..%5cserver.py", "/%00"):
            self.assertEqual(self.request(path)[0], 400, path)
        self.assertEqual(self.request("/api/scene?root=/tmp")[0], 400)
        self.assertEqual(self.request("/server.py")[0], 404)

    def test_unknown_command_and_client_argv_rejected(self):
        for body in ({"command": "sh", "argv": ["whoami"]}, {"command": "preview-scene", "project_root": "/tmp"},
                     {"command": "inspect-scene", "scene": "../x"}, {"command": "apply-edit", "request": {"document": "../x"}}):
            self.assertEqual(self.command(body)[0], 400)

    def test_static_has_no_cors_and_has_csp(self):
        status, data, headers = self.request("/")
        self.assertEqual(status, 200)
        self.assertIn(b"authoring approximation", data)
        self.assertNotIn("Access-Control-Allow-Origin", headers)
        self.assertIn("frame-ancestors 'none'", headers["Content-Security-Policy"])

    def test_static_and_binary_symlink_escapes_rejected(self):
        web = self.root / "web"
        web.mkdir()
        (web / "index.html").symlink_to(ROOT / "README.md")
        with patch.object(server_module, "WEB", web):
            self.assertEqual(self.request("/")[0], 403)
        executable = self.root / "build/tls-content"
        executable.unlink()
        executable.symlink_to("/usr/bin/true")
        self.assertEqual(self.request()[0], 400)

    def test_edit_exact_argv_body_and_pinned_root(self):
        request = self.edit()
        def run(argv, **kwargs):
            self.assertEqual(argv[:4], [str(self.root / "build/tls-content"), "apply-edit", "--project-root", str(self.root)])
            self.assertEqual(argv[4], "--request")
            self.assertEqual(len(argv), 6)
            self.assertEqual(json.loads(Path(argv[5]).read_text()), request)
            self.assertEqual(Path(argv[5]).name, "request.json")
            self.assertEqual(kwargs, {"cwd": str(self.root), "capture_output": True, "timeout": 20, "check": False})
            return subprocess.CompletedProcess(argv, 0, b'{"commit_state":"committed","new_revision":"sha256:abc"}', b'')
        with patch.object(server_module.subprocess, "run", side_effect=run) as mocked:
            status, value, _ = self.command({"command": "apply-edit", "request": request})
        self.assertEqual(status, 200)
        self.assertEqual(value["exit_code"], 0)
        self.assertEqual(value["result"]["commit_state"], "committed")
        self.assertEqual(mocked.call_count, 1)

    def test_stale_invalid_and_uncertain_codes_propagate(self):
        for code, state in [(2, "not_committed"), (3, "not_committed"), (5, "committed_durability_uncertain")]:
            result = {"commit_state": state, "diagnostics": [{"code": "test", "message": "preserve me"}]}
            with patch.object(server_module.subprocess, "run", return_value=subprocess.CompletedProcess([], code, json.dumps(result).encode(), b"stderr")):
                status, value, _ = self.command({"command": "apply-edit", "request": self.edit()})
            self.assertEqual(status, 200)
            self.assertEqual(value["exit_code"], code)
            self.assertEqual(value["result"], result)
            self.assertEqual(value["stderr"], "stderr")

    def test_preview_uses_generated_session_fixed_argv_and_is_stopped(self):
        process = Mock(pid=123)
        process.poll.return_value = None
        with patch.object(server_module.subprocess, "Popen", return_value=process) as popen:
            status, value, _ = self.command({"command": "preview-scene"})
        self.assertEqual(status, 200)
        self.assertRegex(value["session"], r"^editor_[a-f0-9]{24}$")
        argv = popen.call_args.args[0]
        self.assertEqual(argv, [str(self.root / "build/the-last-stop-dev"), "--project-root", str(self.root),
                                "--preview-scene", "oliver_obstacle", "--preview-session", value["session"], "--dump-scene"])
        self.assertNotIn("shell", popen.call_args.kwargs)
        self.bridge.close()
        process.terminate.assert_called_once()
        process.wait.assert_called_once_with(timeout=3)
        process.poll.return_value = 0

    def test_inspect_exact_argv(self):
        with patch.object(server_module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, b'{}', b'')) as run:
            self.assertEqual(self.request()[0], 200)
        self.assertEqual(run.call_args.args[0], [str(self.root / "build/tls-content"), "inspect-scene", "--project-root", str(self.root), "--scene", "oliver_obstacle"])


class JavaScriptLogicTests(unittest.TestCase):
    def test_actual_js_logic_without_node(self):
        # JavaScriptCore is shipped with macOS. Exercise the actual pure JS, not a Python rewrite.
        try:
            library = ctypes.CDLL("/System/Library/Frameworks/JavaScriptCore.framework/JavaScriptCore")
        except OSError:
            self.skipTest("JavaScriptCore unavailable; run logic_tests.js in a browser after logic.js")
        pointer = ctypes.c_void_p
        library.JSGlobalContextCreate.argtypes = [pointer]
        library.JSGlobalContextCreate.restype = pointer
        library.JSStringCreateWithUTF8CString.argtypes = [ctypes.c_char_p]
        library.JSStringCreateWithUTF8CString.restype = pointer
        library.JSEvaluateScript.argtypes = [pointer, pointer, pointer, pointer, ctypes.c_int, ctypes.POINTER(pointer)]
        library.JSEvaluateScript.restype = pointer
        library.JSValueToStringCopy.argtypes = [pointer, pointer, ctypes.POINTER(pointer)]
        library.JSValueToStringCopy.restype = pointer
        library.JSStringGetMaximumUTF8CStringSize.argtypes = [pointer]
        library.JSStringGetMaximumUTF8CStringSize.restype = ctypes.c_size_t
        library.JSStringGetUTF8CString.argtypes = [pointer, ctypes.c_char_p, ctypes.c_size_t]
        library.JSStringRelease.argtypes = [pointer]
        library.JSGlobalContextRelease.argtypes = [pointer]
        context = library.JSGlobalContextCreate(None)
        source = (ROOT / "editor/web/logic.js").read_text() + '\n' + (Path(__file__).parent / "logic_tests.js").read_text()
        script = library.JSStringCreateWithUTF8CString(source.encode())
        exception = pointer()
        try:
            value = library.JSEvaluateScript(context, script, None, None, 1, ctypes.byref(exception))
            string = library.JSValueToStringCopy(context, exception.value or value, None)
            try:
                size = library.JSStringGetMaximumUTF8CStringSize(string)
                buffer = ctypes.create_string_buffer(size)
                library.JSStringGetUTF8CString(string, buffer, size)
                text = buffer.value.decode()
            finally:
                library.JSStringRelease(string)
            self.assertFalse(exception.value, text)
            self.assertEqual(text, "logic: 20 assertions passed")
        finally:
            library.JSStringRelease(script)
            library.JSGlobalContextRelease(context)


if __name__ == "__main__":
    unittest.main()
