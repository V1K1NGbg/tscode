#!/bin/bash

# echo "Pulling the latest image ..."

# docker pull v1k1ngbg/tscode:latest

mkdir -p ~/.tscode

cp tscode.sh ~/.tscode/tscode.sh

chmod +x ~/.tscode/tscode.sh

if ! grep -Fxq 'alias tscode="~/.tscode/tscode.sh' "~/.bashrc"; then
    echo 'alias tscode="~/.tscode/tscode.sh"' >> ~/.bashrc
fi

source ~/.bashrc