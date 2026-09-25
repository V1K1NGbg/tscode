#!/bin/bash

config_dir=${TSCODE_CONFIG_DIR:-${TSCODE_HOME:-$HOME}/.tscode}
# shellcheck disable=SC2016 # The pane shell expands the homepage at launch.
defaults=('panes=ranger;0:right:67:opencode;1:right:50:cha "${website:-https://www.google.com}";1:bottom:50:bash -i' 'website=https://www.google.com')

fail() { printf 'tscode: %s\n' "$*" >&2; return 1; }

validate() {
    case "$2" in *$'\n'*|*$'\r'*) fail 'Values must be a single line'; return 1 ;; esac
    if [ "$1" = panes ]; then parse_panes "$2"; return; fi
    if [ "$1" = website ]; then
        [[ "$2" =~ ^https?://[^[:space:]]+$ ]] || { fail 'Website must be an http:// or https:// URL without spaces'; return 1; }
        return 0
    fi
    fail "Invalid setting: $1=$2"
}

# Each new pane splits a previously declared pane; indexes refer to declaration order.
parse_panes() {
    local spec command target index=0
    local split='^(0|[1-9][0-9]*):(left|right|top|bottom):([1-9][0-9]?):(.+)$'
    case "$1" in ''|';'*|*';'|*';;'*) fail 'Empty pane definition'; return 1 ;; esac
    IFS=';' read -r -a pane_specs <<< "$1"
    for spec in "${pane_specs[@]}"; do
        command=$spec
        if [ "$index" -gt 0 ]; then
            [[ "$spec" =~ $split ]] || { fail "Expected target:direction:percent:command: $spec"; return 1; }
            target=${BASH_REMATCH[1]}
            # Reject oversized numbers before arithmetic (including overflow).
            if [ "${#target}" -gt "${#index}" ] || [ "$target" -ge "$index" ]; then
                fail "Pane $index must split an earlier pane: $target"; return 1
            fi
            command=${BASH_REMATCH[4]}
        fi
        [[ "$command" =~ [^[:space:]] ]] || { fail 'Empty pane command'; return 1; }
        index=$((index + 1))
    done
}

repair_config() {
    mkdir -p "$config_dir"
    local tmp setting previous
    tmp=$(mktemp "$config_dir/config.XXXXXX") || return
    if [ -f "$config_dir/config.conf" ]; then
        # Preserve the old file before removing settings from the former app-based layout.
        local obsolete='^(debug|editor|browser|top|layout|editor_width|shell_height|top_width|help_height)=|^panes=default$'
        if grep -Eq "$obsolete" "$config_dir/config.conf" && [ ! -e "$config_dir/config.conf.before-commands" ]; then
            cp -p "$config_dir/config.conf" "$config_dir/config.conf.before-commands" || { rm -f "$tmp"; return 1; }
        fi
        # Migrate former helpers and Carbonyl commands; preserve other commands.
        # shellcheck disable=SC2016 # Keep website expansion literal in the saved command.
        awk -v obsolete="$obsolete" '
            $0 ~ obsolete {next}
            /^panes=/ {
                count = split(substr($0, 7), panes, ";")
                for (i = 1; i <= count; i++) {
                    prefix = ""
                    command = panes[i]
                    if (i > 1 && match(command, /^[0-9]+:[a-z]+:[0-9]+:/)) {
                        prefix = substr(command, 1, RLENGTH)
                        command = substr(command, RLENGTH + 1)
                    }
                    if (command == "shell") command = "bash -i"
                    else if (command ~ /^carbonyl([[:space:]]|$)/) {
                        sub(/^carbonyl([[:space:]]+--no-sandbox)?/, "cha", command)
                        if (command == "cha") command = "cha \"${website:-https://www.google.com}\""
                    }
                    panes[i] = prefix command
                }
                $0 = "panes=" panes[1]
                for (i = 2; i <= count; i++) $0 = $0 ";" panes[i]
            }
            {print}
        ' "$config_dir/config.conf" > "$tmp" || { rm -f "$tmp"; return 1; }
    fi
    for setting in "${defaults[@]}"; do
        if ! grep -q "^${setting%%=*}=" "$tmp"; then
            if [[ "$setting" == website=* ]] && [ -f "$config_dir/config.conf.before-commands" ]; then
                previous=$(grep '^website=' "$config_dir/config.conf.before-commands" | head -n 1) || true
                if [ -n "$previous" ] && validate website "${previous#*=}" 2>/dev/null; then setting=$previous; fi
            fi
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
