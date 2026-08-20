#!/bin/bash
# Rebuild board.json (reps-only, retail/D2D, CAs) from the live tracker + agreements, and push it to
# GitHub Pages so the shared Rep Board link stays current. Safe: READ-ONLY on the tracker; only
# writes/pushes this one leaderboard file. Runs on Hunter's Mac (scheduled nightly, see the LaunchAgent).
set -euo pipefail

GA="$HOME/projects/google-automation"
SITE="$HOME/projects/rep-board-site"
LOG="$SITE/refresh.log"

ts() { date "+%Y-%m-%d %H:%M:%S"; }
echo "--- [$(ts)] refresh start ---" >> "$LOG"

cd "$GA"
# Build the public payload (JSON on stdout, a dropped-report after it). Keep just the JSON.
if ! "$GA/.venv/bin/python" rep_board.py --dry > /tmp/rep_board_out.txt 2>>"$LOG"; then
  echo "--- [$(ts)] build FAILED ---" >> "$LOG"; exit 1
fi
python3 - "$SITE/board.json" >> "$LOG" 2>&1 <<'PY'
import sys, json
t = open("/tmp/rep_board_out.txt").read()
d = t.find("Dropped from")
obj = json.loads(t[:d].strip() if d > 0 else t)
json.dump(obj, open(sys.argv[1], "w"), indent=1)
print("board.json: sales", len(obj["board"]), "cas", len(obj.get("cas", {}).get("board", [])))
PY

cd "$SITE"
if git diff --quiet -- board.json; then
  echo "--- [$(ts)] no change, nothing to push ---" >> "$LOG"; exit 0
fi
git add board.json
git commit -m "board refresh $(date +%Y-%m-%d)" >> "$LOG" 2>&1
git push >> "$LOG" 2>&1
echo "--- [$(ts)] pushed https://huntfair.github.io/rep-board/ ---" >> "$LOG"
