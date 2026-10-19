# 網頁版 Nova 與系統卡匣
#
# 用法（在 nova-system 資料夾裡）：
#   make         產生系統卡匣 build/system.lua
#   make web     產生網頁版 Nova 到 build/web/（引擎從 comet 編譯、複製過來）
#   make serve   瀏覽器開 http://localhost:8422
#   make clean   清除編譯結果
#
# 引擎預設在旁邊的 ../comet；在別的地方的話：make serve ENGINE=/path/to/comet

ENGINE ?= ../comet
PORT ?= 8422

# 網頁版 Nova 要用到的引擎檔案（只拿需要的，Studio 之類的不放進來）
ENGINE_FILES = comet.wasm comet.js input.js touchpad.js play.css

# 系統卡匣：和遊戲一樣，用引擎附的合併工具
build/system.lua: comet.json $(wildcard src/*.lua)
	node $(ENGINE)/tools/cart.mjs .

# 1. 用引擎自己的 Makefile 編譯網頁版（引擎有改過才會重新編譯）
# 2. 從引擎拿需要的檔案，再放上 Nova 自己的網頁和系統卡匣
web: build/system.lua $(wildcard web/*)
	$(MAKE) -C $(ENGINE) web
	mkdir -p build/web
	cd $(ENGINE)/build/web && cp $(ENGINE_FILES) $(CURDIR)/build/web/
	cp web/* build/web/
	cp build/system.lua build/web/system.lua

serve: web
	@echo "電腦：http://localhost:$(PORT)"
	@for i in en0 en1 en2; do ip=$$(ipconfig getifaddr $$i 2>/dev/null) && echo "手機：http://$$ip:$(PORT)"; done; true
	python3 $(ENGINE)/tools/serve.py $(PORT) build/web

clean:
	rm -rf build

.PHONY: web serve clean
