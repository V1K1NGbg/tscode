#!/bin/bash

echo "Pulling the latest image ..."

docker pull v1k1ngbg/tscode:latest

echo "Copying the files ..."

cp -ru .tscode ~

echo "Setting up the app ..."

chmod +x ~/.tscode/tscode.sh
chmod +x ~/.tscode/tscode_edit_conf.sh
chmod +x ~/.tscode/tscode_gen_conf.sh

echo "Setting up the alias ..."

if grep -q '^alias tscode' ~/.bashrc; then
    grep -v '^alias tscode' ~/.bashrc > temp
    mv temp ~/.bashrc
fi

echo $'alias tscode="~/.tscode/tscode.sh"' >> ~/.bashrc

if grep -q '^alias tscodeconf' ~/.bashrc; then
    grep -v '^alias tscodeconf' ~/.bashrc > temp
    mv temp ~/.bashrc
fi

echo $'alias tscodeconf="~/.tscode/tscode_edit_conf.sh"' >> ~/.bashrc

echo "Setting up the config file ..."

~/.tscode/tscode_gen_conf.sh

echo "Make sure to run 'source ~/.bashrc' or restart the terminal to apply the changes."