#!/bin/bash
set -euo pipefail
expect_failure() {
    if "$@"; then
        printf 'Expected failure: %s\n' "$*" >&2
        exit 1
    fi
}

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
work=$(mktemp -d)
work=$(cd "$work" && pwd -P)
trap 'rm -rf "$work"' EXIT
export TSCODE_HOME="$work/user space" ZDOTDIR="$work/user space"
export TSCODE_CONFIG_DIR="$TSCODE_HOME/.tscode" TSCODE_IMAGE=tscode:test
export TEST_LOG="$work/docker.log"
mkdir -p "$work/bin" "$TSCODE_CONFIG_DIR/.config-docker" "$work/project space"
cat > "$work/bin/docker" <<'STUB'
#!/bin/bash
printf '<%s>\n' "$@" >> "$TEST_LOG"
[ "${DOCKER_STATUS:-0}" = 0 ] || exit "$DOCKER_STATUS"
if [ "${1:-}" = inspect ]; then
    if [ "${CONTAINER_RUNNING:-false}" != true ] && [ ! -f "$TEST_LOG.running" ] && [ "${CONTAINER_STOPPED:-0}" != 1 ]; then exit 1; fi
    case "$3" in
        *State.Status*) if [ "${CONTAINER_STOPPED:-0}" = 1 ]; then echo exited; else echo running; fi ;;
        *State.Running*) if [ "${STARTUP_FAILED:-0}" = 1 ]; then echo false; else echo true; fi ;;
        *project*) echo "${RUNNING_PROJECT:-$TSCODE_HOME/project}" ;;
        *Mounts*) echo "$TSCODE_CONFIG_DIR" ;;
        *Labels*) echo "${MANAGED:-1}" ;;
        *Entrypoint*) echo "${ENTRYPOINT:-/tscode/scripts/entrypoint.sh}" ;;
        *Config.Image*) echo tscode:test ;;
    esac
    exit 0
fi
if [ "${1:-}" = run ]; then
    case " $* " in *' --name tscode '*) touch "$TEST_LOG.running" ;; esac
fi
if [ "${1:-}" = exec ]; then
    case " $* " in
        *' -it '*) rm -f "$TEST_LOG.running" ;;
        *' test -f /tscode/scripts/workspace-user.sh '*) exit "${LEGACY:-0}" ;;
        *' test -f /run/tscode.ready '*) exit "${NOT_READY:-0}" ;;
    esac
fi
if [ "${1:-}" = image ] && [ "${IMAGE_MISSING:-0}" = 1 ]; then exit 1; fi
if [ "${3:-}" = --format ]; then echo ubuntu26.04-v1-arm64; fi
exit 0
STUB
chmod +x "$work/bin/docker"
export PATH="$work/bin:$PATH"
printf 'editor=vim' > "$TSCODE_CONFIG_DIR/config.conf"
printf 'custom hook\n' > "$TSCODE_CONFIG_DIR/startup-docker.sh"
printf 'custom overlay\n' > "$TSCODE_CONFIG_DIR/.config-docker/.bashrc"
printf '# existing login profile\n' > "$TSCODE_HOME/.profile"
printf 'alias tscode="~/.tscode/tscode.sh"\nalias keep="echo keep"\n' > "$TSCODE_HOME/.bashrc"

bash "$repo/install.sh"
bash "$repo/install.sh"
[ "$(grep -c '^# >>> TS Code >>>' "$TSCODE_HOME/.bashrc")" = 1 ]
[ "$(grep -c '^# >>> TS Code >>>' "$TSCODE_HOME/.zshrc")" = 1 ]
[ "$(grep -c '^# >>> TS Code >>>' "$TSCODE_HOME/.profile")" = 1 ]
[ ! -e "$TSCODE_HOME/.bash_profile" ]
grep -qx '# existing login profile' "$TSCODE_HOME/.profile"
if grep -q '^alias tscode=' "$TSCODE_HOME/.bashrc"; then exit 1; fi
grep -q '^alias keep=' "$TSCODE_HOME/.bashrc"
grep -qx 'custom hook' "$TSCODE_CONFIG_DIR/startup-docker.sh"
grep -qx 'custom overlay' "$TSCODE_CONFIG_DIR/.config-docker/.bashrc"
grep -qx 'editor=vim' "$TSCODE_CONFIG_DIR/config.conf"
[ "$(grep -c '=' "$TSCODE_CONFIG_DIR/config.conf")" = 5 ]
bash -c '. "$TSCODE_HOME/.bashrc"; command -v tscode' | grep -F "$TSCODE_HOME/.local/bin/tscode"
if command -v zsh >/dev/null; then
    zsh -c '. "$ZDOTDIR/.zshrc"; command -v tscode' | grep -F "$TSCODE_HOME/.local/bin/tscode"
