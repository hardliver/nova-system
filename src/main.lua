-- main.lua — Nova 的系統卡匣：HOME（大廳）
--
-- 這是一個 Comet 遊戲，但由 engine_load_system() 載入，所以多了 sys 表格：
--   sys.games()      平台提供的遊戲清單 { { id =, name =, desc =, players = }, ... }
--   sys.launch(id)   啟動一款遊戲（這一幀結束後平台才會換）
--   sys.last_game()  剛剛從哪一款回來
-- 網頁版 Nova 和 Nova One 主機跑的是同一份檔案。
--
-- 每次回到 HOME，這個檔案都會重新載入（_init 重跑），
-- 所以「游標停在哪一款」靠 sys.last_game() 找回來。
--
-- 遊戲名稱、介紹是執行時才從平台拿到的，字型裡要先有那些字：
-- comet.json 的 fontText 列了 web/games.json，合併時會把裡面的字放進字型。
--
-- 版面（照最初的主選單設計）：
--   上方標題列 → 遊戲封面一排 → 分隔線 → 選到的遊戲資訊 → 下方操作列

local LEFT, RIGHT, A = 0, 1, 4

-- 版面的位置
local TILE = 64          -- 封面大小
local PITCH = 74         -- 封面和封面的間距（含空隙）
local ROW_X, ROW_Y = 12, 50
local INFO_Y = 142       -- 分隔線的位置，下面是遊戲資訊
local BAR_Y = 212        -- 下方操作列

-- 介面用的顏色：放在調色盤最後面（封面圖片從 16 號往後用，不會撞到）
local BG, BAR, LINE, DIM, SOFT, GOLD, GREEN = 249, 250, 251, 252, 253, 254, 255

-- 內建遊戲的封面（comet.json 的 images）。之後商城下載的遊戲，封面會跟著遊戲一起來
local COVERS = {
    ["hardliver/wildkin"] = IMG.cover_wildkin,
    ["hardliver/incident-report"] = IMG.cover_incident,
}
local FALLBACK = { 12, 8, 11, 9, 14, 13 }   -- 沒有封面的遊戲：色塊＋名稱第一個字

local games = {}
local cursor = 1
local scroll = 0         -- 封面整排往左捲了幾像素
local launching = nil    -- 按下 A 之後：正在啟動哪一款
local ready = false      -- 剛載入時，等所有按鍵都放開才接受輸入
local prev = {}          -- 上一幀每個鍵有沒有按著（判斷「剛按下」用）

-- ---------- 小工具 ----------

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- 這一幀剛按下（上一幀沒按、這一幀按著）
local function pressed(b)
    return btn(0, b) and not prev[b]
end

local function any_down()
    for b = 0, 12 do
        if btn(0, b) then return true end
    end
    return false
end

