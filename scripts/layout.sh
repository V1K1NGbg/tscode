#!/bin/bash

create_workspace() {
    parse_panes "$1" || return
    local index target direction percent command
    local ids=() flags=()
    # Keep a clean shell alive until retention is enabled for the layout commands.
    ids+=("$(workspace_exec tmux -f "$HOME/.tmux.conf" new-session -d -s tscode -x 160 -y 48 -P -F '#{pane_id}' /bin/bash --noprofile --norc)") || return
    workspace_exec tmux set-option -w -t "${ids[0]}" remain-on-exit on || return
    workspace_exec tmux respawn-pane -k -t "${ids[0]}" /bin/bash -c "${pane_specs[0]}" || return
    for ((index=1; index<${#pane_specs[@]}; index++)); do
        IFS=: read -r target direction percent command <<< "${pane_specs[index]}"
        command=${pane_specs[index]#*:*:*:} # Preserve trailing colons stripped by read's IFS.
        case "$direction" in
            left) flags=(-h -b) ;; right) flags=(-h) ;;
            top) flags=(-v -b) ;; bottom) flags=(-v) ;;
        esac
        ids+=("$(workspace_exec tmux split-window "${flags[@]}" -l "$percent%" -t "${ids[target]}" -P -F '#{pane_id}' /bin/bash -c "$command")") || return
    done
    workspace_exec tmux select-pane -t "${ids[0]}"
}
