# Clicks and keys for driving the desktop in tests (no xdotool here), through XTest:
#   click.py X Y [button]   (3 = right)   click.py key Escape   click.py type text (no capitals)
import ctypes, sys, time
X = ctypes.CDLL("libX11.so.6"); T = ctypes.CDLL("libXtst.so.6")
X.XOpenDisplay.restype = ctypes.c_void_p
d = ctypes.c_void_p(X.XOpenDisplay(None))
def key(sym):
    X.XStringToKeysym.restype = ctypes.c_ulong
    ks = X.XStringToKeysym(sym.encode()); kc = X.XKeysymToKeycode(d, ctypes.c_ulong(ks))
    T.XTestFakeKeyEvent(d, kc, 1, 0); T.XTestFakeKeyEvent(d, kc, 0, 0); X.XFlush(d); time.sleep(0.03)
a = sys.argv[1:]
if a[0] == "key":
    for s in a[1:]: key(s)
elif a[0] == "type":
    for ch in a[1]:
        key({" ": "space", ".": "period", "-": "minus"}.get(ch, ch))
else:
    x, y = int(a[0]), int(a[1]); b = int(a[2]) if len(a) > 2 else 1
    T.XTestFakeMotionEvent(d, -1, x, y, 0); X.XFlush(d); time.sleep(0.15)
    T.XTestFakeButtonEvent(d, b, 1, 0); X.XFlush(d); time.sleep(0.05)
    T.XTestFakeButtonEvent(d, b, 0, 0); X.XFlush(d)
X.XCloseDisplay(d)
