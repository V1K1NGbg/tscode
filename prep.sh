#!/bin/bash

apt-get update -y 
apt-get full-upgrade -y 
apt-get install -y git make curl vim ranger tmux libnss3 libasound2 xdg-utils neofetch
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash 
source /root/.bashrc
nvm install node 
npm install -g vtop 
npm install -g carbonyl


mkdir /data
LANG=en_US.utf8
export LANG





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

