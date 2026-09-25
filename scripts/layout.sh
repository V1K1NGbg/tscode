#!/bin/bash

create_workspace() {
    local index target direction percent command
    local ids=() flags=() pane_specs=()
    parse_panes "$1" || return
    # Build the whole layout before starting commands that may exit immediately.
    ids+=("$(workspace_exec tmux -f "$HOME/.tmux.conf" new-session -d -s tscode -x 160 -y 48 -P -F '#{pane_id}' /bin/bash --noprofile --norc)") || return
    workspace_exec tmux set-option -w -t "${ids[0]}" remain-on-exit off || return
    for ((index=1; index<${#pane_specs[@]}; index++)); do
        IFS=: read -r target direction percent command <<< "${pane_specs[index]}"
        case "$direction" in
            left) flags=(-h -b) ;; right) flags=(-h) ;;
            top) flags=(-v -b) ;; bottom) flags=(-v) ;;
        esac
        ids+=("$(workspace_exec tmux split-window "${flags[@]}" -l "$percent%" -t "${ids[target]}" -P -F '#{pane_id}' /bin/bash --noprofile --norc)") || return
    done
    workspace_exec tmux select-pane -t "${ids[0]}" || return
    for ((index=0; index<${#pane_specs[@]}; index++)); do
        command=${pane_specs[index]}
        if [ "$index" -gt 0 ]; then command=${command#*:*:*:}; fi
        workspace_exec tmux respawn-pane -k -t "${ids[index]}" /bin/bash -c "$command" || return
    done
}
