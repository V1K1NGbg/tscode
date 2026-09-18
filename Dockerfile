FROM ubuntu:26.04
LABEL org.tscode.storage="ubuntu26.04-v1"

# Application recipes are shipped as text; packages are installed into volumes at runtime.
COPY scripts/ /tscode/scripts/
COPY config/ /tscode/config/
RUN sed -i '/^root:/s|:/root:|:/home/tscode:|' /etc/passwd \
    && mkdir -p /home/tscode/project /packages /config \
    && cp /etc/skel/.bashrc /home/tscode/.bashrc \
    && cp /tscode/config/tmux.conf /home/tscode/.tmux.conf \
    && printf '\n. /tscode/config/bash-env\n' >> /home/tscode/.bashrc \
    && chmod +x /tscode/scripts/entrypoint.sh /tscode/scripts/prepare-packages.sh /tscode/scripts/tscode-install \
    && ln -s /tscode/scripts/tscode-install /usr/local/bin/tscode-install

ENV debug=0 website=https://lite.duckduckgo.com/lite/ editor=ranger browser=elinks top=htop \
    TSCODE_CONFIG_DIR=/config BASH_ENV=/tscode/config/bash-env \
    NVM_DIR=/packages/nvm CARGO_HOME=/packages/cargo RUSTUP_HOME=/packages/rustup \
    PATH=/packages/cargo/bin:$PATH LANG=C.UTF-8
WORKDIR /home/tscode/project
ENTRYPOINT ["/tscode/scripts/entrypoint.sh"]
