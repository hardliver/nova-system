-- main.lua — Nova 的系統卡匣：HOME（大廳）
--
-- 這是一個 Comet 遊戲，但由 engine_load_system() 載入，所以多了 sys 表格：
--   sys.games()      平台提供的遊戲清單 { { id = , name = }, ... }
--   sys.launch(id)   啟動一款遊戲（這一幀結束後平台才會換）
--   sys.last_game()  剛剛從哪一款回來
-- 網頁版 Nova 和 Nova One 主機跑的是同一份檔案。
--
-- 每次回到 HOME，這個檔案都會重新載入（_init 重跑），
-- 所以「游標停在哪一款」靠 sys.last_game() 找回來。
--
-- 遊戲名稱是執行時才從平台拿到的，字型裡要先有那些字：
-- comet.json 的 fontText 列了 web/games.json，合併時會把裡面的字放進字型。

local LEFT, RIGHT, A = 0, 1, 4

local TILE = 80          -- 遊戲方塊的大小
local PITCH = 92         -- 方塊和方塊的間距（含空隙）
local ROW_Y = 64
local LEFT_X = 24
local COLORS = { 12, 8, 11, 9, 14, 13 }   -- 方塊的顏色，依序輪流

local games = {}
local cursor = 1
local scroll = 0         -- 方塊整排往左捲了幾像素
local launching = nil    -- 按下 A 之後：正在啟動哪一款
local ready = false      -- 剛載入時，等所有按鍵都放開才接受輸入
local prev = {}          -- 上一幀每個鍵有沒有按著（判斷「剛按下」用）
local stars = {}

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

-- 星星：位置、速度用放大 16 倍的整數，往左慢慢飄
local function new_star(x)
    return { x = x * 16, y = rnd(SCREEN_H), speed = 4 + rnd(28) }
end

-- ---------- 引擎呼叫的三個函式 ----------

function _init()
    games = sys.games()
    local last = sys.last_game()
    for i, g in ipairs(games) do
        if g.id == last then cursor = i end
    end
    for i = 1, 60 do
        stars[i] = new_star(rnd(SCREEN_W))
    end
end

function _update()
    for i, s in ipairs(stars) do
        s.x = s.x - s.speed
        if s.x < 0 then stars[i] = new_star(SCREEN_W) end
    end

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

    -- 捲動：讓游標所在的方塊停在畫面第 2 格的位置，兩端不要捲出空白
    local target = clamp((cursor - 2) * PITCH, 0, math.max(0, (#games - 3) * PITCH))
    scroll = scroll + (target - scroll) // 3   -- 每幀靠近 1/3：滑過去，不是瞬間跳過去
    if math.abs(target - scroll) < 3 then scroll = target end

    for b = 0, 12 do prev[b] = btn(0, b) end
end

function _draw()
    cls(0)
    for _, s in ipairs(stars) do
        pset(s.x // 16, s.y, s.speed > 20 and 7 or (s.speed > 10 and 6 or 5))
    end

    -- 上方：標題、遊戲數
    text("N O V A", 16, 14, 7)
    local count = #games .. " 款遊戲"
    text(count, SCREEN_W - 16 - textw(count), 14, 5)
    rect(16, 30, SCREEN_W - 32, 1, 1)

    if #games == 0 then
        center("還沒有遊戲", 110, 6)
        return
    end

    -- 遊戲方塊
    for i, g in ipairs(games) do
        local x = LEFT_X + (i - 1) * PITCH - scroll
        if x > -TILE and x < SCREEN_W then
            rect(x, ROW_Y, TILE, TILE, COLORS[(i - 1) % #COLORS + 1])
            rect(x + 6, ROW_Y + 6, TILE - 12, TILE - 12, 1)
            -- 方塊中間：名稱的第一個字（utf8 的一個字可能是好幾個 byte）
            local second = utf8.offset(g.name, 2)
            local first = second and g.name:sub(1, second - 1) or g.name
            text(first, x + (TILE - textw(first)) // 2, ROW_Y + 34, 7)
            if i == cursor then
                -- 選到的方塊：外面一圈黃框，會閃
                local c = frame() % 40 < 30 and 10 or 9
                frame_rect(x - 4, ROW_Y - 4, TILE + 8, TILE + 8, 2, c)
            end
        end
    end

    -- 選到的遊戲名稱
    center(games[cursor].name, ROW_Y + TILE + 14, 7)

    -- 下方：操作說明
    if launching then
        center("載入中……", 196, 10)
    else
        center("A 開始　← → 選擇", 196, 6)
    end
    center("遊戲中按住 Start＋Select 回到這裡", 216, 5)
end
