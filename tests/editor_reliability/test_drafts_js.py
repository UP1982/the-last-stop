"""Execute the actual asynchronous recovery queue in macOS JavaScriptCore."""
import ctypes, json, unittest
from pathlib import Path

class DraftQueue(unittest.TestCase):
    def test_actual_async_queue_and_unavailable_recovery(self):
        try: lib=ctypes.CDLL('/System/Library/Frameworks/JavaScriptCore.framework/JavaScriptCore')
        except OSError:self.skipTest('JavaScriptCore unavailable; run drafts_tests.js in browser after drafts.js')
        pointer=ctypes.c_void_p
        for name,args,result in [('JSGlobalContextCreate',[pointer],pointer),('JSStringCreateWithUTF8CString',[ctypes.c_char_p],pointer),('JSEvaluateScript',[pointer,pointer,pointer,pointer,ctypes.c_int,ctypes.POINTER(pointer)],pointer),('JSValueToStringCopy',[pointer,pointer,ctypes.POINTER(pointer)],pointer),('JSStringGetMaximumUTF8CStringSize',[pointer],ctypes.c_size_t),('JSStringGetUTF8CString',[pointer,ctypes.c_char_p,ctypes.c_size_t],ctypes.c_size_t),('JSStringRelease',[pointer],None),('JSGlobalContextRelease',[pointer],None)]:
            fn=getattr(lib,name);fn.argtypes=args;fn.restype=result
        context=lib.JSGlobalContextCreate(None)
        def evaluate(source):
            script=lib.JSStringCreateWithUTF8CString(source.encode());exception=pointer()
            try:
                value=lib.JSEvaluateScript(context,script,None,None,1,ctypes.byref(exception));text=lib.JSValueToStringCopy(context,exception.value or value,None)
                try:
                    size=lib.JSStringGetMaximumUTF8CStringSize(text);buf=ctypes.create_string_buffer(size);lib.JSStringGetUTF8CString(text,buf,size);result=buf.value.decode()
                finally:lib.JSStringRelease(text)
                self.assertFalse(exception.value,result);return result
            finally:lib.JSStringRelease(script)
        root=Path(__file__).resolve().parents[2]
        try:
            evaluate('globalThis.window=globalThis;\n'+(root/'editor/web/drafts.js').read_text()+'\n'+(Path(__file__).with_name('drafts_tests.js')).read_text())
            result=json.loads(evaluate('JSON.stringify(globalThis.draftTestResult)'))
            self.assertEqual(result,dict(ok=True,assertions=7))
        finally:lib.JSGlobalContextRelease(context)
