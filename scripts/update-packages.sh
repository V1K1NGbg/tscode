#!/bin/bash
set -eo pipefail

# Restore ownership of newly installed toolchain files, including on failure.
if [ -f /tscode/scripts/workspace-user.sh ]; then
    . /tscode/scripts/workspace-user.sh
    trap own_toolchains EXIT
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Update only toolchains already installed in the persistent package volume.
if [ -s "${NVM_DIR:-/packages/nvm}/nvm.sh" ]; then
    . "${NVM_DIR:-/packages/nvm}/nvm.sh"
    if command -v node >/dev/null; then
        previous_node=$(nvm current)
        nvm install --lts
        if [ "$(nvm current)" != "$previous_node" ]; then
            nvm reinstall-packages "$previous_node"
        fi
        nvm alias default 'lts/*'
        npm update --global
    fi
fi
if command -v rustup >/dev/null; then
    rustup update stable
fi
printf 'Packages updated. Restart the workspace to use updated tools in all panes.\n'
