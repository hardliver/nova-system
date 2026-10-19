網頁版 Nova（本機版）

不用網路、不用 GitHub，在自己的電腦上玩 Nova 的遊戲。
遊戲在瀏覽器裡執行，這個資料夾只是提供檔案。

啟動
  Mac      雙擊 start.command（第一次：按右鍵 → 打開 → 打開）
  Windows  雙擊 start.bat（需要先安裝 Python：https://www.python.org）
  Linux    在終端機執行 ./start.sh

然後瀏覽器會打開 http://localhost:8422 。

注意
  - 不能直接雙擊 index.html：瀏覽器不允許從檔案（file://）載入遊戲引擎
  - 存檔存在這台電腦的瀏覽器裡（和 GitHub 上的網頁版分開）
  - 同一個 WiFi 的手機也可以連進來玩（用電腦的 IP，例如 http://192.168.1.23:8422），
    但手機的瀏覽器不允許非 https 網址使用手把，只能用觸控
