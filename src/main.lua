-- main.lua — Nova 的系統卡匣：開機後的 HOME 畫面
--
-- 這是一個 Comet 遊戲，但由 engine_load_system() 載入，所以多了 sys 表格：
--   sys.games()      平台提供的遊戲清單
--   sys.launch(id)   啟動一款遊戲
--   sys.last_game()  剛剛從哪一款回來
-- 網頁版 Nova 和 Nova One 主機跑的是同一份檔案。
--
-- N4：只有開機畫面（星空＋標題）。大廳（列出遊戲、啟動）在 N5。

local stars = {}
local games = {}

-- 星星的位置、速度用「放大 16 倍的整數」（AI_GUIDE 規則 2），往左慢慢飄
local function new_star(x)
    return {
        x = x * 16,
        y = rnd(SCREEN_H),
        speed = 4 + rnd(28),          -- 每幀移動 0.25～2 像素
    }
end

function _init()
    games = sys.games()
    for i = 1, 60 do
        stars[i] = new_star(rnd(SCREEN_W))
    end
end

function _update()
    for i, s in ipairs(stars) do
        s.x = s.x - s.speed
        if s.x < 0 then stars[i] = new_star(SCREEN_W) end
    end
end

-- 畫一行置中的字
local function center(str, y, color)
    text(str, (SCREEN_W - textw(str)) // 2, y, color)
end

function _draw()
    cls(0)
    -- 快的星星比較亮（看起來比較近）
    for _, s in ipairs(stars) do
        pset(s.x // 16, s.y, s.speed > 20 and 7 or (s.speed > 10 and 6 or 5))
    end

    center("N O V A", 92, 7)
    rect(110, 108, 100, 1, 12)
    center("開源遊戲主機", 116, 6)

    center("已安裝 " .. #games .. " 款遊戲", 196, 5)
    -- 閃爍：每 60 幀裡亮 40 幀
    if frame() % 60 < 40 then
        center("大廳製作中（N5）", 212, 13)
    end
end
