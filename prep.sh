#!/bin/bash

apt-get update -y 
apt-get full-upgrade -y 
apt-get install -y make libnss3 libasound2 xdg-utils git curl nano vim ranger tmux neofetch 
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended 
#node
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash 
source /root/.bashrc 
#java
apt-get install -y openjdk-21-jdk 
#lua
apt-get install -y lua5.4 
#rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 
#c/c++
apt-get install -y build-essential gdb cmake 
#python
apt-get install -y python3 python3-pip 
#docker
# apt-get install -y ca-certificates
# install -m 0755 -d /etc/apt/keyrings 
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 
# chmod a+r /etc/apt/keyrings/docker.asc 
# echo \
# "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
# $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
# tee /etc/apt/sources.list.d/docker.list > /dev/null 
# apt-get update -y 
# apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 
nvm install node 
npm install -g vtop 
npm install -g carbonyl 
mkdir /data 
LANG=en_US.utf8 
export LANG
