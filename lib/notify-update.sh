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
# rather than waiting for it. With buttons the text is just "You have
# X.Y.Z."; without them it's all of MESSAGE, with the command and the link. Critical everywhere (so it stays). On GNOME, shown by
# notify-dbus.py (notify-send drops its buttons there), and clicking the
# notification itself also opens the release page (its "default" action;
# only there, so other desktops don't draw it as a third button). Same idea
# as fingerprint-fix-sdcp's notify-update.sh.
# =============================================================================
title="${1:?Usage: $0 TITLE MESSAGE URL}"; msg="${2:-}"; url="${3:-}"
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# Critical as well as -t 0, on every desktop: GNOME and Cinnamon ignore -t 0
# and slide a normal notification away after a few seconds; only a critical
# one stays on screen until it's closed or clicked (as fingerprint-fix-sdcp's
# always has, on every desktop)
args=(-u critical -t 0 -a "Samsung Galaxy Book Fixes" -i system-software-update)
# GNOME (Ubuntu's is ubuntu:GNOME; not Budgie, budgie:GNOME): notify-dbus.py
# and the click on the notification, below
desk="${XDG_CURRENT_DESKTOP,,}"
gnome=0
[[ "$desk" == *gnome* && "$desk" != *budgie* ]] && gnome=1

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

# The buttons, as KEY=LABEL
acts=()
# Only offer "Update now" where a terminal can be opened for it
[[ -n "$term" && -x "$HERE/update-in-terminal.sh" ]] && acts+=("update=Update now")
# ...and "What's new" only where the link can be opened
[[ -n "$url" && -n "$opener" ]] && acts+=("whatsnew=What's new")
# GNOME: clicking the notification itself sends its "default" action: make
# that "What's new" too (not "Update now", so a stray click only opens a web
# page), and say so. Only on GNOME ($gnome above): some other desktops draw
# "default" as a button of its own.
if (( gnome )) && [[ -n "$url" && -n "$opener" ]]; then
    acts+=("default=What's new")
fi

# How to show it with buttons: notify-send --action, or on GNOME
# notify-dbus.py, straight over D-Bus - there notify-send (0.8.8, Ubuntu
# 26.04) says "Actions are not supported" and drops them, although GNOME
# shows them when asked directly. 2 = can't (no PyGObject): plain instead.
way=""
if (( gnome )) && [[ -f "$HERE/notify-dbus.py" ]] && command -v python3 >/dev/null 2>&1 \
        && python3 -c 'import gi' 2>/dev/null; then
    way=dbus
elif notify-send --help 2>&1 | grep -q -- '--action'; then
    way=notify-send
fi
# With buttons, only the first line of the text ("You have X.Y.Z."): the
# command and the link are what the buttons do, and GNOME runs the lines
# together into one long one. Without buttons, all of it ($full: also used
# if the D-Bus helper fails below), so it can still be acted on.
full="$msg"
if [[ -n "$way" && ${#acts[@]} -gt 0 ]]; then
    msg="${msg%%$'\n'*}"
    [[ " ${acts[*]} " == *" default="* ]] && msg+=$'\n'"Click this notification to see what's new."
fi

# Show it and print the button pressed (nothing if it was closed)
show() {
    local a pairs=() opts=()
    case "$way" in
        dbus)
            for a in "${acts[@]}"; do pairs+=("${a%%=*}" "${a#*=}"); done
            python3 -I "$HERE/notify-dbus.py" 2 \
                "Samsung Galaxy Book Fixes" system-software-update "$title" "$msg" "${pairs[@]}" ;;
        notify-send)
            for a in "${acts[@]}"; do opts+=("--action=$a"); done
            notify-send "${args[@]}" "${opts[@]}" "$title" "$msg" 2>/dev/null ;;
    esac
}

if [[ -n "$way" && ${#acts[@]} -gt 0 ]]; then
    # "What's new" shouldn't take "Update now" away: desktops close a
    # notification when one of its buttons is pressed, so after opening the
    # page show it again - a new one, a moment later so it pops up after the
    # browser window. "Update now" or closing it ends this.
    # (Not the "resident" hint: notify-send only reports a button once the
    # notification has closed, and KDE kept a resident one, so the click
    # never got through. Not --replace-id either: KDE then quietly updates
    # the one already gone instead of showing it.)
    for (( n = 0; n < 20; n++ )); do
        choice="$(show)"; rc=$?
        if [[ $way == dbus && $rc -eq 2 ]]; then
            # D-Bus didn't work after all: the plain notification, without
            # the line about clicking it
            notify-send "${args[@]}" "$title" "$full"
            break
        fi
        case "$choice" in
            update)
                # $term is a command and its options, split on purpose
                # shellcheck disable=SC2086
                exec $term /bin/bash "$HERE/update-in-terminal.sh" ;;
            whatsnew|default)
                # shellcheck disable=SC2086
                $opener "$url" >/dev/null 2>&1 &
                sleep 2 ;;
            *)  break ;;                   # closed, or timed out
        esac
    done
else
    notify-send "${args[@]}" "$title" "$msg"
fi
exit 0
