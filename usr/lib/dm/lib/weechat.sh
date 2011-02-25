#!/bin/bash

#
# weechat.sh
#
# Library of functions related to interfacing with weechat.
#

#
# __weechat_log_path
#
# Sent: weechat_version - optional, string representing weechat version
#                         Eg '0.3.0'
#       conf_log_path   - optional, string representing weechat conf
#                         file log path setting.
#                         Eg '%h/logs', '/var/log/weechat'
# Return: nothing
# Purpose:
#
#   Return the path to the weechat log file directory.
#
# Notes:
#
#   The weechat_version and conf_log_path parameters are optional. If
#   they are not provided, they will be acquired from the system
#   (recommended). Normally they are used just for testing.
#
__weechat_log_path() {

    weechat_version=$1
    conf_log_path=$2

    if [[ ! "$weechat_version" ]]; then
        weechat_version=$(weechat-curses --version)
    fi

    if [[ ! "$conf_log_path" ]]; then
        conf_log_path="$HOME/.weechat/logs/"
        if [[ ! -d $conf_log_path ]]; then
            echo "Weechat logs directory not found: $conf_log_path" >&2
            exit 1
        fi

        case $weechat_version in

            0.2.*) conf_log_path=$(awk '/^log_path =/ \
                   {print $3}' ${HOME}/.weechat/weechat.rc | tr -d '"');;

            0.3.*) conf_log_path=$(awk '/^path =/ \
                   {print $3}' ${HOME}/.weechat/logger.conf | tr -d '"');;

            *) echo "Invalid weechat version" >&2
               exit;;
        esac
    fi

    # Replace %h with $HOME/.weechat
    log_path=${conf_log_path/\%h/$HOME\/.weechat}

    # Remove trailing slash
    echo "$log_path" | sed -e 's/\/$//'

    return
}


#
# __weechat_events_file
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Return the name of the weechat events log file.
#
# Notes:
#
#   The file name includes the absolute path.
#
__weechat_events_file() {

    path=$(__weechat_log_path)
    [[ ! $path ]] && return

    echo "$path/events"

    return
}

# This function indicates this file has been sourced.
__loaded_weechat() {
    return 0
}

# Export all functions to any script sourcing this library file.
while read -r function; do
    export -f "${function%%(*}"         # strip '()'
done < <(awk '/^__*()/ {print $1}' "$DM_ROOT"/lib/weechat.sh)
