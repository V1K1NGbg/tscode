#!/bin/bash
# Run with Bash and tmux installed; uses an isolated tmux server.
set -euo pipefail
repo=${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}
work=$(mktemp -d)
cleanup() { tmux -S "$work/socket" kill-server 2>/dev/null || true; rm -rf "$work"; }
trap cleanup EXIT
. "$repo/scripts/config.sh"
. "$repo/scripts/layout.sh"
workspace_exec() {
    shift # tmux
    if [ "$1" = -f ]; then shift 2; fi
    tmux -S "$work/socket" -f /dev/null "$@"
}
# Stub only application processes; exercise real tmux, Bash, and the default commands.
mkdir "$work/bin"
for app in ranger opencode cha; do
    cat > "$work/bin/$app" <<'APP'
#!/bin/bash
printf '%s\n' "$@" > "$PANE_TEST_DIR/${0##*/}.args"
exec sleep 60
APP
    chmod +x "$work/bin/$app"
done
export PATH="$work/bin:$PATH" PANE_TEST_DIR="$work" BASH_ENV="$repo/config/bash-env"
export website='https://example.com/a?x=1&y=2'
panes=${defaults[0]#*=}
create_workspace "$panes"
workspace_exec tmux list-panes -t tscode:0 -F '#{pane_left} #{pane_top} #{pane_width} #{pane_height}' > "$work/geometry"
printf '0 0 52 48\n53 0 53 23\n53 24 53 24\n107 0 53 48\n' > "$work/expected"
cmp "$work/expected" "$work/geometry"
for ((attempt=0; attempt<50; attempt++)); do
    [ ! -f "$work/cha.args" ] || break
    sleep 0.1
done
printf '%s\n' "$website" > "$work/expected"
cmp "$work/expected" "$work/cha.args"
workspace_exec tmux display-message -p -t tscode:0.0 '#{pane_start_command}' | grep ranger
workspace_exec tmux display-message -p -t tscode:0.1 '#{pane_start_command}' | grep opencode
workspace_exec tmux display-message -p -t tscode:0.2 '#{pane_start_command}' | grep 'bash -i'
workspace_exec tmux display-message -p -t tscode:0.3 '#{pane_start_command}' | grep cha
workspace_exec tmux kill-session -t tscode

# Custom browser commands receive exactly their explicit arguments.
for argument in --version https://example.org/explicit; do
    rm "$work/cha.args"
    create_workspace "cha $argument;0:right:50:bash -i"
    for ((attempt=0; attempt<50; attempt++)); do
        [ ! -f "$work/cha.args" ] || break
        sleep 0.1
    done
    printf '%s\n' "$argument" > "$work/expected"
    cmp "$work/expected" "$work/cha.args"
    workspace_exec tmux kill-session -t tscode
done

# Arbitrary commands support arguments, quotes, colons, pipes, and redirection.
# shellcheck disable=SC2016 # The inner shell must receive this literally.
panes='bash -i;0:right:50:printf "%s" "https://example.com/a:b" | cat > "$PANE_TEST_DIR/command-output" && ranger trailing:'
create_workspace "$panes"
for ((attempt=0; attempt<50; attempt++)); do
    [ ! -s "$work/command-output" ] || break
    sleep 0.1
done
[ "$(cat "$work/command-output")" = 'https://example.com/a:b' ]
for ((attempt=0; attempt<50; attempt++)); do
    [ "$(cat "$work/ranger.args")" != trailing: ] || break
    sleep 0.1
done
[ "$(cat "$work/ranger.args")" = trailing: ]
workspace_exec tmux kill-session -t tscode

# Splitting before a pane changes tmux indexes, but not our declaration references.
panes='bash -i;0:left:50:bash -i;0:top:50:bash -i'
create_workspace "$panes"
workspace_exec tmux list-panes -t tscode:0 -F '#{pane_left} #{pane_top} #{pane_width} #{pane_height}' > "$work/geometry"
printf '0 0 80 48\n81 0 79 24\n81 25 79 23\n' > "$work/expected"
cmp "$work/expected" "$work/geometry"
workspace_exec tmux kill-session -t tscode

# Fast-exiting commands cannot remove split targets before the layout is built.
create_workspace 'printf hello;0:right:50:tscode_missing_test_command;1:bottom:50:bash -i'
for ((attempt=0; attempt<50; attempt++)); do
    [ "$(workspace_exec tmux list-panes -t tscode:0 -F '#{pane_dead}')" != 0 ] || break
    sleep 0.1
done
[ "$(workspace_exec tmux list-panes -t tscode:0 -F '#{pane_dead}')" = 0 ]
# Exiting the final shell closes the session rather than leaving a dead pane.
workspace_exec tmux send-keys -t tscode:0.0 exit Enter
for ((attempt=0; attempt<50; attempt++)); do
    workspace_exec tmux has-session -t tscode 2>/dev/null || break
    sleep 0.1
done
if workspace_exec tmux has-session -t tscode 2>/dev/null; then exit 1; fi
echo 'Tmux layout checks passed.'
