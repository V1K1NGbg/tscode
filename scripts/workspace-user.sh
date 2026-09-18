#!/bin/bash

validate_workspace_user() {
    if ! [[ "${TSCODE_UID:-0}" =~ ^[0-9]+$ && "${TSCODE_GID:-0}" =~ ^[0-9]+$ ]]; then
        echo 'TSCODE_UID and TSCODE_GID must be numeric.' >&2
        return 1
    fi
    if [ "${TSCODE_UID:-0}" != 0 ] && [ -z "${TSCODE_GID:-}" ]; then
        echo 'Set TSCODE_GID along with TSCODE_UID.' >&2
        return 1
    fi
}

own_toolchains() {
    [ "${TSCODE_UID:-0}" != 0 ] || return 0
    local directory
    for directory in /packages/nvm /packages/cargo /packages/rustup; do
        [ ! -d "$directory" ] || find "$directory" -xdev -uid 0 -exec chown -h "$TSCODE_UID:$TSCODE_GID" {} +
    done
}

setup_workspace_user() {
    validate_workspace_user
    [ "${TSCODE_UID:-0}" != 0 ] || return 0
    apt_packages sudo passwd util-linux
    getent group "$TSCODE_GID" >/dev/null || groupadd -g "$TSCODE_GID" "tscode-$TSCODE_GID"
    getent passwd "$TSCODE_UID" >/dev/null || useradd -M -u "$TSCODE_UID" -g "$TSCODE_GID" -d /home/tscode -s /bin/bash "tscode-$TSCODE_UID"
    printf '#%s ALL=(ALL) NOPASSWD: ALL\n' "$TSCODE_UID" > /etc/sudoers.d/tscode
    chmod 440 /etc/sudoers.d/tscode
    # Never cross the project bind mount or follow a home symlink into the project.
    find /home/tscode -xdev -path /home/tscode/project -prune -o -uid 0 -exec chown -h "$TSCODE_UID:$TSCODE_GID" {} +
    own_toolchains
}

workspace_exec() {
    if [ "${TSCODE_UID:-0}" = 0 ]; then "$@"; return; fi
    local account
    account=$(getent passwd "$TSCODE_UID") || return
    account=${account%%:*}
    setpriv --reuid "$TSCODE_UID" --regid "$TSCODE_GID" --init-groups \
        env HOME=/home/tscode USER="$account" LOGNAME="$account" "$@"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -e
    validate_workspace_user
    workspace_exec "$@"
fi
