// nova.js — 網頁版 Nova 的外殼（「平台」）
//
// 網頁版 Nova ＝ 瀏覽器 ＋ Comet 引擎（wasm）＋ 這個外殼 ＋ 系統卡匣（system.lua）。
// 外殼只做「平台」的事：輸入、畫面、開機畫面、載入檔案；
// 主選單長什麼樣子、怎麼選遊戲，全部寫在系統卡匣（src/main.lua），和主機共用。
//
// 引擎、輸入、虛擬手把（含設定選單）的程式從 comet 複製過來（make 時），不在這個 repo 裡。

import { createEngine, startLoop } from "./comet.js";
import { setupKeyboard, setupTouch, readGamepad, connectedPads, merge } from "./input.js";
import { setupTouchpad } from "./touchpad.js";
import { setupPadMenu } from "./padmenu.js";

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
setupPadMenu(setupTouchpad(), showHint);   // 手機右上角的選單：按鍵配置、透明度、調整位置、全螢幕
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

// ---- 遊戲清單：games.json ----
// [{ id, name, desc, players, file, pak }]：id 和遊戲檔開頭的「-- id:」相同，file 是遊戲檔的網址，
// pak 是資源包的網址（沒有就不寫）。desc、players 只給大廳顯示用。
// 列了但伺服器上找不到檔案的遊戲（例如 GitHub Pages 上沒有事故報告）直接跳過，大廳不會出現。
// 之後的商城（N7、N8）會換成「從 nova-official 的精選清單下載」，系統卡匣不用改
const gameInfo = new Map();   // id → { file, pak }
try {
    const list = await fetch("games.json").then((r) => r.json());
    // 同時問每個遊戲檔在不在（HEAD 只拿檔頭，不下載內容）
    const exists = await Promise.all(list.map((g) =>
        fetch(g.file, { method: "HEAD" }).then((r) => r.ok).catch(() => false)));
    engine.clearGames();
    list.forEach((g, i) => {
        if (!exists[i]) return;
        if (engine.addGame(g.id, g.name, { desc: g.desc, players: g.players }) === 0) {
            gameInfo.set(g.id, { file: g.file, pak: g.pak || null });
        }
    });
} catch (e) {
    showHint(`讀不到遊戲清單 games.json（${e.message}）`);
}

if (engine.loadSystem(systemSource) !== 0) {
    $("press").textContent = "系統卡匣執行錯誤（看提示框或主控台）";
}

// ---- 平台的工作：啟動遊戲、回 HOME ----
// 系統卡匣呼叫 sys.launch(id)、或玩家按 HOME 時，引擎只記下「請求」。
// 每跑完一幀，這裡看一次有沒有請求，有就去做（說明見 comet 的 core/system.h）
const sources = new Map();     // 讀過的遊戲檔留著，下次啟動不用再下載
const paks = new Map();        // 讀過的資源包也留著（Uint8Array）
let loading = false;

function randomSeed() {
    return crypto.getRandomValues(new Uint32Array(1))[0] || 1;
}

async function fetchText(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.text();
}

async function fetchBytes(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`資源包 HTTP ${res.status}`);
    return new Uint8Array(await res.arrayBuffer());
}

async function launch(id) {
    loading = true;
    try {
        const info = gameInfo.get(id);
        if (!sources.has(id)) sources.set(id, await fetchText(info.file));
        if (info.pak && !paks.has(id)) paks.set(id, await fetchBytes(info.pak));
        // 資源包要在 load() 之前交給引擎；沒有資源包的遊戲設成 null（順便放掉上一款的）
        if (engine.setPak(info.pak ? paks.get(id) : null) !== 0) throw new Error("資源包格式不對");
        // 和 Comet 遊玩頁一樣：每次開局新的亂數種子，從載入前就開始錄重播（之後成就驗證用）
        engine.setSeed(randomSeed());
        engine.recordBegin();
        if (engine.load(sources.get(id)) !== 0) {
            engine.replayStop();
            showHint("遊戲啟動時出錯（看主控台）。按住 Start＋Select 回 HOME");
        }
    } catch (e) {
        showHint(`讀不到遊戲 ${id}（${e.message}）`);
        engine.loadSystem(systemSource);   // 回到大廳（清掉「載入中」）
    } finally {
        loading = false;
    }
}

function goHome() {
    engine.replayStop();
    engine.setPak(null);   // 大廳用不到資源包：還給記憶體（JS 這邊的 paks 還留著，下次不用再下載）
    engine.loadSystem(systemSource);
}

function afterFrame() {
    if (loading) return;   // 還在下載上一款：請求留著，下載完再看
    const req = engine.request();
    if (req === 1) {
        const id = engine.requestGame();
        engine.requestDone();
        launch(id);
    } else if (req === 2) {
        engine.requestDone();
        goHome();
    }
}

await waitForStart();
$("boot").classList.add("hidden");
startLoop(engine, $("screen"), getInput, { afterFrame });
