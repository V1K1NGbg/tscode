#!/bin/bash
# Run on the host: bash tests/smoke.sh tscode:test [linux/arm64|linux/amd64]
set -euo pipefail
image=${1:-tscode:test}
platform=${2:-linux/arm64}
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
work=$(mktemp -d)
# Match the CLI: retain host ownership so native Linux can read failure diagnostics.
(umask 077; : > "$work/startup.log")
container=''
cleanup() {
    if [ -n "$container" ]; then docker rm -f "$container" >/dev/null 2>&1 || true; fi
    if [ -n "${package_volume:-}" ]; then
        docker rm -f "$package_volume-init" >/dev/null 2>&1 || true
        docker volume rm "$package_volume" >/dev/null 2>&1 || true
    fi
    if [ -n "${home_volume:-}" ]; then docker volume rm "$home_volume" >/dev/null 2>&1 || true; fi
    for volume in "${user_config_volume:-}" "${project_volume:-}"; do
        [ -z "$volume" ] || docker volume rm "$volume" >/dev/null 2>&1 || true
    done
    rm -rf "$work"
}
trap cleanup EXIT

# The image contains recipes, not application packages.
docker run --rm --platform "$platform" --entrypoint bash "$image" -ec '
    test "$HOME" = /home/tscode
    for tool in ranger opencode carbonyl tmux git node npm javac rustc gcc; do
        if type -P "$tool"; then echo "Unexpected bundled tool: $tool"; exit 1; fi
    done
'
. "$repo/scripts/storage.sh"
prefix="tscode-test-$$-$(date +%s)"
prepare_storage "$image" "$prefix"
mounts=("${storage_mounts[@]}" -v "$work:/config" -v "$repo/tests:/tests:ro")

docker run --rm --platform "$platform" "${mounts[@]}" "$image" bash -ec '
    for tool in ranger file nano sensible-editor opencode carbonyl tmux git node npm; do type -P "$tool"; done
    for tool in javac rustc gcc; do
        if type -P "$tool"; then echo "Unexpected optional tool: $tool"; exit 1; fi
    done
    printf "ranger opens text\n" > /tmp/"ranger test.txt"
    test "$(env -u VISUAL EDITOR=cat rifle -p editor /tmp/"ranger test.txt")" = "ranger opens text"
    rm /tmp/"ranger test.txt"
    printf "home survives\n" > "$HOME/.persistence-check"
'

# Real startup with the default commands and an arbitrary command layout.
docker run --rm --platform "$platform" "${mounts[@]}" "$image" bash /tests/layout.sh /tscode
for panes in 'ranger;0:right:67:opencode;1:right:50:carbonyl;1:bottom:50:shell' 'shell;0:right:50:printf "%s" "https://example.com/a:b" > /config/command-output && shell'; do
    container=$(docker run -dit --rm --platform "$platform" "${mounts[@]}" -e "panes=$panes" "$image")
    ready=0
    for ((attempt=0; attempt<60; attempt++)); do
        if docker exec "$container" test -f /run/tscode.ready; then ready=1; break; fi
        sleep 1
    done
    if [ "$ready" != 1 ]; then docker logs "$container"; exit 1; fi
    expected=4
    case "$panes" in shell*) expected=2 ;; esac
    [ "$(docker exec "$container" tmux list-panes -t tscode:0 | wc -l | tr -d ' ')" = "$expected" ]
    if [ "$expected" = 2 ]; then
        for ((attempt=0; attempt<50; attempt++)); do
            [ ! -s "$work/command-output" ] || break
            sleep 0.1
        done
        [ "$(cat "$work/command-output")" = 'https://example.com/a:b' ]
    fi
    docker exec "$container" bash -c tscode-exit
    for ((attempt=0; attempt<60; attempt++)); do
        if ! docker inspect "$container" >/dev/null 2>&1; then break; fi
        sleep 1
    done
    if docker inspect "$container" >/dev/null 2>&1; then
        docker inspect --format '{{json .State}}' "$container" || true
        docker top "$container" -eo pid,ppid,args || true
        docker logs "$container" || true
        echo 'tscode-exit did not remove the workspace container' >&2
        exit 1
    fi
    container=''
done
: > "$work/startup-docker.sh"

docker run --rm --platform "$platform" "${mounts[@]}" "$image" bash /tests/toolchains.sh
# Preparation must never overwrite an initialized store.
prepare_storage "$image" "$prefix"

# A failed hook leaves diagnostics after --rm removes its container.
printf 'echo deliberate-startup-failure; false\n' > "$work/startup-docker.sh"
if docker run --rm --platform "$platform" "${mounts[@]}" "$image" true; then
    echo 'Expected startup failure' >&2; exit 1