local function center(str, y, color)
    text(str, (SCREEN_W - textw(str)) // 2, y, color)
end

-- 空心方框：上下左右四條
local function frame_rect(x, y, w, h, t, c)
    rect(x, y, w, t, c)
    rect(x, y + h - t, w, t, c)
    rect(x, y, t, h, c)
    rect(x + w - t, y, t, h, c)
end

-- 實心圓：一列一列畫橫線。每一列的半寬 = √(r² − dy²)，用整數找（不能用小數）
local function disc(cx, cy, r, c)
    for dy = -r, r do
        local w = 0
        while (w + 1) * (w + 1) + dy * dy <= r * r do w = w + 1 end
        rect(cx - w, cy + dy, w * 2 + 1, 1, c)
    end
end

-- 名稱的第一個字（utf8 的一個字可能是好幾個 byte）
local function first_char(s)
    local second = utf8.offset(s, 2)
    return second and s:sub(1, second - 1) or s
end

-- ---------- 引擎呼叫的三個函式 ----------

function _init()
    pal(BG,    24,  29,  56)   -- 深藍底
    pal(BAR,   15,  18,  38)   -- 標題列、操作列（更深）
    pal(LINE,  52,  60, 104)   -- 分隔線
    pal(DIM,  128, 136, 176)   -- 次要文字
    pal(SOFT, 200, 206, 228)   -- 介紹文字
    pal(GOLD, 246, 200,  72)   -- NOVA 標題
    pal(GREEN, 76, 191,  90)   -- A 鍵

    games = sys.games()
    local last = sys.last_game()
    for i, g in ipairs(games) do
        if g.id == last then cursor = i end
    end
end

function _update()
    -- 剛回到 HOME 時，Start＋Select（或開機時按的鍵）可能還按著：
    -- 全部放開之前不理會輸入，免得一回來就又啟動了一款
    if not ready then
        ready = not any_down()
    elseif not launching and #games > 0 then
        if pressed(LEFT) then cursor = clamp(cursor - 1, 1, #games) end
        if pressed(RIGHT) then cursor = clamp(cursor + 1, 1, #games) end
        if pressed(A) and sys.launch(games[cursor].id) then
            launching = games[cursor]
        end
    end

    -- 捲動：游標超出畫面才捲，讓選到的封面停在第 3 格；兩端不要捲出空白
    local visible = (SCREEN_W - ROW_X) // PITCH
    local target = clamp((cursor - 3) * PITCH, 0, math.max(0, (#games - visible) * PITCH))
    scroll = scroll + (target - scroll) // 3   -- 每幀靠近 1/3：滑過去，不是瞬間跳過去
    if math.abs(target - scroll) < 3 then scroll = target end

    for b = 0, 12 do prev[b] = btn(0, b) end
end

local function draw_cover(g, i, x)
    local img = COVERS[g.id]
    if img then
        spr(img, 0, x, ROW_Y)
    else
        rect(x, ROW_Y, TILE, TILE, FALLBACK[(i - 1) % #FALLBACK + 1])
        rect(x + 4, ROW_Y + 4, TILE - 8, TILE - 8, BAR)
        local c = first_char(g.name)
        text(c, x + (TILE - textw(c)) // 2, ROW_Y + 25, 7)
    end
end

function _draw()
    cls(BG)

    -- 上方標題列
    rect(0, 0, SCREEN_W, 24, BAR)
    text("NOVA", 12, 5, GOLD)

    if #games == 0 then
        center("還沒有遊戲", 110, DIM)
        return
    end

    text("我的遊戲  " .. #games, 12, 30, DIM)

    -- 封面一排；選到的那款外面一圈白框，封面下方寫名稱
    for i, g in ipairs(games) do
        local x = ROW_X + (i - 1) * PITCH - scroll
        if x > -TILE and x < SCREEN_W then
            draw_cover(g, i, x)
            if i == cursor then
                frame_rect(x - 3, ROW_Y - 3, TILE + 6, TILE + 6, 2, 7)
                local name = g.name
                local nx = clamp(x + (TILE - textw(name)) // 2, 4, SCREEN_W - 4 - textw(name))
                text(name, nx, ROW_Y + TILE + 7, 7)
            end
        end
    end

    -- 選到的遊戲資訊
    local g = games[cursor]
    rect(12, INFO_Y, SCREEN_W - 24, 1, LINE)
    text(g.name, 12, INFO_Y + 10, 7)
    local meta = g.id
    if g.players > 0 then meta = meta .. "    " .. g.players .. " 人" end
    text(meta, 12, INFO_Y + 30, DIM)
    if g.desc ~= "" then text(g.desc, 12, INFO_Y + 50, SOFT) end

    -- 下方操作列
    rect(0, BAR_Y, SCREEN_W, SCREEN_H - BAR_Y, BAR)
    if launching then
        text("載入中……", 12, BAR_Y + 7, GOLD)
    else
        disc(19, BAR_Y + 13, 7, GREEN)
        text("A", 17, BAR_Y + 7, 7)
        text("開始", 31, BAR_Y + 7, 7)
        local hint = "遊戲中按住 Start＋Select 回到這裡"
        text(hint, SCREEN_W - 12 - textw(hint), BAR_Y + 7, DIM)
    end
end
