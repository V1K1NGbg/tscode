#!/bin/bash
set -euo pipefail

# Seed the Ubuntu system files once. No application packages are installed here.
[ ! -f /packages/.ready ] || exit 0
printf 'Preparing persistent package storage...\n'
for directory in usr etc var; do
    mkdir -p "/packages/$directory"
    cp -a "/$directory/." "/packages/$directory/"
done
# An interrupted copy is retried next time; only a complete store gets this marker.
touch /packages/.ready
