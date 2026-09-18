#!/bin/bash
set -eo pipefail
lib_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export TSCODE_CONFIG_DIR=${TSCODE_CONFIG_DIR:-/config}
# shellcheck source=config.sh
. "$lib_dir/config.sh"
# shellcheck source=tools.sh
. "$lib_dir/tools.sh"
# shellcheck source=workspace-user.sh
. "$lib_dir/workspace-user.sh"
# shellcheck source=layout.sh
. "$lib_dir/layout.sh"

mkdir -p "$config_dir"
startup() {
    trap 'printf "Startup failed (exit %s).\n" "$?" >&2' ERR

    # Keep apt's files and database together; partial mounts cannot preserve installs.
    for directory in usr etc var; do
        if [ ! "/$directory" -ef "/packages/$directory" ]; then
            fail 'Persistent package mounts are missing. Start with tscode or follow the Docker instructions.'
            exit 1
        fi
    done
    if [ -d "$config_dir/.config-docker" ]; then
        cp -R "$config_dir/.config-docker/." "$HOME/"
    fi
    panes=${panes-${defaults[0]#*=}}
    validate panes "$panes"
    ensure_tool core
    if [ -f "$config_dir/toolchains" ]; then
        # The container uses Bash: read one tool per line, ignoring empty lines.
        readarray -t saved < <(sed '/^$/d' "$config_dir/toolchains")
        if [ "${#saved[@]}" -gt 0 ]; then
            "$lib_dir/tscode-install" "${saved[@]}" || printf 'Could not install a saved toolchain; continuing.\n' >&2
        fi
    fi
    # Restored Node was installed by a child process; load its environment here too.
    . /tscode/config/bash-env
    if [ -f "$config_dir/startup-docker.sh" ]; then
        . "$config_dir/startup-docker.sh"
    fi
    setup_workspace_user
    # Also supports non-interactive commands for diagnostics and container tests.
    if [ "$#" -gt 0 ]; then
        workspace_exec "$@"
        return
    fi

    create_workspace "$panes"
    touch /run/tscode.ready
    printf 'Workspace ready.\n'
}
# A file avoids keeping startup alive through descriptors inherited by tmux.
(umask 077; : > "$config_dir/startup.log")
startup "$@" <&0 > "$config_dir/startup.log" 2>&1 &
startup_pid=$!
tail --pid="$startup_pid" -n +1 -f "$config_dir/startup.log" &
log_pid=$!
startup_status=0
wait "$startup_pid" || startup_status=$?
wait "$log_pid"
[ "$startup_status" = 0 ] || exit "$startup_status"

# Keep the container alive while the workspace exists, even with no attached client.
while workspace_exec tmux has-session -t tscode 2>/dev/null; do sleep 1; done
