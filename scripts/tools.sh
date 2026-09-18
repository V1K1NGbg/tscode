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

# shellcheck source=../config/packages.sh
. "$(dirname "${BASH_SOURCE[0]}")/../config/packages.sh"