fi

cli="$TSCODE_HOME/.local/bin/tscode"
conf="$TSCODE_HOME/.local/bin/tscodeconf"
# shellcheck disable=SC2016 # Verify shell syntax stays literal.
"$conf" website 'https://example.com/?a=1&b=$(false)'
"$cli" "$work/project space"
grep -Fx "<$work/project space:/home/tscode/project>" "$TEST_LOG"
grep -Fx "<$TSCODE_CONFIG_DIR:/config>" "$TEST_LOG"
grep -Fx '<--env-file>' "$TEST_LOG"
grep -Fx '<type=volume,source=tscode-home,target=/home/tscode>' "$TEST_LOG"
for directory in usr etc var; do
    grep -Fx "<type=volume,source=tscode-ubuntu26.04-v1-arm64-packages,target=/$directory,volume-subpath=$directory,volume-nocopy>" "$TEST_LOG"
done
cp "$TSCODE_CONFIG_DIR/config.conf" "$work/before"
for value in 2 abc '1+0'; do
    expect_failure "$conf" debug "$value"
done
expect_failure "$conf" website $'https://example.com\neditor=nano'
expect_failure "$conf" 'debug editor' 1
cmp "$work/before" "$TSCODE_CONFIG_DIR/config.conf"
expect_failure "$cli" "$work/missing"
printf 'editor=nano\n' >> "$TSCODE_CONFIG_DIR/config.conf"
expect_failure "$cli" "$work/project space"
"$conf" editor nano
"$cli" "$work/project space"
DOCKER_STATUS=1 expect_failure bash "$repo/install.sh"

# Default builds the installed sources and never pulls a published app image.
: > "$TEST_LOG"
unset TSCODE_IMAGE
bash "$repo/install.sh"
"$cli" "$work/project space"
[ "$(grep -c '^<build>$' "$TEST_LOG")" = 2 ]
grep -Fx '<tscode:local>' "$TEST_LOG"
grep -Fx "<$TSCODE_HOME/.tscode>" "$TEST_LOG"
if grep -qx '<pull>' "$TEST_LOG"; then exit 1; fi
cmp "$repo/Dockerfile" "$TSCODE_HOME/.tscode/Dockerfile"
cmp "$repo/config/bash-env" "$TSCODE_HOME/.tscode/config/bash-env"
# Explicit image selection skips building.
: > "$TEST_LOG"
export TSCODE_IMAGE=tscode:test
"$cli" "$work/project space"
if grep -qx '<build>' "$TEST_LOG"; then exit 1; fi

# Resume attaches directly; updates work with and without a running workspace.
: > "$TEST_LOG"
CONTAINER_RUNNING=true "$cli" resume
grep -qx '<exec>' "$TEST_LOG"
grep -qx '<-it>' "$TEST_LOG"
grep -q 'exec tmux attach-session -t tscode' "$TEST_LOG"
if grep -qx '<run>' "$TEST_LOG"; then exit 1; fi
expect_failure "$cli" resume extra
: > "$TEST_LOG"
CONTAINER_RUNNING=true "$cli" update
grep -qx '<exec>' "$TEST_LOG"
if grep -qx '<run>' "$TEST_LOG"; then exit 1; fi
: > "$TEST_LOG"
"$cli" update
grep -qx '<run>' "$TEST_LOG"
grep -qx '<--entrypoint>' "$TEST_LOG"
if grep -qx '<exec>' "$TEST_LOG"; then exit 1; fi
DOCKER_STATUS=1 expect_failure "$cli" resume

