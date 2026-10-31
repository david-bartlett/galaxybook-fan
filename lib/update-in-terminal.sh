#!/bin/bash
# =============================================================================
# galaxybook-fan - "Update now", in a terminal window (from notify-update.sh)
#
# Runs 'sudo galaxybook-fan update': sudo asks for the password, and dnf /
# apt / pacman ask before installing, as usual. The window closes by itself
# 10 seconds after a successful update; otherwise it stays until Enter.
# =============================================================================
bold=$'\e[1m'; green=$'\e[32m'; red=$'\e[31m'; off=$'\e[0m'
printf '\e]0;%s\a' "galaxybook-fan update"     # the window's title
echo "${bold}galaxybook-fan update${off}"
echo
echo "Running:  sudo galaxybook-fan update"
echo
sudo galaxybook-fan update
rc=$?
echo
if [[ $rc -eq 0 ]]; then
    echo "${green}${bold}Done.${off} 'galaxybook-fan status' shows the version now installed."
    echo
    read -r -t 10 -p "This window closes in 10 seconds (or press Enter)." _ || true
else
    echo "${red}${bold}The update didn't finish${off} (exit code $rc). Nothing was changed unless it says so above."
    echo
    read -r -p "Press Enter to close this window." _ || true
fi
