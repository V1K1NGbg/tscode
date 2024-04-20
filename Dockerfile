
FROM ubuntu:latest

RUN apt-get update -y && \
    apt-get full-upgrade -y && \
    apt-get install -y tmux git make vim ca-certificates curl && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update -y && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    mkdir /data && \
    mkdir /source_code && \
    cd /source_code && \
    git clone https://github.com/hut/ranger.git && \
    cd ranger && \
    make install && \
    cd .. && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash && \
    source ~/.bashrc && \
    nvm install node && \
    npm install vtop -g && \


    VOLUME [ "/data" ]
WORKDIR /data