# Internal controls use tmux without replacing the shell's ordinary exit command.
(
    tmux() { printf '%s\n' "$*" >> "$TEST_LOG"; }
    . "$repo/config/bash-env"
    : > "$TEST_LOG"
    tscode-detach
    tscode-exit
    printf 'detach-client\nkill-session -t tscode\n' > "$work/expected"
    cmp "$work/expected" "$TEST_LOG"
)

# Status and saved logs are read-only; same-project launches attach without building.
"$cli" status | grep -x 'Workspace: not running'
CONTAINER_RUNNING=true "$cli" status | grep -x 'Workspace: ready'
CONTAINER_RUNNING=true NOT_READY=1 "$cli" status | grep -x 'Workspace: starting'
CONTAINER_STOPPED=1 "$cli" status | grep -x 'Workspace: stopped'
DOCKER_STATUS=1 expect_failure "$cli" status
: > "$TEST_LOG"
CONTAINER_RUNNING=true RUNNING_PROJECT="$work/project space" "$cli" "$work/project space"
if grep -Eq '^<(build|run)>$' "$TEST_LOG"; then exit 1; fi
CONTAINER_RUNNING=true expect_failure "$cli" "$work/project space"
CONTAINER_STOPPED=1 expect_failure "$cli" "$work/project space"
CONTAINER_RUNNING=true MANAGED=0 ENTRYPOINT=/unrelated expect_failure "$cli" resume
CONTAINER_RUNNING=true MANAGED=0 LEGACY=1 "$cli" resume
printf 'saved failure diagnostics\n' > "$TSCODE_CONFIG_DIR/startup.log"
DOCKER_STATUS=1 "$cli" logs | grep -x 'saved failure diagnostics'
CONTAINER_RUNNING=true NOT_READY=1 STARTUP_FAILED=1 expect_failure "$cli" resume
"$cli" logs | grep -x 'saved failure diagnostics'
TSCODE_CONFIG_DIR="$work/no-config" expect_failure "$cli" logs

# Interrupting startup stops only the local follower, not the workspace.
: > "$TEST_LOG"
CONTAINER_RUNNING=true NOT_READY=1 "$cli" resume > "$work/wait-output" 2>&1 &
waiting_cli=$!
for ((attempt=0; attempt<50; attempt++)); do
    if grep -q 'Waiting for startup' "$work/wait-output"; then break; fi
    sleep 0.1
done
kill -TERM "$waiting_cli"
wait_status=0
wait "$waiting_cli" || wait_status=$?
[ "$wait_status" = 143 ]
if grep -Eq '^<(stop|kill|rm)>$' "$TEST_LOG"; then exit 1; fi

# Linux passes host IDs; macOS keeps root behavior (including offline updates).
cat > "$work/bin/uname" <<'STUB'
#!/bin/bash
printf '%s\n' "${TEST_OS:-Darwin}"
STUB
chmod +x "$work/bin/uname"
: > "$TEST_LOG"
TEST_OS=Linux "$cli" "$work/project space"
grep -Fx "<TSCODE_UID=$(id -u)>" "$TEST_LOG"
grep -Fx "<TSCODE_GID=$(id -g)>" "$TEST_LOG"
: > "$TEST_LOG"
TEST_OS=Darwin "$cli" "$work/project space"
grep -Fx '<TSCODE_UID=0>' "$TEST_LOG"
: > "$TEST_LOG"
TEST_OS=Linux "$cli" update
grep -Fx "<TSCODE_UID=$(id -u)>" "$TEST_LOG"
rm "$work/bin/uname"
. "$repo/scripts/workspace-user.sh"
TSCODE_UID=123 TSCODE_GID=456 validate_workspace_user
TSCODE_UID='1:2' TSCODE_GID=456 expect_failure validate_workspace_user
TSCODE_UID=123 TSCODE_GID='' expect_failure validate_workspace_user

# Display defaults without creating config; existing values remain literal and unchanged.
TSCODE_CONFIG_DIR="$work/no-config" "$conf" --show > "$work/shown"
[ ! -e "$work/no-config" ]
grep -qx editor=ranger "$work/shown"
cp "$TSCODE_CONFIG_DIR/config.conf" "$work/before"
"$conf" --show | grep -x editor=nano
cmp "$work/before" "$TSCODE_CONFIG_DIR/config.conf"
printf 'editor=vim\n' >> "$TSCODE_CONFIG_DIR/config.conf"
expect_failure "$conf" --show
cp "$work/before" "$TSCODE_CONFIG_DIR/config.conf"

