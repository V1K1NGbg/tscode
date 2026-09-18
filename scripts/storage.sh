#!/bin/bash

# Build the installed source by default; an image override opts into prebuilt images.
prepare_image() {
    local context=$1
    image=${TSCODE_IMAGE:-tscode:local}
    if [ -n "${TSCODE_IMAGE:-}" ]; then
        docker image inspect "$image" >/dev/null 2>&1 || docker pull "$image"
    else
        docker build --pull=false -t "$image" "$context"
    fi
}

# The optional prefix lets smoke tests use isolated volumes.
prepare_storage() {
    local image=$1 prefix=${2:-tscode} key directory
    key=$(docker image inspect --format '{{index .Config.Labels "org.tscode.storage"}}-{{.Architecture}}' "$image") || return
    if [ -z "$key" ] || [[ "$key" == -* ]]; then
        echo 'This image does not support persistent packages. Rebuild or pull the updated TS Code image.' >&2
        return 1
    fi
    package_volume="$prefix-$key-packages"
    home_volume="$prefix-home"
    docker run --rm --name "$package_volume-init" \
        --env BASH_ENV=/dev/null \
        --mount "type=volume,source=$package_volume,target=/packages" \
        --entrypoint /tscode/scripts/prepare-packages.sh "$image" || return

    storage_mounts=(
        --mount "type=volume,source=$home_volume,target=/home/tscode"
        --mount "type=volume,source=$package_volume,target=/packages"
    )
    # Ubuntu's /bin, /sbin and /lib already link into /usr.
    for directory in usr etc var; do
        storage_mounts+=(--mount "type=volume,source=$package_volume,target=/$directory,volume-subpath=$directory,volume-nocopy")
    done
}
