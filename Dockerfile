FROM ubuntu:26.04 AS chawan
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl nim gcc make pkg-config libssl-dev libssh2-1-dev libbrotli-dev
WORKDIR /build
RUN curl --proto '=https' --tlsv1.2 -fsSL https://git.sr.ht/~bptato/chawan/archive/v0.4.4.tar.gz -o source.tar.gz \
    && echo 'e0a06e1504e10a51c6009751d79b798c98d8274e559fe195d4b4b7ddadf91bb8  source.tar.gz' | sha256sum -c - \
    && tar -xzf source.tar.gz --strip-components=1 \
    && make -j2 PREFIX=/opt/chawan \
    && make PREFIX=/opt/chawan install

FROM ubuntu:26.04
LABEL org.tscode.storage="ubuntu26.04-v1"

# Chawan is built for each architecture; its compiler stays in the build stage.
COPY --from=chawan /opt/chawan /opt/chawan
# Other application packages are installed into volumes at runtime.
COPY scripts/ /tscode/scripts/
COPY config/ /tscode/config/
RUN sed -i '/^root:/s|:/root:|:/home/tscode:|' /etc/passwd \
    && mkdir -p /home/tscode/project /packages /config \
    && cp /etc/skel/.bashrc /home/tscode/.bashrc \
    && cp /tscode/config/tmux.conf /home/tscode/.tmux.conf \
    && printf '\n. /tscode/config/bash-env\n' >> /home/tscode/.bashrc \
    && chmod +x /tscode/scripts/entrypoint.sh /tscode/scripts/prepare-packages.sh /tscode/scripts/tscode-install \
    && ln -s /tscode/scripts/tscode-install /usr/local/bin/tscode-install

ENV TSCODE_CONFIG_DIR=/config BASH_ENV=/tscode/config/bash-env \
    NVM_DIR=/packages/nvm CARGO_HOME=/packages/cargo RUSTUP_HOME=/packages/rustup \
    PATH=/opt/chawan/bin:/packages/cargo/bin:$PATH LANG=C.UTF-8
WORKDIR /home/tscode/project
ENTRYPOINT ["/tscode/scripts/entrypoint.sh"]
