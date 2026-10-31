#!/bin/bash
# =============================================================================
# galaxybook-fan - the "new version" notification, with buttons where the
# desktop shows them (runs as the user, in their desktop)
# =============================================================================
#   notify-update.sh TITLE MESSAGE URL
#
# Buttons: "Update now" (a terminal running 'sudo galaxybook-fan update',
# lib/update-in-terminal.sh) and "What's new" (URL: the release page, after
# which the notification is shown again, so "Update now" is still there). It
# waits for a click, so update-check.sh starts it on its own (systemd-run)
# rather than waiting for it. Without notify-send --action, or on desktops
# that don't show buttons (GNOME), it's the same text with the command and
# the link in it. Same idea as fingerprint-fix-sdcp's notify-update.sh.
# =============================================================================
title="${1:?Usage: $0 TITLE MESSAGE URL}"; msg="${2:-}"; url="${3:-}"
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
args=(-t 0 -a "Samsung Galaxy Book Fixes" -i system-software-update)

# The user's terminal: the desktop's default where it says, else the usual one
# for this desktop, else any installed. Prints the command to start one with
# a program to run after it (e.g. "konsole -e"), or nothing.
find_terminal() {
    local t list=()
    if command -v xdg-terminal-exec >/dev/null 2>&1; then echo "xdg-terminal-exec"; return; fi
    case "${XDG_CURRENT_DESKTOP,,}" in
        *kde*)              list=(konsole) ;;
        *gnome*|*ubuntu*)   list=(ptyxis gnome-terminal kgx) ;;
        *xfce*)             list=(xfce4-terminal) ;;
        *cinnamon*)         list=(gnome-terminal xfce4-terminal) ;;
        *mate*)             list=(mate-terminal) ;;
        *lxqt*)             list=(qterminal) ;;
        *budgie*)           list=(tilix gnome-terminal) ;;
    esac
    list+=(ptyxis konsole gnome-terminal kgx xfce4-terminal mate-terminal qterminal
           tilix terminator kitty alacritty wezterm foot x-terminal-emulator xterm)
    for t in "${list[@]}"; do
        command -v "$t" >/dev/null 2>&1 || continue
        case "$t" in
            ptyxis)                  echo "ptyxis --new-window --" ;;
            gnome-terminal|kgx)      echo "$t --" ;;
            xfce4-terminal|mate-terminal|terminator) echo "$t -x" ;;
            wezterm)                 echo "wezterm start --" ;;
            kitty|foot)              echo "$t" ;;
            *)                       echo "$t -e" ;;
        esac
        return
    done
}

# How to open the release page: xdg-open (xdg-utils), else GNOME's gio
opener=""
if command -v xdg-open >/dev/null 2>&1; then opener="xdg-open"
elif command -v gio >/dev/null 2>&1; then opener="gio open"
fi

term="$(find_terminal)"
if notify-send --help 2>&1 | grep -q -- '--action'; then
    actions=()
    # Only offer "Update now" where a terminal can be opened for it
    [[ -n "$term" && -x "$HERE/update-in-terminal.sh" ]] && actions+=(--action=update="Update now")
    # ...and "What's new" only where the link can be opened
    [[ -n "$url" && -n "$opener" ]] && actions+=(--action=whatsnew="What's new")
    # "What's new" shouldn't take "Update now" away: ask the server to keep
    # the notification when a button is pressed (the "resident" hint: GNOME
    # does; KDE closes it anyway), and after opening the page show it again,
    # replacing it by its ID where notify-send can, so there's never two.
    # Only "Update now" or closing it ends this.
    idargs=(); notify-send --help 2>&1 | grep -q -- '--print-id' && idargs=(--print-id)
    id=""
    for (( n = 0; n < 20; n++ )); do
        out="$(notify-send "${args[@]}" --hint=boolean:resident:true "${idargs[@]}" \
            ${id:+--replace-id="$id"} "${actions[@]}" "$title" "$msg" 2>/dev/null)"
        if [[ ${#idargs[@]} -gt 0 ]]; then
            id="$(head -1 <<< "$out")"; [[ "$id" =~ ^[0-9]+$ ]] || id=""
            choice="$(sed -n 2p <<< "$out")"
        else
            choice="$out"
        fi
        case "$choice" in
            update)
                # $term is a command and its options, split on purpose
                # shellcheck disable=SC2086
                exec $term /bin/bash "$HERE/update-in-terminal.sh" ;;
            whatsnew)
                # shellcheck disable=SC2086
                $opener "$url" >/dev/null 2>&1 &
                ;;
            *)  break ;;                   # closed, or timed out
        esac
    done
else
    notify-send "${args[@]}" "$title" "$msg"
fi
exit 0
