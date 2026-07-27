#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Редактор Сидур — локальный сервер редактора молитв.

Запуск:  python3 tools/editor_server.py     (или двойной клик по «Редактор Сидур.app»)
Пишет прямо в Сидур/Content/*.json — те же файлы, что читает приложение.

API:
  GET  /api/files              список файлов + статистика заполненности
  GET  /api/file?name=…        содержимое файла
  POST /api/file?name=…        сохранить (валидация + версия в истории)
  POST /api/new?name=…         создать новую службу
  GET  /api/history?name=…     список версий
  POST /api/restore?name=…&v=… откатить к версии
  GET  /api/status             статус проекта
"""
import http.server, socketserver, json, os, urllib.parse, webbrowser, threading
import time, sys, subprocess, shutil, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CONTENT = os.path.join(ROOT, 'Сидур', 'Content')
HISTORY = os.path.join(HERE, '.history')
HTML = os.path.join(HERE, 'editor.html')
PORT = 8777
SKIP = {'calendar.json'}

NICE = {
    'mincha': 'Минха', 'shacharit': 'Шахарит', 'maariv': 'Маарив',
    'birkat_hashachar': 'Утренние благословения', 'bedtime': 'Молитва перед сном',
    'birkat_hamazon': 'Биркат а-мазон', 'meein_shalosh': 'Меэйн шалош',
    'birkat_halevana': 'Биркат а-левана', 'havdalah': 'Авдала',
    'liturgy': 'Брахот (короткие)',
}


def stats(path):
    """Заполненность файла: сколько блоков/текстов и сколько ещё пустых."""
    try:
        d = json.load(open(path))
    except Exception:
        return {'error': True}
    if 'parts' in d:
        blocks = [b for p in d['parts'] for b in p['blocks']]
        body = [b for b in blocks if b.get('k') == 'body']
        empty = sum(1 for b in body if not (b.get('he') or '').strip())
        no_ru = sum(1 for b in body if not (b.get('ru') or '').strip())
        ins = sum(1 for b in blocks if b.get('insert'))
        return {'kind': 'service', 'parts': len(d['parts']), 'blocks': len(blocks),
                'empty': empty, 'noRu': no_ru, 'inserts': ins,
                'title': d.get('titleRu') or d.get('titleHe', '')}
    if 'brachotOften' in d:
        items = (d.get('brachotOften', [])
                 + [i for f in d.get('brachotFolders', []) for i in f['items']]
                 + d.get('personal', []) + [d['havdalah']])
        empty = sum(1 for i in items if not (i.get('textHe') or '').strip())
        return {'kind': 'liturgy', 'items': len(items), 'empty': empty,
                'title': 'Короткие благословения'}
    return {'kind': 'other'}


class Handler(http.server.BaseHTTPRequestHandler):
    # ---------- helpers ----------
    def _send(self, code, body, ctype='application/json'):
        b = body if isinstance(body, (bytes, bytearray)) else body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype + '; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _json(self, obj, code=200):
        self._send(code, json.dumps(obj, ensure_ascii=False))

    def _safe(self, name):
        if not name or '/' in name or '\\' in name or not name.endswith('.json'):
            return None
        return os.path.join(CONTENT, name)

    def _q(self, key, default=''):
        u = urllib.parse.urlparse(self.path)
        return urllib.parse.parse_qs(u.query).get(key, [default])[0]

    def _body(self):
        n = int(self.headers.get('Content-Length', 0))
        return self.rfile.read(n)

    # ---------- routes ----------
    def do_GET(self):
        p = urllib.parse.urlparse(self.path).path
        if p in ('/', '/index.html'):
            self._send(200, open(HTML, 'rb').read(), 'text/html')

        elif p == '/api/files':
            out = []
            for f in sorted(os.listdir(CONTENT)):
                if not f.endswith('.json') or f in SKIP:
                    continue
                sid = f[:-5]
                s = stats(os.path.join(CONTENT, f))
                s.update({'file': f, 'id': sid, 'nice': NICE.get(sid, sid)})
                out.append(s)
            self._json(out)

        elif p == '/api/file':
            fp = self._safe(self._q('name'))
            if fp and os.path.isfile(fp):
                self._send(200, open(fp, 'rb').read())
            else:
                self._json({'error': 'not found'}, 404)

        elif p == '/api/history':
            name = self._q('name')
            d = os.path.join(HISTORY, name)
            vs = []
            if os.path.isdir(d):
                for v in sorted(os.listdir(d), reverse=True)[:40]:
                    fp = os.path.join(d, v)
                    vs.append({'v': v, 'size': os.path.getsize(fp),
                               'when': datetime.datetime.fromtimestamp(
                                   os.path.getmtime(fp)).strftime('%d.%m %H:%M:%S')})
            self._json(vs)

        elif p == '/api/status':
            self._json({'root': ROOT, 'content': CONTENT,
                        'files': len([f for f in os.listdir(CONTENT)
                                      if f.endswith('.json') and f not in SKIP])})
        else:
            self._send(404, 'not found', 'text/plain')

    def do_POST(self):
        p = urllib.parse.urlparse(self.path).path

        if p == '/api/file':
            name = self._q('name')
            fp = self._safe(name)
            if not fp:
                return self._json({'error': 'bad name'}, 400)
            raw = self._body()
            try:
                obj = json.loads(raw.decode('utf-8'))
            except Exception as e:
                return self._json({'error': 'JSON: %s' % e}, 400)
            err = self._validate(obj)
            if err:
                return self._json({'error': err}, 400)
            self._snapshot(name, fp)
            json.dump(obj, open(fp, 'w'), ensure_ascii=False, separators=(',', ':'))
            self._json({'ok': True, 'bytes': os.path.getsize(fp)})

        elif p == '/api/new':
            name = self._q('name')
            fp = self._safe(name)
            if not fp:
                return self._json({'error': 'bad name'}, 400)
            if os.path.exists(fp):
                return self._json({'error': 'файл уже существует'}, 400)
            sid = name[:-5]
            doc = {'id': sid, 'titleHe': '', 'titleRu': NICE.get(sid, sid),
                   'parts': [{'he': '', 'ru': 'Часть 1',
                              'blocks': [{'k': 'body', 'he': '', 'translit': '', 'ru': ''}]}]}
            json.dump(doc, open(fp, 'w'), ensure_ascii=False, separators=(',', ':'))
            self._json({'ok': True})

        elif p == '/api/restore':
            name, v = self._q('name'), self._q('v')
            fp, src = self._safe(name), os.path.join(HISTORY, name, v)
            if not fp or not os.path.isfile(src):
                return self._json({'error': 'нет такой версии'}, 404)
            self._snapshot(name, fp)
            shutil.copy(src, fp)
            self._json({'ok': True})
        else:
            self._json({'error': 'unknown'}, 404)

    # ---------- validation & history ----------
    def _validate(self, o):
        if isinstance(o, dict) and 'parts' in o:
            if not isinstance(o['parts'], list):
                return 'parts должен быть списком'
            for i, p in enumerate(o['parts'], 1):
                if not isinstance(p.get('blocks'), list):
                    return 'часть %d: нет blocks' % i
                for b in p['blocks']:
                    if b.get('k') not in ('body', 'rubric', 'sub'):
                        return 'часть %d: неизвестный тип блока «%s»' % (i, b.get('k'))
            return None
        if isinstance(o, dict) and 'brachotOften' in o:
            return None
        return 'неизвестный формат файла'

    def _snapshot(self, name, fp):
        if not os.path.isfile(fp):
            return
        d = os.path.join(HISTORY, name)
        os.makedirs(d, exist_ok=True)
        stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
        shutil.copy(fp, os.path.join(d, stamp + '.json'))
        vs = sorted(os.listdir(d))
        for old in vs[:-40]:                       # держим 40 последних версий
            try:
                os.remove(os.path.join(d, old))
            except OSError:
                pass

    def log_message(self, *a):
        pass


def open_window():
    time.sleep(0.6)
    url = 'http://localhost:%d/' % PORT
    for app in ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
                '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge']:
        if os.path.exists(app):
            try:
                subprocess.Popen([app, '--app=' + url, '--window-size=1440,940'])
                return
            except Exception:
                pass
    webbrowser.open(url)


class Reusable(socketserver.TCPServer):
    allow_reuse_address = True


if __name__ == '__main__':
    if not os.path.isdir(CONTENT):
        print('Не найдена папка Content:', CONTENT)
        sys.exit(1)
    if '--no-open' not in sys.argv:
        threading.Thread(target=open_window, daemon=True).start()
    print('Редактор Сидур → http://localhost:%d/   (Ctrl+C — остановить)' % PORT)
    try:
        Reusable(('127.0.0.1', PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        print('\nОстановлено.')
    except OSError as e:
        print('Порт занят? %s' % e)
