#!/bin/bash
# Двойной клик — запускает Редактор Сидур и открывает его в окне-приложении.
cd "$(dirname "$0")"
exec /usr/bin/python3 tools/editor_server.py
