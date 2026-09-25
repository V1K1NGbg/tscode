#!/bin/bash
# Run with cha and tmux installed; no network or user profile is needed.
set -euo pipefail
repo=${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}
work=$(mktemp -d)
cleanup() { tmux -S "$work/socket" kill-server 2>/dev/null || true; rm -rf "$work"; }
trap cleanup EXIT
printf '<title>Hints</title><a href="next.html">Open destination</a>\n' > "$work/index.html"
printf '<title>Destination</title><h1>LINK_HINT_SUCCESS</h1>\n' > "$work/next.html"
for ((row=0; row<80; row++)); do printf '<p>Row %s</p>\n' "$row" >> "$work/next.html"; done
tmux -S "$work/socket" -f /dev/null new-session -d -s browser -x 100 -y 30 \
    cha -C "$repo/config/chawan.toml" "$work/index.html"
for ((attempt=0; attempt<50; attempt++)); do
    if tmux -S "$work/socket" capture-pane -p -t browser | grep -q 'Open destination'; then break; fi
    sleep 0.1
done
tmux -S "$work/socket" capture-pane -p -t browser | grep -q 'Open destination'
# The only link gets hint a; following it must not require Enter or a mouse.
tmux -S "$work/socket" send-keys -t browser f
for ((attempt=0; attempt<50; attempt++)); do
    if tmux -S "$work/socket" capture-pane -p -t browser | grep -q 'apen destination'; then break; fi
    sleep 0.1
done
tmux -S "$work/socket" capture-pane -p -t browser | grep -q 'apen destination'
tmux -S "$work/socket" send-keys -t browser a
for ((attempt=0; attempt<50; attempt++)); do
    if tmux -S "$work/socket" capture-pane -p -t browser | grep -q LINK_HINT_SUCCESS; then break; fi
    sleep 0.1
done
tmux -S "$work/socket" capture-pane -p -t browser | grep -q LINK_HINT_SUCCESS
tmux -S "$work/socket" send-keys -t browser C-d
for ((attempt=0; attempt<50; attempt++)); do
    if ! tmux -S "$work/socket" capture-pane -p -t browser | grep -q LINK_HINT_SUCCESS; then break; fi
    sleep 0.1
done
tmux -S "$work/socket" capture-pane -p -t browser > "$work/screen"
grep -q 'Row ' "$work/screen"
if grep -q LINK_HINT_SUCCESS "$work/screen"; then exit 1; fi
echo 'Chawan link hints and scrolling passed.'
