#!/bin/bash

echo "Pulling the latest image ..."

docker pull v1k1ngbg/tscode:latest

echo "Copying the files ..."

cp -ru .tscode ~

echo "Setting up the app ..."

chmod +x ~/.tscode/tscode.sh

echo "Setting up the alias ..."

if grep -q '^alias tscode' ~/.bashrc; then
    grep -v '^alias tscode' ~/.bashrc > temp
    mv temp ~/.bashrc
fi

echo $'\nalias tscode="~/.tscode/tscode.sh"' >> ~/.bashrc

source ~/.bashrc