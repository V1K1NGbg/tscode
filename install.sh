#!/bin/bash
set -euo pipefail

source_dir=''
if [ -f "${BASH_SOURCE[0]:-}" ]; then
    source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
fi
if [ ! -f "$source_dir/scripts/tscode" ]; then
    command -v curl >/dev/null || { echo 'Install curl first.' >&2; exit 1; }
    download=$(mktemp -d)
    trap 'rm -rf "$download"' EXIT
    curl -fsSL "https://codeload.github.com/V1K1NGbg/tscode/tar.gz/${TSCODE_REF:-master}" -o "$download/source.tar.gz"
    mkdir "$download/source"
    tar -xzf "$download/source.tar.gz" --strip-components=1 -C "$download/source"
    source_dir="$download/source"
fi

command -v docker >/dev/null || { echo 'Install Docker first: https://docs.docker.com/get-started/get-docker/' >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo 'Start Docker and ensure your user can access its daemon, then retry.' >&2; exit 1; }
user_dir=${TSCODE_HOME:-$HOME}
install_dir="$user_dir/.tscode"
bin_dir="$user_dir/.local/bin"
mkdir -p "$install_dir/scripts" "$install_dir/config" "$bin_dir"
for name in tscode tscodeconf; do
    if [ -e "$bin_dir/$name" ] && [ ! -L "$bin_dir/$name" ]; then
        echo "Refusing to replace an existing file: $bin_dir/$name" >&2
        exit 1
    fi
    if [ -L "$bin_dir/$name" ] && [ "$(readlink "$bin_dir/$name")" != "$install_dir/scripts/$name" ]; then
        echo "Refusing to replace an unrelated command link: $bin_dir/$name" >&2
        exit 1
    fi
done
cp "$source_dir"/scripts/* "$install_dir/scripts/"
cp "$source_dir"/config/* "$install_dir/config/"
cp "$source_dir/Dockerfile" "$source_dir/.dockerignore" "$install_dir/"
. "$install_dir/scripts/storage.sh"
prepare_image "$install_dir"
chmod +x "$install_dir/scripts/tscode" "$install_dir/scripts/tscodeconf"
for name in tscode tscodeconf; do
    ln -sfn "$install_dir/scripts/$name" "$bin_dir/$name"
done
. "$install_dir/scripts/config.sh"
repair_config

# Bash login shells (including macOS Terminal) read the first existing login profile.
bash_profile="$user_dir/.bash_profile"
for candidate in .bash_profile .bash_login .profile; do
    if [ -f "$user_dir/$candidate" ]; then
        bash_profile="$user_dir/$candidate"
        break
    fi
done
profiles=("$user_dir/.bashrc" "$bash_profile" "${ZDOTDIR:-$user_dir}/.zshrc")
# Validate every profile before writing any of them.
for rc in "${profiles[@]}"; do
    [ -f "$rc" ] || continue
    if ! awk '
        $0 == "# >>> TS Code >>>" {if (inside) bad=1; inside=1}
        $0 == "# <<< TS Code <<<" {if (!inside) bad=1; inside=0}
        END {exit (bad || inside)}
    ' "$rc"; then
        printf 'Malformed TS Code markers in %s; no shell profiles were changed.\n' "$rc" >&2
        exit 1
    fi
done
# Update our PATH block; preserve all unrelated shell configuration.
for rc in "${profiles[@]}"; do
    mkdir -p "$(dirname "$rc")"
    touch "$rc"
    tmp=$(mktemp "${rc}.XXXXXX")
    awk '
        $0 == "# >>> TS Code >>>" {skip=1; next}
        $0 == "# <<< TS Code <<<" {skip=0; next}
        /^alias tscode(conf)?=/ && /\.tscode\/tscode(_edit_conf)?\.sh/ {next}
        !skip {print}
    ' "$rc" > "$tmp"
    # shellcheck disable=SC2016 # Expand PATH when the user opens their shell.
    printf '# >>> TS Code >>>\nexport PATH=%q:"$PATH"\n# <<< TS Code <<<\n' "$bin_dir" >> "$tmp"
    # Preserve rc symlinks and permissions.
    cat "$tmp" > "$rc"
    rm -f "$tmp"
done
printf '\nInstalled. Open a new terminal and run: tscode\nOr run now: %q\n' "$bin_dir/tscode"
