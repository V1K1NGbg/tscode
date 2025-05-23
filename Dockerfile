
FROM ubuntu:latest

SHELL ["/bin/bash", "--login", "-i", "-c"]

RUN apt-get update -y --fix-missing && \
    apt-get full-upgrade -y

RUN apt-get install -y make libnss3 xdg-utils git curl nano vim ranger tmux neofetch lynx links elinks htop
# RUN apt-get install -y make libnss3 libasound2 (not found) xdg-utils openssh-server (for ssh) git curl nano vim ranger tmux neofetch lynx links elinks htop


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
    mkdir /root/.config/.tscode && \
    echo 'export LANG=en_US.UTF-8' >> /root/.bashrc && \
    . /root/.bashrc && \
    cd /root/data

VOLUME [ "/root/data", "/root/.config/.tscode" ]
WORKDIR /root/data

ENV debug=0
ENV website=https://google.com
# nano, vim, ranger
ENV editor=ranger
# carbonyl, links, lynx, elinks
ENV browser="elinks"
# vtop, htop, gtop, top
ENV top=vtop


CMD if [ "$browser" == "carbonyl" ]; then export browser="carbonyl --no-sandbox"; fi && \
    if [ -d /root/.config/.tscode/.config-docker ]; then echo "Copying files from .config-docker" && /bin/cp -rf /root/.config/.tscode/.config-docker/. /root ; else echo "No files to copy from .config-docker" ; fi && \
    if [ -f /root/.config/.tscode/startup-docker.sh ]; then echo "Running startup-docker.sh" && chmod +x /root/.config/.tscode/startup-docker.sh && . /root/.config/.tscode/startup-docker.sh ; else echo "No startup-docker.sh to run" ; fi && \
    # if [ ! -f /root/.ssh/id_rsa ] ; then ssh-keygen -t ed25519 -C "${email}" -f /root/.ssh/id_rsa && /bin/cp -rf /root/.ssh/id_rsa.pub /root/data/.ssh-key/ ; fi && \
    if [ ${debug} -eq 0 ] ; then \
    (tmux new-session ${editor} \; split-window -h '${browser} ${website}' \; split-window -v 'su' \; select-pane -t 0) ; \
    else \
    (tmux new-session ${editor} \; split-window -h '${browser} ${website}' \; split-window -v 'su' \; split-window -h ${top} \; split-window -v -d 'neofetch | less' \; split-window -h 'less /root/.config/.tscode/README.md' \; select-pane -t 0) ; \
    fi

# EXPOSE 22