tmux new-session vim \; split-window -h ranger \; split-window -v 'carbonyl https://google.com/' \; select-pane -t 1 \; split-window -h \; split-window -h gtop
tmux new-session \; split-window -h \; split-window -v \; split-window -h \; split-window -h