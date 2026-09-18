# TS Code

A terminal development workspace in Docker: a file manager, browser, and shell in tmux. Ubuntu 26.04, a persistent home, and packages installed once into Docker-managed storage.

## Install

Requires a running [Docker Engine 26.0 or newer](https://docs.docker.com/engine/release-notes/26.0/) (or a current Docker Desktop) and Bash. Persistent package storage uses Docker volume subpaths. Supports macOS and Linux with Bash or Zsh, including **64-bit Raspberry Pi OS** (ARM64). Windows and 32-bit Raspberry Pi OS are not supported.

From your local checkout, build and run the current code:

```bash
bash install.sh
"$HOME/.local/bin/tscode" .
```

The installer copies the local source to `~/.tscode`, builds `tscode:local`, and adds `~/.local/bin` to your Bash/Zsh PATH. Every launch runs a cached local build, so installed source changes are picked up automatically. Run `bash install.sh` again after changing your checkout to refresh that installed copy. No published TS Code image is downloaded by default.

Docker may download the Ubuntu 26.04 base image if it is missing. First-time package installation also needs network access. Once the base image and selected packages are cached, the workspace can reuse them locally. This is a local application build, not an air-gapped bootstrap.

Open a new terminal, then:

```bash
tscode                 # open the current directory
tscode ~/my-project    # open another directory
tscodeconf editor vim  # install/use Vim on the next launch
tscodeconf --show      # effective settings and saved toolchain selections
tscode status         # state, project, image, and startup-log location
tscode logs           # saved startup diagnostics, even after a failed launch
```

### Alternative: published images

To use your published Docker Hub image instead of building locally:

```bash
TSCODE_IMAGE=v1k1ngbg/tscode:latest bash install.sh
TSCODE_IMAGE=v1k1ngbg/tscode:latest "$HOME/.local/bin/tscode" .
```

Keep `TSCODE_IMAGE` set for subsequent launches (or export it in your shell profile). An explicit image is reused if present and pulled only if missing. Run `docker pull v1k1ngbg/tscode:latest` explicitly to update it. The published image must support the persistent-storage layout; publish the updated image before using this alternative with the new CLI.

If you do not have a checkout, this optional command downloads the source and builds it locally:

```bash
curl -fsSL https://raw.githubusercontent.com/V1K1NGbg/tscode/master/install.sh | bash
```

To review the installer first, download it to a file before running it. The installer does not install Docker or require host sudo.

### Docker only

The CLI prepares the volumes automatically. For direct Docker use:

```bash
docker build --pull=false -t tscode:local .
mkdir -p "$HOME/.tscode"
package_store="tscode-ubuntu26.04-v1-$(docker image inspect --format '{{.Architecture}}' tscode:local)-packages"
docker run --rm --name "$package_store-init" --env BASH_ENV=/dev/null \
  --mount "type=volume,source=$package_store,target=/packages" \
  --entrypoint /tscode/scripts/prepare-packages.sh tscode:local

docker run -dit --rm --hostname tscode --name tscode \
  --mount type=volume,source=tscode-home,target=/home/tscode \
  --mount "type=volume,source=$package_store,target=/packages" \
  --mount "type=volume,source=$package_store,target=/usr,volume-subpath=usr,volume-nocopy" \
  --mount "type=volume,source=$package_store,target=/etc,volume-subpath=etc,volume-nocopy" \
  --mount "type=volume,source=$package_store,target=/var,volume-subpath=var,volume-nocopy" \
  -v "$PWD:/home/tscode/project" -v "$HOME/.tscode:/config" \
  tscode:local
# Once startup finishes (follow it with docker logs -f tscode):
docker exec -it tscode tmux attach-session -t tscode
```

Add flags such as `-e editor=vim` before the image name, or `--env-file "$HOME/.tscode/config.conf"` to use CLI configuration. One workspace runs at a time under the name `tscode`.

## Persistent home and packages

| Container path | Storage | Contents |
| --- | --- | --- |
| `/home/tscode` | `tscode-home` Docker volume | Shell history, dotfiles, and other home files |
| `/home/tscode/project` | Your selected host directory | Project files |
| `/config` | Host `~/.tscode` | Settings, toolchain selections, custom startup |
| `/packages` | `tscode-ubuntu26.04-v1-<architecture>-packages` Docker volume | Installed system packages, nvm, Rust, and their state |

On Linux, CLI launches run interactive tools as your host UID/GID so newly created project files belong to you. Initialization, package installation, updates, and trusted custom startup hooks still run as root. Passwordless `sudo` is available inside the container; `tscode-install` elevates automatically. The workspace home remains `/home/tscode`.

macOS and direct Docker launches retain root sessions. Direct Docker users can opt in with both `-e TSCODE_UID=<uid>` and `-e TSCODE_GID=<gid>`. Use `docker exec <container> bash /tscode/scripts/workspace-user.sh <command>` to run a command as the workspace user (add `-it` for tmux attachment).

The first non-root launch migrates root-owned files in the persistent home and Node/Rust stores. It does not change existing project ownership or follow home symlinks into other locations. Existing root-owned project files require manual correction on the host. First-time non-root setup installs sudo and its required utilities, so it requires networking even if the older root workspace was cached. Docker removes the container on exit but keeps both named volumes.

On first launch, TS Code copies Ubuntu's base `/usr`, `/etc`, and `/var` directories into the package volume. It mounts these subdirectories back at their normal locations, keeping executables, libraries, configuration, and apt's database together. Node and Rust install directly under `/packages`. Subsequent launches reuse these files, including with networking disabled once the selected tools are installed.

TS Code scripts and recipes live separately at `/tscode`, so updating the image updates the application without hiding its new code behind the package volume. Package storage is separated by Ubuntu version, storage format, and CPU architecture; the home volume is retained across image updates.

## Tools and configuration

The image contains the Ubuntu base and TS Code scripts, with no application installation during the build. First startup installs tmux, Git, curl, less, the selected editor, and the selected browser. The defaults are **ranger** and **elinks**; **htop** is installed when debug mode first uses it. Required dependencies are included—for example, ranger needs Python, `file` for file-type detection, and Nano with `sensible-editor` to open text files.

| Setting | Default | Choices |
| --- | --- | --- |
| `editor` | `ranger` | `ranger`, `nano`, `vim` |
| `browser` | `elinks` | `elinks`, `links`, `lynx`, `carbonyl` |
| `top` | `htop` | `htop`, `top`, `vtop`, `gtop` |
| `debug` | `0` | `0`, `1` (adds monitor and help panes) |
| `website` | `https://lite.duckduckgo.com/lite/` | A nonempty, single-line URL |

```bash
tscodeconf browser lynx
tscodeconf website 'https://example.com/?a=1&b=2'
tscodeconf debug 1
```

Settings live in `~/.tscode/config.conf` as plain `key=value` lines, without shell quoting. Missing keys receive defaults. Invalid settings are reported instead of executed.

Only missing selected tools are installed. An optional monitor is installed only with `debug=1`. npm-based tools install Node LTS through nvm as a dependency. If an optional tool fails, TS Code tries the default for that session without changing your saved choice. First-time installation requires networking; an already installed fallback works offline. Carbonyl continues to run with `--no-sandbox` for compatibility with the container environment.

Google Search may show an “update your browser” page in ELinks ([Google’s browser requirements](https://support.google.com/websearch/answer/16515119?hl=en)). The default is DuckDuckGo Lite, which works in the text browser. Existing website settings are preserved; switch with:

```bash
tscodeconf website https://lite.duckduckgo.com/lite/
```

### Language toolchains

Inside the workspace:

```bash
tscode-install python node     # Python + pip/venv; Node LTS + npm via nvm
tscode-install java lua        # Java 25 LTS; Lua 5.4
tscode-install rust cpp        # Rust stable; GCC/G++, make, gdb, cmake
tscode-install all             # all six toolchains
```

### Package definitions and LTS policy

[`config/packages.sh`](config/packages.sh) is the package recipe file. Each entry contains its actual installation commands, including system dependencies. Change recipes there and rebuild the small image; application packages are installed at runtime, not during the build.

- **Node:** `nvm install --lts` on first installation, then reuse the installed LTS version. It is no longer pinned to Node 22.
- **Java:** Ubuntu's OpenJDK 25 LTS package.
- **Python, Lua, C/C++, editors, browsers, monitors:** Ubuntu 26.04 LTS packages, or upstream stable npm packages where required.
- **Rust:** the upstream stable channel. Rust and several other tools do not offer a separate LTS channel; they are not mislabeled as LTS.

Successful explicit toolchain selections are saved in `~/.tscode/toolchains`, one name per line. Startup checks these selections and installs only missing components. Removing a name stops the startup check but does not uninstall an already persisted toolchain. Installations made manually with apt, npm, nvm, or rustup also survive when they use the normal paths described above.

For Python dependencies, use a virtual environment: `python3 -m venv .venv`.

### Custom startup

- Put files under `~/.tscode/.config-docker/` to overlay them onto `/home/tscode` (for example `.tmux.conf` or `.vimrc`).
- Put trusted shell commands in `~/.tscode/startup-docker.sh`; it is sourced as root after tool installation, before opening the workspace.
- If supplying your own `.bashrc`, source `/tscode/config/bash-env` to enable nvm and interactive toolchain environment refresh.

These files are preserved by installer updates. The installer validates TS Code marker pairs in every targeted shell profile before editing any profile; malformed markers must be corrected manually. Existing installations keep their tool choices, including `vtop`; set `top=htop` to use the default monitor.

## Navigation

- **Alt+h/j/k/l:** move between panes.
- **Ctrl+a, then | or _:** split side by side or above/below.
- **Ctrl+a, then Ctrl+x:** close the workspace and remove its container.
- **Ctrl+a, then d:** detach; reattach from the host with `tscode resume`.
- Inside the shell, **`tscode-detach`** detaches and keeps the workspace running.
- Inside the shell, **`tscode-exit`** closes the whole workspace and removes the container. Home files and packages remain in their volumes; plain `exit` only closes the shell pane.

## Update or uninstall

Update by running the installer again. It refreshes managed source files and rebuilds the local image, preserving your settings, home, and installed packages. Restart the workspace to use the new image.

Update installed packages from the host:

```bash
tscode update
```

This upgrades Ubuntu packages, installed Node to the latest LTS (carrying over global npm packages and updating them), and installed Rust to stable. It does not install unselected toolchains. It uses the running workspace when available, or a temporary container with the same persistent volumes otherwise. Network access is required; failures stop the update and can be retried. Restart the workspace afterward so every pane uses updated tools. Project dependencies and Python virtual environments are managed by their projects.

Use `tscode resume` after detaching with `tscode-detach` or **Ctrl+a, d**. This attaches a tmux client with `docker exec`; the container must still be running. `docker attach tscode` now shows container output, not the workspace. Launching `tscode` again for the same canonical project path reattaches without rebuilding. If another project is running, the CLI reports its path; use `tscode resume`, then `tscode-exit` inside that workspace before switching. Unrelated or stopped containers named `tscode` are never removed automatically.

`tscode status` reports `starting`, `ready`, `stopped`, or `not running`, plus the project, image, and log path. Readiness means all requested tmux panes have been created and the session exists. `tscode logs` prints `~/.tscode/startup.log` without requiring Docker. The log captures initialization and custom-hook output, survives container removal, and is replaced at the next fresh launch; it does not capture interactive pane output. The CLI streams startup diagnostics until readiness. Interrupting that wait leaves the container running.

`tscodeconf --show` displays defaults for missing settings without changing configuration, and lists saved toolchain selections rather than claiming they are currently installed. Invalid or duplicate settings remain errors.

For directories named `resume`, `update`, `status`, or `logs`, use an explicit relative path such as `tscode ./status`.

Rebuilding locally or explicitly pulling an alternative image updates TS Code's scripts; it does not overwrite packages already in the volume.

To uninstall, remove `~/.local/bin/tscode` and `~/.local/bin/tscodeconf`, then remove the marked `TS Code` PATH block from `.bashrc`, your Bash login profile (`.bash_profile`, `.bash_login`, or `.profile`), and `.zshrc` (or `$ZDOTDIR/.zshrc`). Keep `~/.tscode` to retain configuration, or delete it too. Optionally remove the image with `docker image rm tscode:local`. Docker volumes remain until explicitly removed: inspect them with `docker volume ls --filter name=tscode`. Removing `tscode-home` deletes container-home files; removing a package volume deletes its installed tools. Neither action is part of the installer.

## Development

- `install.sh`: host installation and remote bootstrap.
- `scripts/`: host CLI, configuration, persistent storage setup, container startup, and installation helpers.
- `config/`: package recipes, tmux configuration, shell environment, and help.
- `tests/`: shell regression tests and Docker smoke tests.

```bash
bash tests/check.sh
shellcheck -x -P SCRIPTDIR --shell=bash -e SC1090,SC1091 install.sh scripts/* config/bash-env config/packages.sh tests/*.sh
docker build -t tscode:test .
bash tests/smoke.sh tscode:test linux/arm64  # use linux/amd64 on x86-64
TSCODE_IMAGE=tscode:test bash install.sh
TSCODE_IMAGE=tscode:test tscode
```

`TSCODE_IMAGE` skips local builds and selects a prebuilt image; both installer and launcher reuse it if present, pulling it only when missing. Pull it explicitly to update it. `TSCODE_REF` chooses the source archive ref for remote installation. `TSCODE_HOME` relocates the host installation (default: `$HOME`); retain that variable when invoking the CLI. Tests use a temporary location and stub Docker, so shell regression checks do not modify your real installation.

### Release

GitHub Actions runs shell checks on Linux/macOS and image smoke tests on native AMD64/ARM64 runners, including a fresh offline container reusing every installed toolchain and its home. Set repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`, then manually run **Check and publish** on `master` with **publish** enabled. Publishing waits for successful checks and uploads a multiarchitecture `latest` tag plus a commit-SHA tag.

This storage layout replaces the old `/root/data` and `/root/.config/.tscode` paths. Update custom startup scripts that reference those paths. Existing host settings and toolchain selections are reused; the package volume is populated once on first launch.

Local builds need no image publication. To distribute the optional prebuilt alternative, publish a matching Docker image. Local edits alone do not update GitHub or Docker Hub. For a manual image release:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t v1k1ngbg/tscode:latest --push .
```