# Reject malformed markers in any profile before touching the earlier valid profiles.
cp "$TSCODE_HOME/.bashrc" "$work/bashrc-before"
cp "$TSCODE_HOME/.profile" "$work/profile-before"
cp "$TSCODE_HOME/.zshrc" "$work/zshrc-before"
for markers in $'# >>> TS Code >>>\nexport KEEP=yes' $'# <<< TS Code <<<' $'# >>> TS Code >>>\n# >>> TS Code >>>\n# <<< TS Code <<<'; do
    printf '%s\n' "$markers" > "$TSCODE_HOME/.zshrc"
    cp "$TSCODE_HOME/.zshrc" "$work/bad-profile"
    expect_failure bash "$repo/install.sh"
    cmp "$work/bashrc-before" "$TSCODE_HOME/.bashrc"
    cmp "$work/profile-before" "$TSCODE_HOME/.profile"
    cmp "$work/bad-profile" "$TSCODE_HOME/.zshrc"
done
cp "$work/zshrc-before" "$TSCODE_HOME/.zshrc"
# Duplicate complete blocks are collapsed; symlink and target permissions survive.
mv "$TSCODE_HOME/.bashrc" "$work/bashrc-target"
ln -s "$work/bashrc-target" "$TSCODE_HOME/.bashrc"
chmod 640 "$work/bashrc-target"
cat "$work/bashrc-before" >> "$work/bashrc-target"
bash "$repo/install.sh"
[ -L "$TSCODE_HOME/.bashrc" ]
[ "$(grep -c '^# >>> TS Code >>>' "$TSCODE_HOME/.bashrc")" = 1 ]
[ -n "$(find "$work/bashrc-target" -perm 0640)" ]

# Package updates stop on errors and only update toolchains already present.
mkdir -p "$work/update-bin" "$work/nvm"
cat > "$work/update-bin/apt-get" <<'STUB'
#!/bin/bash
printf 'apt %s\n' "$*" >> "$TEST_LOG"
exit "${APT_STATUS:-0}"
STUB
chmod +x "$work/update-bin/apt-get"
: > "$TEST_LOG"
PATH="$work/update-bin" NVM_DIR="$work/nvm" /bin/bash "$repo/scripts/update-packages.sh"
printf 'apt update\napt upgrade -y\n' > "$work/expected"
cmp "$work/expected" "$TEST_LOG"
cat > "$work/nvm/nvm.sh" <<'STUB'
nvm() {
    if [ "$1" = current ]; then echo "${test_node:-v24.0.0}"; return; fi
    if [ "$1" = install ]; then test_node=v24.1.0; fi
    printf 'nvm %s\n' "$*" >> "$TEST_LOG"
}
node() { :; }
npm() { printf 'npm %s\n' "$*" >> "$TEST_LOG"; }
rustup() { printf 'rustup %s\n' "$*" >> "$TEST_LOG"; }
STUB
: > "$TEST_LOG"
PATH="$work/update-bin" NVM_DIR="$work/nvm" /bin/bash "$repo/scripts/update-packages.sh"
grep -qx 'nvm reinstall-packages v24.0.0' "$TEST_LOG"
grep -qx 'npm update --global' "$TEST_LOG"
grep -qx 'rustup update stable' "$TEST_LOG"
: > "$TEST_LOG"
expect_failure env PATH="$work/update-bin" NVM_DIR="$work/nvm" APT_STATUS=1 /bin/bash "$repo/scripts/update-packages.sh"
printf 'apt update\n' > "$work/expected"
cmp "$work/expected" "$TEST_LOG"

# A missing explicitly requested image is pulled, never built.
: > "$TEST_LOG"
IMAGE_MISSING=1 bash "$repo/install.sh"
grep -Fx '<pull>' "$TEST_LOG"
if grep -qx '<build>' "$TEST_LOG"; then exit 1; fi

# Configured tools: alternatives only when used; failure falls back without persisting it.
. "$repo/scripts/tools.sh"

