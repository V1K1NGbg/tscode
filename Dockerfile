
FROM ubuntu:latest

SHELL ["/bin/bash", "--login", "-i", "-c"]

RUN apt-get update -y --fix-missing && \
    apt-get full-upgrade -y

RUN apt-get install -y make libnss3 libasound2 xdg-utils openssh-server git curl nano vim ranger tmux neofetch lynx links elinks htop

RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended

RUN apt-get install -y openjdk-21-jdk

RUN apt-get install -y lua5.4

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN apt-get install -y build-essential gdb cmake

RUN apt-get install -y python3 python3-pip

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash && \
    . /root/.bashrc

RUN nvm install node

RUN npm install -g vtop
RUN npm install -g gtop
RUN npm install -g carbonyl

RUN mkdir /root/data && \
    mkdir /root/.config && \
    mkdir /root/.config/ranger && \
    echo 'export LANG=en_US.UTF-8' >> ~/.bashrc && \
    . /root/.bashrc && \
    cd /root/data

VOLUME [ "/root/data" ]
WORKDIR /root/data

ENV more_stats=0
ENV email=email@example.com
ENV website=https://google.com
# nano, vim, ranger
ENV editor=ranger
# carbonyl --no-sandbox, links, lynx, elinks
ENV browser="elinks"
# vtop, htop, gtop, top
ENV top=vtop


CMD if [ -d /root/data/.config-docker ]; then echo "Copying files from .config-docker" && /bin/cp -rf /root/data/.config-docker/. /root ; else echo "No files to copy from .config-docker" ; fi && \
    if [ -f /root/data/startup-docker.sh ]; then echo "Running startup-docker.sh" && chmod +x /root/data/startup-docker.sh && . /root/data/startup-docker.sh ; else echo "No startup-docker.sh to run" ; fi && \
    if [ ! -f /root/.ssh/id_rsa ] ; then ssh-keygen -t ed25519 -C "${email}" -f /root/.ssh/id_rsa && /bin/cp -rf /root/.ssh/id_rsa.pub /root/data/.ssh-key/ ; fi && \
    if [ ${more_stats} -eq 0 ] ; then \
    (tmux new-session ${editor} \; split-window -h '${browser} ${website}' \; split-window -v \; select-pane -t 0) ; \
    else \
    (tmux new-session ${editor} \; split-window -h '${browser} ${website}' \; split-window -v \; split-window -h ${top} \; split-window -v -d 'neofetch && sh' \; select-pane -t 0) ; \
    fi

EXPOSE 22