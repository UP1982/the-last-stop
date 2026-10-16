"""Real Odin CLI round-trip through HTTP, always in a fresh temporary data copy."""
import http.client
import json
from pathlib import Path
import shutil
import tempfile
import threading
import unittest

from test_bridge import ROOT, server_module


@unittest.skipUnless((ROOT / "build/tls-content").is_file(), "Build tls-content first")
class RealContentTests(unittest.TestCase):
    def test_roundtrip_stale_validation_and_validated_undo(self):
        with tempfile.TemporaryDirectory(prefix="tls-e1-content-") as directory:
            root = Path(directory).resolve()
            shutil.copytree(ROOT / "data", root / "data")
            if (ROOT / "assets").is_dir():
                shutil.copytree(ROOT / "assets", root / "assets")
            (root / "build").mkdir()
            shutil.copy2(ROOT / "build/tls-content", root / "build/tls-content")
            server = server_module.make_server(root)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                def api(command, request=None):
                    connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=10)
                    body = {"command": command}
                    if request is not None:
                        body["request"] = request
                    headers = {"Content-Type": "application/json", "X-Editor-Token": server.bridge.token,
                               "Origin": "http://127.0.0.1:" + str(server.server_port)}
                    connection.request("POST", "/api/command", json.dumps(body), headers)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    value = json.loads(response.read())
                    connection.close()
                    return value
                before = api("inspect-scene")
                self.assertEqual(before["exit_code"], 0)
                scene = before["result"]
                request = {"protocol_version": 1, "request_id": "http_roundtrip", "chapter": scene["chapter"],
                           "document": scene["document"], "expected_revision": scene["graph_revision"], "operations": [
                               {"op": "set_property", "collection": "objects", "id": "crank_handle", "property": "position", "value": [1192, 256]},
                               {"op": "set_property", "collection": "objects", "id": "crank_handle", "property": "interaction", "value": [-40, -16, 96, 64]}]}
                saved = api("apply-edit", request)
                self.assertEqual(saved["exit_code"], 0)
                inspection = api("inspect-scene")["result"]
                handle = inspection["authored"]["objects"]["crank_handle"]
                self.assertEqual(handle["position"], [1192, 256])
                self.assertEqual(handle["interaction"], [-40, -16, 96, 64])
                path = root / "data/scenes/oliver_obstacle.json"
                saved_bytes = path.read_bytes()
                self.assertEqual(api("apply-edit", request)["exit_code"], 3)
                self.assertEqual(path.read_bytes(), saved_bytes)
                request["expected_revision"] = inspection["graph_revision"]
                request["operations"][1]["value"][2] = 0
                invalid = api("apply-edit", request)
                self.assertEqual(invalid["exit_code"], 2)
                self.assertTrue(invalid["result"]["diagnostics"])
                self.assertEqual(path.read_bytes(), saved_bytes)
                request["operations"] = [{"op": "restore_document", "value": scene["authored"]}]
                self.assertEqual(api("apply-edit", request)["exit_code"], 0)
                self.assertEqual(api("inspect-scene")["result"]["authored"], scene["authored"])
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=2)
                server.bridge.close()
