if test "$(tty)" = /dev/tty1 && test -z "${WAYLAND_DISPLAY:-}"; then
    WLR_RENDERER_ALLOW_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 XCURSOR_THEME=capitaine-cursors \
        /usr/bin/systemd-cat --identifier=pond-installer-session /usr/bin/cage -s -m last -- sudo /usr/local/bin/pond-installer
    status=$?
    # Not exec'd: if cage dies, say why on screen and keep this shell, instead
    # of getty respawning into a blank console.
    echo "Pond Installer: the graphical session exited with status $status."
    journalctl -b --no-pager -o short-monotonic -n 30 -t pond-installer-session
    journalctl -b --no-pager -o short-monotonic -k -p warning -n 15
fi
