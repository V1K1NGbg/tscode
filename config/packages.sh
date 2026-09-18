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
        core) apt_packages tmux less git curl ca-certificates ;;
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
        ranger) apt_packages ranger file nano sensible-utils ;;
        nano|vim|elinks|links|lynx|htop) apt_packages "$1" ;;
        top) apt_packages procps ;;
        carbonyl|vtop|gtop)
            ensure_node || return
            if [ "$1" = carbonyl ]; then
                apt_packages libnss3 libexpat1 libasound2t64 libfontconfig1 || return
            fi
            if ! command -v "$1" >/dev/null; then
                npm install --global "$1" || return
            fi
            if [ "$1" = carbonyl ]; then
                carbonyl --no-sandbox --version >/dev/null || return
            fi
            ;;
        *) printf 'Unknown tool: %s\n' "$1" >&2; return 1 ;;
    esac
}
