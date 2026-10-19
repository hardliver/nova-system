@echo off
rem Windows：雙擊這個檔案，啟動網頁版 Nova（需要先安裝 Python：python.org）
chcp 65001 >nul
cd /d "%~dp0"
echo 網頁版 Nova：http://localhost:8422（要停止：關掉這個視窗）
start "" http://localhost:8422
py -m http.server 8422 || python -m http.server 8422
