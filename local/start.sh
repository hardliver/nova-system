#!/bin/sh
# Linux：在終端機執行 ./start.sh，啟動網頁版 Nova。
cd "$(dirname "$0")"
echo "網頁版 Nova：http://localhost:8422（要停止：按 Ctrl+C）"
(sleep 1; xdg-open "http://localhost:8422" >/dev/null 2>&1) &
python3 -m http.server 8422