# A partial download must never execute; installer failures must propagate and clean up.
# shellcheck disable=SC2329 # Called by run_installer through expect_failure.
curl() {
    cp "$work/download-script" "${@: -1}"
    printf '%s\n' "${@: -1}" > "$work/download-path"
    return "${download_status:-0}"
}
printf 'touch "%s"\n' "$work/should-not-run" > "$work/download-script"
download_status=1
expect_failure run_installer https://example.com/install.sh
[ ! -e "$work/should-not-run" ]
[ ! -e "$(cat "$work/download-path")" ]
download_status=0
printf 'exit 7\n' > "$work/download-script"
expect_failure run_installer https://example.com/install.sh
[ ! -e "$(cat "$work/download-path")" ]
unset -f curl

ensure_tool() { printf '%s\n' "$1" >> "$work/tools"; [ "$1" != "${FAIL_TOOL:-}" ]; }
editor=ranger browser=elinks top=gtop debug=0
install_configured
printf 'ranger\nelinks\n' > "$work/expected"
cmp "$work/expected" "$work/tools"
: > "$work/tools"
editor=vim browser=lynx top=gtop debug=1
install_configured
printf 'vim\nlynx\ngtop\n' > "$work/expected"
cmp "$work/expected" "$work/tools"
FAIL_TOOL=lynx
install_configured
[ "$browser" = elinks ]

# Exercise the real selection/recording script with only external installation stubbed.
mkdir "$work/installer"
cp "$repo/scripts/tscode-install" "$repo/scripts/workspace-user.sh" "$work/installer/"
cat > "$work/installer/tools.sh" <<'STUB'
ensure_tool() { printf '%s\n' "$1" >> "$TEST_LOG"; [ "$1" != "${FAIL_TOOL:-}" ]; }
STUB
cat > "$work/bin/id" <<'STUB'
#!/bin/bash
echo 0
STUB
cat > "$work/bin/chown" <<'STUB'
#!/bin/bash
# Ownership is exercised by Docker smoke tests; macOS lacks GNU --reference.
exit 0
STUB
chmod +x "$work/bin/id" "$work/bin/chown"
export FAIL_TOOL=java
expect_failure bash "$work/installer/tscode-install" python java
grep -qx python "$TSCODE_CONFIG_DIR/toolchains"
if grep -qx java "$TSCODE_CONFIG_DIR/toolchains"; then exit 1; fi
unset FAIL_TOOL
# Manually edited selections may have no final newline.
printf python > "$TSCODE_CONFIG_DIR/toolchains"
bash "$work/installer/tscode-install" python java
[ "$(grep -c '^python$' "$TSCODE_CONFIG_DIR/toolchains")" = 1 ]
grep -qx java "$TSCODE_CONFIG_DIR/toolchains"
cp "$TEST_LOG" "$work/before"
expect_failure bash "$work/installer/tscode-install" node bad
cmp "$work/before" "$TEST_LOG"
bash "$work/installer/tscode-install" all
[ "$(wc -l < "$TSCODE_CONFIG_DIR/toolchains" | tr -d ' ')" = 6 ]

# Exercise stdin bootstrap using the exact archive layout returned by GitHub.
export TEST_ARCHIVE="$work/source.tar.gz"
tar -czf "$TEST_ARCHIVE" --exclude=.git -C "$(dirname "$repo")" "$(basename "$repo")"
cat > "$work/bin/curl" <<'STUB'
#!/bin/bash
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then cp "$TEST_ARCHIVE" "$2"; exit; fi
    shift
done
exit 1
STUB
chmod +x "$work/bin/curl"
(
    export TSCODE_HOME="$work/remote user" ZDOTDIR="$work/remote user"
    export TSCODE_CONFIG_DIR="$TSCODE_HOME/.tscode"
    bash < "$repo/install.sh"
    test -x "$TSCODE_HOME/.local/bin/tscode"
    "$TSCODE_HOME/.local/bin/tscode" --help
)

for file in "$repo/install.sh" "$repo"/scripts/* "$repo"/tests/*.sh "$repo/config/bash-env" "$repo/config/packages.sh"; do
    bash -n "$file"
done
echo 'Shell regression checks passed.'
