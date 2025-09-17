# Preview instructions (PowerShell + Python 3)

This project is a static site in the `site/` folder. You can preview it locally using Python 3's built-in HTTP server.

Quick checklist before starting:
- Make sure `index.html` and the `assets/` folder are in the same directory where you run the server.
- Install Python 3 and choose "Add to PATH" during installation if `python --version` fails.

1) One-click start (Windows)
- Double-click `start-server.bat` in the `site` folder. That opens PowerShell and runs the helper script.

2) PowerShell helper (recommended)
- From PowerShell in the `site` folder run:

```powershell
powershell -ExecutionPolicy Bypass -File .\start-server.ps1
```

This opens a new PowerShell window, attempts to use `python` (or `py -3`) to start a server on `http://127.0.0.1:8000`, and opens your browser.

3) Manual start (if you prefer)
- Change to the site directory and run the server yourself:

```powershell
cd 'C:\workspace\site'
python -m http.server 8000 --bind 127.0.0.1
# or
py -3 -m http.server 8000 --bind 127.0.0.1
```

4) If the browser shows "This site can’t be reached"
- Confirm the server terminal shows a message like: `Serving HTTP on 127.0.0.1 port 8000`.
- If no server message appears, the server didn't start — copy/paste the terminal output here and I'll debug it.
- If you see "Address already in use", try a different port:

```powershell
python -m http.server 8080 --bind 127.0.0.1
```

- If `python` is not found, run:

```powershell
py -3 --version
```

If `py` works, run the server with `py -3 -m http.server ...`.

5) Firewall notes
- Serving on `127.0.0.1` (localhost) normally bypasses Windows Firewall restrictions. If you bind to `0.0.0.0` or another address, Windows Firewall may block it.

6) When you’re stuck
- Paste the exact terminal output from the helper or the manual command here and I will diagnose it. Helpful outputs are the last 10-20 lines from the PowerShell window the helper opens.

---
If you want, I can also add a small Node-based preview server (npm script) if you prefer Node tooling. Let me know.