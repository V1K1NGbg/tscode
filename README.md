# TS Code

Terminal Studio Code

## Description

Ubuntu-based image with a set of pre-installed tools and configurations tailored for development container development. The image includes essential utilities, programming languages, and configuration settings for enhanced productivity.

## Features

- Ubuntu environment
- Installation of essential packages such as `make`, `git`, `curl`, `vim`, and more
- Oh My Bash for a customized shell experience
- Preinstalled languages: 
    - Java (`21`)
    - Lua (`5`)
    - Rust
    - C/C++ (`gcc`, `gdb`, and `cmake`)
    - Python (`3` with `pip`)
    - Node.js (`22`, with `nvm`, `npm`)
- Monitoring tools:
    - `vtop`
    - `gtop`
    - `htop`
    - `top`
- Runtime environment variables:
    - debug (debug for some stats and a tutorial on how to use the app, default:`0`)
    - website (the startup website, default:`https://google.com`)
    - editor (the startup editor, default:`ranger`, options:`nano`, `vim`, `ranger`)
    - browser (the startup browser, default:`elinks`, options:`carbonyl`, `links`, `lynx`, `elinks`)
    - top (the startup top (only in debug mode), default:`vtop`, options:`vtop`, `htop`, `gtop`, `top`)
- If a `.config-docker` directory exists in `.tscode`, its contents will be copied to the container during container startup.
- If a `startup-docker.sh` script is provided in `.tscode`, it will be executed during container startup.

## Set Up

### Prerequisites

- Docker

### Installation (CLI)

- Run the setup script: `./setup_tscode.sh`

## Usage

### Usage with CLI (Recommended)

`tscode <file>` - Run tscode with a specific directory
`tscodeconf <variable> <value>` - Change runtime environment variables

### Usage with Docker Command

`docker run -it --hostname tscode --name tscode --rm -v {a folder to open}:/root/data/ -v ~/.tscode:/root/.config/.tscode v1k1ngbg/tscode:latest`

## Configuration Files

### ! In your home directory !

```
.tscode
├── .config-docker
│   ├── .bashrc
│   ├── .config
│   │   └── ranger
│   │       ├── rc.conf
│   │       ├── rifle.conf
│   │       └── scope.sh
│   ├── .tmux.conf
│   └── .vimrc
├── config.conf
├── README.md
├── startup-docker.sh
├── tscode.sh
├── tscode_edit_conf.sh
└── tscode_gen_conf.sh
```
