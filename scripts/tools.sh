#!/bin/bash

# Run downloaded installers in a subshell so cleanup also runs on failure.
run_installer() (
    url=$1
    shift
    installer=$(mktemp) || return
    trap 'rm -f "$installer"' EXIT
    curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$installer" && bash "$installer" "$@"
)

apt_packages() {
    local package missing=0
    for package in "$@"; do
        if [ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null)" != 'install ok installed' ]; then
            missing=1
        fi
    done
    [ "$missing" -eq 1 ] || return 0
    if [ "${apt_updated:-0}" -eq 0 ]; then
        apt-get update || return
        apt_updated=1
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

install_configured() {
    if ! ensure_tool "$editor"; then
        printf 'Could not install %s; using ranger for this session.\n' "$editor" >&2
        editor=ranger
        ensure_tool ranger || return
    fi
    if ! ensure_tool "$browser"; then
        printf 'Could not install %s; using elinks for this session.\n' "$browser" >&2
        browser=elinks
        ensure_tool elinks || return
    fi
    if [ "${debug:-0}" = 1 ] && ! ensure_tool "$top"; then
        printf 'Could not install %s; using htop for this session.\n' "$top" >&2
        top=htop
        ensure_tool htop || return
    fi
}

# shellcheck source=../config/packages.sh
. "$(dirname "${BASH_SOURCE[0]}")/../config/packages.sh"
