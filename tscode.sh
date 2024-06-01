#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: tscode <folder>"
  exit 1
fi


echo "$1"
# docker run -it --hostname tscode --rm -v "$1":/root/data/ v1k1ngbg/ts-code:latest
