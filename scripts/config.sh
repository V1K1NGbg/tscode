#!/bin/bash

config_dir=${TSCODE_CONFIG_DIR:-${TSCODE_HOME:-$HOME}/.tscode}
defaults=(debug=0 website=https://lite.duckduckgo.com/lite/ editor=ranger browser=elinks top=htop)

fail() { printf 'tscode: %s\n' "$*" >&2; return 1; }

validate() {
    case "$2" in *$'\n'*|*$'\r'*) fail 'Values must be a single line'; return 1 ;; esac
    case "$1:$2" in
        debug:0|debug:1) return 0 ;;
        editor:ranger|editor:nano|editor:vim) return 0 ;;
        browser:elinks|browser:links|browser:lynx|browser:carbonyl) return 0 ;;
        top:htop|top:top|top:vtop|top:gtop) return 0 ;;
        website:*) [ -n "$2" ] && return 0 ;;
    esac
    fail "Invalid setting: $1=$2"
}

repair_config() {
    mkdir -p "$config_dir"
    local tmp setting
    tmp=$(mktemp "$config_dir/config.XXXXXX") || return
    if [ -f "$config_dir/config.conf" ]; then
        # Normalize the final newline without accumulating blank lines on each launch.
        awk '{print}' "$config_dir/config.conf" > "$tmp" || { rm -f "$tmp"; return 1; }
    fi
    for setting in "${defaults[@]}"; do
        if ! grep -q "^${setting%%=*}=" "$tmp"; then
            printf '%s\n' "$setting" >> "$tmp"
        fi
    done
    mv "$tmp" "$config_dir/config.conf"
}

check_config() {
    local line key seen=' '
    [ -f "$config_dir/config.conf" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in ''|'#'*) continue ;; esac
        key=${line%%=*}
        case "$line" in *=*) ;; *) fail "Expected key=value: $line"; return 1 ;; esac
        validate "$key" "${line#*=}" || return
        case "$seen" in *" $key "*) fail "Duplicate setting: $key"; return 1 ;; esac
        seen="$seen$key "
    done < "$config_dir/config.conf"
}
