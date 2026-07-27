#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Собирает «Редактор Сидур.app» — приложение macOS с иконкой для дока.

    python3 tools/make_editor_app.py

Кладёт готовый бандл в ~/Applications (оттуда macOS разрешает запуск; из папки
iCloud — нет). Сам редактор (сервер + html) копируется ВНУТРЬ бандла, а тексты
читаются из репозитория по абсолютному пути.

При первом запуске macOS спросит доступ к папке «Документы» — это нужно, чтобы
редактор мог править Сидур/Content/*.json. Разрешить один раз.
"""
import os, subprocess, shutil, plistlib, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, 'tools')
DEST_DIR = os.path.expanduser('~/Applications')
APP = os.path.join(DEST_DIR, 'Редактор Сидур.app')
SRC_ICON = os.path.join(ROOT, 'Сидур', 'Assets.xcassets', 'AppIcon.appiconset', 'icon-1024.png')

os.makedirs(DEST_DIR, exist_ok=True)
if os.path.isdir(APP):
    shutil.rmtree(APP)
macos = os.path.join(APP, 'Contents', 'MacOS')
res = os.path.join(APP, 'Contents', 'Resources')
os.makedirs(macos), os.makedirs(res)

# --- иконка: png → iconset → icns ---
iconset = '/tmp/sidur_editor.iconset'
shutil.rmtree(iconset, ignore_errors=True)
os.makedirs(iconset)
for s in (16, 32, 128, 256, 512):
    subprocess.run(['sips', '-z', str(s), str(s), SRC_ICON,
                    '--out', os.path.join(iconset, f'icon_{s}x{s}.png')], capture_output=True)
    subprocess.run(['sips', '-z', str(s * 2), str(s * 2), SRC_ICON,
                    '--out', os.path.join(iconset, f'icon_{s}x{s}@2x.png')], capture_output=True)
icns = os.path.join(res, 'AppIcon.icns')
subprocess.run(['iconutil', '-c', 'icns', iconset, '-o', icns], capture_output=True)

# --- редактор внутрь бандла ---
shutil.copy(os.path.join(TOOLS, 'editor_server.py'), os.path.join(res, 'editor_server.py'))
shutil.copy(os.path.join(TOOLS, 'editor.html'), os.path.join(res, 'editor.html'))

# --- launcher ---
launcher = os.path.join(macos, 'run')
with open(launcher, 'w') as f:
    f.write(f'''#!/bin/bash
# Редактор Сидур
RES="$(cd "$(dirname "$0")/../Resources" && pwd)"
PROJ="{ROOT}"
LOG="$HOME/Library/Logs/sidur-editor.log"
exec >>"$LOG" 2>&1
echo "--- $(date) старт"

# уже запущен? просто открыть окно
if /usr/bin/curl -s -m 1 http://localhost:8777/api/status >/dev/null 2>&1; then
  open -a "Google Chrome" --args --app=http://localhost:8777/ 2>/dev/null || open http://localhost:8777/
  exit 0
fi

# macOS не даёт приложению читать «Документы» без разрешения. Если доступа нет —
# запускаем через Терминал: он подписан Apple и сам корректно спросит доступ.
if ! /bin/ls "$PROJ/Сидур/Content" >/dev/null 2>&1; then
  echo "нет доступа к Content → запуск через Терминал"
  /usr/bin/osascript \\
    -e "tell application \\"Terminal\\" to do script \\"cd '$PROJ' && /usr/bin/python3 tools/editor_server.py\\"" \\
    -e 'tell application "Terminal" to activate'
  exit 0
fi

exec /usr/bin/python3 "$RES/editor_server.py" --root "$PROJ"
''')
os.chmod(launcher, 0o755)

# --- Info.plist (с запросами доступа к папкам — иначе macOS молча запрещает) ---
info = {
    'CFBundleName': 'Редактор Сидур',
    'CFBundleDisplayName': 'Редактор Сидур',
    'CFBundleIdentifier': 'com.shevetachim.sidur.editor',
    'CFBundleVersion': '1.0', 'CFBundleShortVersionString': '1.0',
    'CFBundlePackageType': 'APPL', 'CFBundleExecutable': 'run',
    'CFBundleIconFile': 'AppIcon', 'LSMinimumSystemVersion': '11.0',
    'NSHighResolutionCapable': True,
    'NSDocumentsFolderUsageDescription': 'Редактор правит тексты молитв приложения «Сидур».',
    'NSDesktopFolderUsageDescription': 'Редактор правит тексты молитв приложения «Сидур».',
    'NSDownloadsFolderUsageDescription': 'Редактор правит тексты молитв приложения «Сидур».',
}
with open(os.path.join(APP, 'Contents', 'Info.plist'), 'wb') as f:
    plistlib.dump(info, f)

# чистая ad-hoc подпись (без неё Gatekeeper блокирует запуск)
subprocess.run(['xattr', '-cr', APP], capture_output=True)
r = subprocess.run(['codesign', '--force', '--deep', '-s', '-', APP], capture_output=True, text=True)

print('Готово:', APP)
print('подпись:', 'ok' if r.returncode == 0 else r.stderr.strip()[:120])
print('\nПри первом запуске macOS спросит доступ к «Документам» — разрешите.')
print('Чтобы закрепить в доке: запустите, затем правый клик по иконке в доке → Параметры → Оставить в Dock.')
