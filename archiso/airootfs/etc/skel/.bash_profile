if test "$(tty)" = /dev/tty1 && test -z "${WAYLAND_DISPLAY:-}"; then
    /usr/bin/systemd-cat --identifier=pond-session /usr/bin/niri --session
    status=$?
    # Not exec'd: if niri dies, say why on screen and keep this shell, instead
    # of getty respawning into a blank console.
    echo "Pond: the graphical session exited with status $status."
    journalctl -b --no-pager -o short-monotonic -n 30 -t pond-session
    journalctl -b --no-pager -o short-monotonic -k -p warning -n 15
fi
