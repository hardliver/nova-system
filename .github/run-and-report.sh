#!/usr/bin/env bash
# run-and-report.sh — 執行一個指令；失敗時把最後 20 行輸出變成 GitHub Actions 的錯誤標記
# 用法：.github/run-and-report.sh make -C comet web
log="$(mktemp)"
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
    tail -n 20 "$log" | while IFS= read -r line; do
        echo "::error::${line}"
    done
fi
exit "$status"
