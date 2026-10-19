#!/bin/sh
# Mac：在 Finder 裡雙擊這個檔案，啟動網頁版 Nova。
# 第一次如果出現「無法打開」：按右鍵 → 打開 → 打開。
cd "$(dirname "$0")"
echo "網頁版 Nova：http://localhost:8422"
echo "同一個 WiFi 的手機：http://$(ipconfig getifaddr en0 2>/dev/null):8422（手機上手把不能用，觸控可以）"
echo "要停止：關掉這個視窗"
(sleep 1; open "http://localhost:8422") &
python3 -m http.server 8422
