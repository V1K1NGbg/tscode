# TS Code

Alt+h/j/k/l: move left/down/up/right between panes.
Ctrl+a, then |: split side by side.
Ctrl+a, then _: split above/below.
Ctrl+a, then Ctrl+x: end the workspace (the container is removed).

Install languages: tscode-install python node java lua rust cpp
Install all languages: tscode-install all
Installed packages and your container home persist across launches.

Inside the shell: tscode-detach keeps the workspace running; tscode-exit closes it.
Keyboard detach: Ctrl+a, then d. Reattach from the host with: tscode resume
Outside the container: tscodeconf editor vim (takes effect next launch).
Update installed packages from the host: tscode update

Host diagnostics: tscode status; tscode logs
Show effective settings and saved selections: tscodeconf --show
Linux CLI sessions use your host UID/GID; sudo is available inside the container.
