# Your TS Code folder

Edit your settings here; installed application files live in `app/`.

| Path | Purpose |
| --- | --- |
| `config.conf` | Pane commands and the default browser website |
| `toolchains` | Saved language/toolchain selections |
| `.config-docker/` | Your files copied into the container home, such as `.tmux.conf` |
| `startup-docker.sh` | Optional trusted startup commands (run as root) |
| `startup.log` | Latest startup diagnostics; read with `tscode logs` |
| `config.conf.before-commands` | Backup from older settings migration, if present |
| `app/` | Managed scripts, templates, and Docker build files; refreshed by installation |

Use `tscodeconf --show` to see settings, `tscodeconf website https://example.com`
to choose the browser homepage, or `tscodeconf panes 'bash -i'` for a single shell.
Changes apply on the next workspace start; use `tscode-exit` inside the workspace
to close it first. Closing a pane removes it; closing the last pane ends the workspace.
