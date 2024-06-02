#!/bin/bash

if [ -z "$1" ]; then
  set -- "."
fi

~/.tscode/tscode_gen_conf.sh

docker run -it --hostname tscode --name tscode --rm \
  -v $(realpath "$1"):/root/data/ \
  -v $(realpath ~/.tscode):/root/.config/.tscode \
  --env $(grep "^debug=" ~/.tscode/config.conf) \
  --env $(grep "^website=" ~/.tscode/config.conf) \
  --env $(grep "^editor=" ~/.tscode/config.conf) \
  --env $(grep "^browser=" ~/.tscode/config.conf) \
  --env $(grep "^top=" ~/.tscode/config.conf) \
  v1k1ngbg/tscode:latest
