#!/bin/bash
# Package definitions and installation instructions.
# Ubuntu 26.04 is LTS; Java 25 is LTS; Node follows nvm's LTS channel.
# Rust has no LTS channel, so use stable. Other tools use Ubuntu LTS packages
# or their upstream stable npm release when no LTS channel exists.

ensure_node() {
    export NVM_DIR=${NVM_DIR:-/packages/nvm}
    apt_packages curl ca-certificates git || return
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        mkdir -p "$NVM_DIR" || return
        PROFILE=/dev/null run_installer https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh || return
    fi
    # nvm is shell code, and must be loaded into the caller's environment.
    . "$NVM_DIR/nvm.sh" || return
    if [ "$(nvm version 'lts/*')" = N/A ]; then
        nvm install --lts || return
    fi
    nvm alias default 'lts/*' >/dev/null || return
    nvm use --silent 'lts/*'
}

ensure_tool() {
    case "$1" in
        core)
            apt_packages tmux less git curl ca-certificates ranger file nano sensible-utils \
                libssl3t64 libssh2-1t64 libbrotli1 || return
            ensure_node || return
            type -P opencode >/dev/null || npm install --global opencode-ai || return
            # Remove the browser installed by older TS Code versions.
            if [ -d "$(npm root --global)/carbonyl" ]; then npm uninstall --global carbonyl || return; fi
            ;;
        python) apt_packages python3 python3-pip python3-venv ;;
        java) apt_packages openjdk-25-jdk ;;
        lua) apt_packages lua5.4 ;;
        cpp) apt_packages build-essential gdb cmake ;;
        node) ensure_node ;;
        rust)
            apt_packages build-essential curl ca-certificates || return
            if ! command -v rustc >/dev/null || ! command -v cargo >/dev/null; then
                run_installer https://sh.rustup.rs -y --profile minimal --default-toolchain stable --no-modify-path || return
            fi
            ;;
        *) printf 'Unknown tool: %s\n' "$1" >&2; return 1 ;;
    esac
}
