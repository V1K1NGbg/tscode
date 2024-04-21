
FROM ubuntu:latest

ENV debug=0
ENV website=https://google.com
# nano, vim, ranger
ENV editor=ranger
# carbonyl, links, lynx
ENV browser=carbonyl
# vtop, htop, gtop, top
ENV top=vtop

RUN apt-get update -y && \
    apt-get full-upgrade -y && \
    apt-get install -y make libnss3 libasound2 xdg-utils openssh-server git curl nano vim ranger tmux neofetch lynx links htop && \
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash && \
    source /root/.bashrc && \
    apt-get install -y openjdk-21-jdk && \
    apt-get install -y lua5.4 && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    apt-get install -y build-essential gdb cmake && \
    apt-get install -y python3 python3-pip && \
    nvm install node && \
    npm install -g vtop && \
    npm install -g gtop && \
    npm install -g carbonyl && \
    mkdir /data && \
    LANG=en_US.utf8 && \
    export LANG

VOLUME [ "/data" ]
WORKDIR /data

CMD [[ ${debug} -eq 0 ]] && tmux new-session ${editor} \; split-window -h '${browser} ${website}' \; split-window -v \; select-pane -t 0 || tmux new-session ${editor} \; split-window -h '${browser} ${website}' \; split-window -v \; split-window -h ${top} \; split-window -v neofetch \; select-pane -t 0

EXPOSE 22