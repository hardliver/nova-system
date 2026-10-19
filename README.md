# nova-system

Nova 的系統卡匣（主選單）與網頁版 Nova。

- **系統卡匣**（`src/`）：用 Lua 寫的 Comet 程式，開機後的 HOME、大廳、之後的商城和個人頁。
  網頁版 Nova 和 Nova One 主機跑的是**同一份**。它比一般遊戲多一個 `sys` 表格
  （列出遊戲、啟動遊戲），一般遊戲碰不到（見 comet 的 `core/system.h`）。
- **網頁外殼**（`web/`）：網頁版的「平台」——開機畫面、輸入、畫面、載入檔案。

```
nova/
  comet/          引擎
  nova-system/    這個 repo
  wildkin/        遊戲
```

## 執行

```
make serve        # 瀏覽器開 http://localhost:8422
```

需要：emscripten（`brew install emscripten`）、Node 18 以上。
引擎從旁邊的 `comet` 編譯後複製過來（`comet.wasm`、`comet.js`、`input.js`、`touchpad.js`、`play.css`），
不放進這個 repo。

## 進度

- [x] N4：開機畫面「按任意鍵開始」（手機上順便全螢幕）、系統卡匣 HOME 畫面
- [ ] N5：大廳：列出內建遊戲、啟動、回 HOME
- [ ] N6：部署到 GitHub Pages（https://hardliver.github.io/nova-system）
- [ ] N6b：本機架站用的 `nova-web.zip`
