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
tscodeconf panes shell # open only a shell on the next launch
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

Add flags such as `-e panes=shell` before the image name, or `--env-file "$HOME/.tscode/config.conf"` to use CLI configuration. One workspace runs at a time under the name `tscode`.

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

The image contains Ubuntu and TS Code scripts. First startup installs a fixed workspace toolset: tmux, Git, curl, less, ranger (with its dependencies), OpenCode, and Carbonyl. Node LTS supplies npm for OpenCode and Carbonyl. Packages persist and are installed only when missing. Other commands must already be installed, for example through your startup hook or `sudo apt-get install` in the workspace.

The only workspace setting is `panes`. Its default is:

```ini
panes=ranger;0:right:67:opencode;1:right:50:carbonyl;1:bottom:50:shell
```

```text
┌─────────────┬─────────────┬─────────────┐
│             │ opencode    │             │
│ ranger      ├─────────────┤ carbonyl    │
│             │ shell       │             │
└─────────────┴─────────────┴─────────────┘
```

Settings live in `~/.tscode/config.conf` as plain `key=value` lines. Do not quote the whole value in the file. To change it from your terminal:

```bash
tscodeconf panes 'ranger;0:right:67:opencode;1:right:50:carbonyl;1:bottom:50:shell'
tscodeconf panes 'shell;0:right:50:carbonyl https://example.com'
tscodeconf --show
```

The first command fills the window. Each subsequent `target:direction:percent:command` splits an earlier pane:

- `target` is its zero-based declaration number, even if tmux later renumbers visible panes.
- `direction` is `left`, `right`, `top`, or `bottom`, locating the new pane relative to the target.
- `percent` is the new pane's share of the target's current width or height (`1`–`99`). The default leaves approximately one third for ranger, then divides the remainder into two columns; cell rounding and borders affect exact sizes.
- `command` is a Bash command, including arguments, quotes, environment variables, pipes, or redirection. Colons within commands and URLs are preserved. Semicolons always separate panes, including inside quotes; put commands needing semicolons in a script and use its path instead.

Commands run inside the container as the workspace user. Config is executable, trusted input: command substitution and other shell expressions execute when the pane opens, never when saving or displaying settings. `shell` opens interactive Bash. The Bash environment wraps `carbonyl` with `--no-sandbox` for container compatibility. There are no app aliases, automatic debug panes, app detection, or fallback applications. OpenCode is installed using its [official npm package](https://github.com/anomalyco/opencode#installation); configure its provider credentials inside the workspace.

Changes take effect on a fresh workspace launch; `tscode resume` keeps existing panes. The initial window is 160×48 cells and adapts to your terminal when attached. Splits too small to fit fail with details in `tscode logs`; command errors appear in the pane while it remains open.

On upgrade, the installer or next launch removes old app, debug, website, and preset/size settings, keeping a backup at `~/.tscode/config.conf.before-commands`. Missing `panes` or the old `panes=default` receives the new default. Existing custom pane strings are preserved; replace former `editor`, `browser`, `debug`, and `help` aliases with actual commands.

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
- **Python, Lua, C/C++, ranger:** Ubuntu 26.04 LTS packages.
- **OpenCode and Carbonyl:** upstream npm packages.
- **Rust:** the upstream stable channel. Rust and several other tools do not offer a separate LTS channel; they are not mislabeled as LTS.

Successful explicit toolchain selections are saved in `~/.tscode/toolchains`, one name per line. Startup checks these selections and installs only missing components. Removing a name stops the startup check but does not uninstall an already persisted toolchain. Installations made manually with apt, npm, nvm, or rustup also survive when they use the normal paths described above.

For Python dependencies, use a virtual environment: `python3 -m venv .venv`.

### Custom startup

- Put files under `~/.tscode/.config-docker/` to overlay them onto `/home/tscode` (for example `.tmux.conf` or `.vimrc`).
- Put trusted shell commands in `~/.tscode/startup-docker.sh`; it is sourced as root after tool installation, before opening the workspace.
- If supplying your own `.bashrc`, source `/tscode/config/bash-env` to enable nvm and interactive toolchain environment refresh.

These files are preserved by installer updates. The installer validates TS Code marker pairs in every targeted shell profile before editing any profile; malformed markers must be corrected manually. Existing custom pane commands are preserved.

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
bash tests/layout.sh # requires tmux
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
