"""Restart the local OTClient WebAssembly page server."""
from pathlib import Path
import subprocess, sys, time, socket, json, urllib.request

root = Path(__file__).resolve().parents[1]
runtime = root / "runtime"
python = Path(sys.executable)
command = [str(python), str(root / "client/tools/emscripten-web-serve.py"),
           "--root", str(root / "build/client-web/bin"), "--port", "8080"]
log = (runtime / "web.out.log").open("ab")
error = (runtime / "web.err").open("ab")
flags = subprocess.CREATE_NO_WINDOW | subprocess.DETACHED_PROCESS
proc = subprocess.Popen(command, cwd=root, stdin=subprocess.DEVNULL,
                        stdout=log, stderr=error, creationflags=flags,
                        close_fds=True)
(runtime / "web.pid").write_text(str(proc.pid), encoding="ascii")
for _ in range(50):
    try:
        with urllib.request.urlopen("http://127.0.0.1:8080/otclient.html", timeout=1) as response:
            if response.status == 200:
                print("Jogo aberto em http://localhost:8080/otclient.html")
                break
    except Exception:
        time.sleep(.2)
else:
    raise SystemExit("Servidor web nao iniciou; consulte runtime/web.err")
