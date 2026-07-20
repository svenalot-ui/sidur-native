#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Редактор Сидур — локальный нативный редактор молитв/служб.
Запуск:  python3 tools/editor_server.py   (или двойной клик по «Редактор Сидур.command»)
Открывает редактор в браузере как отдельное окно-приложение и пишет прямо
в Сидур/Content/*.json — те же файлы, что читает приложение.
"""
import http.server, socketserver, json, os, urllib.parse, webbrowser, threading, time, sys, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CONTENT = os.path.join(ROOT, 'Сидур', 'Content')
HTML = os.path.join(HERE, 'editor.html')
PORT = 8777


class Handler(http.server.BaseHTTPRequestHandler):
    def _send(self, code, body, ctype='application/json'):
        b = body if isinstance(body, (bytes, bytearray)) else body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype + '; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Length', str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path in ('/', '/index.html'):
            self._send(200, open(HTML, 'rb').read(), 'text/html')
        elif u.path == '/api/files':
            files = sorted(f for f in os.listdir(CONTENT)
                           if f.endswith('.json') and f not in ('calendar.json',))
            self._send(200, json.dumps(files))
        elif u.path == '/api/file':
            name = urllib.parse.parse_qs(u.query).get('name', [''])[0]
            p = self._safe(name)
            if p and os.path.isfile(p):
                self._send(200, open(p, 'rb').read())
            else:
                self._send(404, '{}')
        else:
            self._send(404, 'not found', 'text/plain')

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == '/api/file':
            name = urllib.parse.parse_qs(u.query).get('name', [''])[0]
            p = self._safe(name)
            if not p:
                self._send(400, '{"error":"bad name"}'); return
            length = int(self.headers.get('Content-Length', 0))
            raw = self.rfile.read(length)
            try:
                obj = json.loads(raw.decode('utf-8'))     # validate
            except Exception as e:
                self._send(400, json.dumps({'error': str(e)})); return
            # backup once per session, then write compact (matches build_content)
            bak = p + '.bak'
            if os.path.isfile(p) and not os.path.isfile(bak):
                try:
                    import shutil; shutil.copy(p, bak)
                except Exception:
                    pass
            json.dump(obj, open(p, 'w'), ensure_ascii=False, separators=(',', ':'))
            self._send(200, json.dumps({'ok': True, 'bytes': os.path.getsize(p)}))
        else:
            self._send(404, '{}')

    def _safe(self, name):
        if not name or '/' in name or '\\' in name or not name.endswith('.json'):
            return None
        return os.path.join(CONTENT, name)

    def log_message(self, *a):
        pass


def open_app_window():
    time.sleep(0.7)
    url = f'http://localhost:{PORT}/'
    # try to open Chrome in app-window mode for a native feel; fall back to default browser
    for chrome in ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
                   '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge']:
        if os.path.exists(chrome):
            try:
                subprocess.Popen([chrome, f'--app={url}', '--window-size=1280,900'])
                return
            except Exception:
                pass
    webbrowser.open(url)


if __name__ == '__main__':
    if not os.path.isdir(CONTENT):
        print('Не найдена папка Content:', CONTENT); sys.exit(1)
    threading.Thread(target=open_app_window, daemon=True).start()
    print('╭───────────────────────────────────────────────╮')
    print('│  Редактор Сидур запущен                        │')
    print(f'│  http://localhost:{PORT}/                        │')
    print('│  Закрой это окно (Ctrl+C), чтобы остановить.   │')
    print('╰───────────────────────────────────────────────╯')
    try:
        socketserver.TCPServer(('127.0.0.1', PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        print('\nОстановлено.')