fi
grep -q deliberate-startup-failure "$work/startup.log"
grep -q 'Startup failed' "$work/startup.log"
: > "$work/startup-docker.sh"

# Migrate an existing root home/toolchain store without changing project or symlink targets.
mkdir "$work/project"
workspace_uid=$(id -u)
workspace_gid=$(id -g)
if [ "$workspace_uid" = 0 ]; then workspace_uid=12345; workspace_gid=12345; fi
mounts+=(-v "$work/project:/home/tscode/project")
# Docker Desktop maps host ownership differently; use Linux volumes for this check.
# Native Linux CI keeps the real host bind mounts and verifies the actual host IDs.
if [ "$(uname -s)" != Linux ]; then
    user_config_volume="$prefix-user-config"
    project_volume="$prefix-project"
    mounts=("${storage_mounts[@]}" -v "$repo/tests:/tests:ro"
        --mount "type=volume,source=$user_config_volume,target=/config"
        --mount "type=volume,source=$project_volume,target=/home/tscode/project,volume-nocopy")
    docker run --rm "${mounts[@]}" -v "$work:/host-config:ro" --entrypoint bash "$image" -ec '
        cp -a /host-config/. /config/
        chown -R "$1:$2" /config
        chown "$1:$2" /home/tscode/project
    ' bash "$workspace_uid" "$workspace_gid"
elif [ "$(id -u)" = 0 ]; then
    docker run --rm "${mounts[@]}" --entrypoint chown "$image" -R "$workspace_uid:$workspace_gid" /config
    docker run --rm "${mounts[@]}" --entrypoint chown "$image" "$workspace_uid:$workspace_gid" /home/tscode/project
fi
docker run --rm --platform "$platform" "${mounts[@]}" --entrypoint bash "$image" -ec '
    touch /home/tscode/root-owned /packages/outside-root /home/tscode/project/existing
    ln -s /packages/outside-root /home/tscode/outside-link
    stat -c %u:%g /home/tscode/project/existing > /config/project-owner
'
identity=(-e "TSCODE_UID=$workspace_uid" -e "TSCODE_GID=$workspace_gid")
container=$(docker run -dit --rm --platform "$platform" "${identity[@]}" "${mounts[@]}" "$image")
ready=0
for ((attempt=0; attempt<120; attempt++)); do
    if docker exec "$container" test -f /run/tscode.ready; then ready=1; break; fi
    sleep 1
done
if [ "$ready" != 1 ]; then docker logs "$container"; exit 1; fi
docker exec "$container" bash /tscode/scripts/workspace-user.sh tmux send-keys -t tscode:0.2 \
    'id -u > /home/tscode/project/interactive-owner; touch /home/tscode/project/interactive-file' Enter
for ((attempt=0; attempt<60; attempt++)); do
    if docker exec "$container" test -f /home/tscode/project/interactive-file; then break; fi
    sleep 1
done
docker exec "$container" grep -qx "$workspace_uid" /home/tscode/project/interactive-owner
docker exec "$container" bash /tscode/scripts/workspace-user.sh bash -ec '
    test "$(stat -c %u:%g /home/tscode/project/interactive-file)" = "$TSCODE_UID:$TSCODE_GID"
    test "$(stat -c %u /home/tscode/root-owned)" = "$TSCODE_UID"
    test "$(stat -c %u /packages/outside-root)" = 0
    test "$(stat -c %u:%g /home/tscode/project/existing)" = "$(cat /config/project-owner)"
    test "$(sudo -n id -u)" = 0
    test "$HOME" = /home/tscode
    tscode-install all
    test -w /packages/nvm/nvm.sh
    test -w /packages/cargo
    test -w /packages/rustup
    node --version
    rustc --version
'
docker exec "$container" bash /tscode/scripts/workspace-user.sh bash -c tscode-exit
for ((attempt=0; attempt<60; attempt++)); do
    if ! docker inspect "$container" >/dev/null 2>&1; then break; fi
    sleep 1
done
if docker inspect "$container" >/dev/null 2>&1; then exit 1; fi
container=''
docker run --rm "${mounts[@]}" --entrypoint bash "$image" -ec '
    printf '\''node -e "if (!process.release.lts) process.exit(1)"\n'\'' > /config/startup-docker.sh
'

# A fresh, network-disabled container must reuse every installed package and the home.
docker run --rm --network none --platform "$platform" "${identity[@]}" "${mounts[@]}" "$image" bash -ec '
    grep -qx "home survives" "$HOME/.persistence-check"
    before=$(sha256sum /var/log/apt/history.log)
    bash /tests/toolchains.sh
    test "$before" = "$(sha256sum /var/log/apt/history.log)"
    test /usr -ef /packages/usr
    test /etc -ef /packages/etc
    test /var -ef /packages/var
'
echo "Persistent storage smoke checks passed: $platform"
