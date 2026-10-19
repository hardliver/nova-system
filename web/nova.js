// nova.js — 網頁版 Nova 的外殼（「平台」）
//
// 網頁版 Nova ＝ 瀏覽器 ＋ Comet 引擎（wasm）＋ 這個外殼 ＋ 系統卡匣（system.lua）。
// 外殼只做「平台」的事：輸入、畫面、開機畫面、載入檔案；
// 主選單長什麼樣子、怎麼選遊戲，全部寫在系統卡匣（src/main.lua），和主機共用。
//
// 引擎、輸入、虛擬手把的程式從 comet 複製過來（make 時），不在這個 repo 裡。

import { createEngine, startLoop } from "./comet.js";
import { setupKeyboard, setupTouch, readGamepad, connectedPads, merge } from "./input.js";
import { setupTouchpad } from "./touchpad.js";

const $ = (id) => document.getElementById(id);

// ---- 提示框（引擎的錯誤訊息）----
let hintTimer = null;
function showHint(text, ms = 6000) {
    $("hint").textContent = text;
    $("hint").classList.add("show");
    clearTimeout(hintTimer);
    hintTimer = setTimeout(() => $("hint").classList.remove("show"), ms);
}

// ---- 輸入：和 Comet 遊玩頁一樣 ----
// 1 號玩家：鍵盤、觸控、第 1 支手把；2–4 號玩家：第 2–4 支手把
setupTouchpad();
const keyboard = setupKeyboard();
const touch = setupTouch(document);
function getInput(player) {
    if (player === 0) return merge(keyboard(), touch(), readGamepad(0));
    return readGamepad(player);
}

window.addEventListener("contextmenu", (e) => e.preventDefault());

// ---- 開機畫面：等玩家按任意鍵 ----
// 為什麼要這一步：瀏覽器規定「使用者動作」之後才能全螢幕、播放聲音；
// 手把也要先按一個鍵，網頁才看得到它。所以開機時請玩家按一下，一次解決。
//   鍵盤、滑鼠、觸控：算「使用者動作」，可以順便全螢幕（只在手機上，電腦全螢幕反而礙事）
//   手把按鍵：瀏覽器不算使用者動作，只能開始，不能全螢幕
function waitForStart() {
    return new Promise((resolve) => {
        let done = false;
        const start = (canFullscreen) => {
            if (done) return;
            done = true;
            window.removeEventListener("keydown", onKey);
            window.removeEventListener("pointerdown", onPointer);
            if (canFullscreen) enterFullscreenOnPhone();
            // 之後有音效時，在這裡建立／恢復 AudioContext
            resolve();
        };
        const onKey = (e) => {
            if (e.repeat || ["Shift", "Control", "Alt", "Meta"].includes(e.key)) return;
            start(true);
        };
        const onPointer = () => start(true);
        window.addEventListener("keydown", onKey);
        window.addEventListener("pointerdown", onPointer);

        // 手把：每一幀看有沒有任何按鍵被按下
        const poll = () => {
            if (done) return;
            if (connectedPads().some((p) => p.buttons.some((b) => b.pressed))) start(false);
            else requestAnimationFrame(poll);
        };
        requestAnimationFrame(poll);
    });
}

async function enterFullscreenOnPhone() {
    if (!matchMedia("(pointer: coarse)").matches) return;
    const root = document.documentElement;
    const request = root.requestFullscreen || root.webkitRequestFullscreen;
    if (!request) return;   // iPhone 的 Safari 不支援；要「加入主畫面」
    try {
        await request.call(root);
        await screen.orientation?.lock?.("landscape").catch(() => {});
    } catch {
        // 不允許就算了，照樣能玩
    }
}

// ---- 啟動 ----
// 引擎和系統卡匣先載好（開機畫面後面），玩家按下去馬上就能動
const engine = await createEngine({ onLog: (msg) => { console.log(msg); showHint(msg); } });

let systemSource;
try {
    const res = await fetch("system.lua");
    if (!res.ok) throw new Error(res.status);
    systemSource = await res.text();
} catch (e) {
    $("press").textContent = `讀不到系統卡匣 system.lua（${e.message}）`;
    throw e;
}

// 遊戲清單：N5 從 games.json 讀；現在是空的
engine.clearGames();

if (engine.loadSystem(systemSource) !== 0) {
    $("press").textContent = "系統卡匣執行錯誤（看提示框或主控台）";
}

await waitForStart();
$("boot").classList.add("hidden");
startLoop(engine, $("screen"), getInput);
