#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0

This script prints the effective weechat fifo named pipe for a user.

OPTIONS:

    -u  User of weechat pipe.

    -h  Print this help message.

EXAMPLES:

    $0
    $0 -u jimk

NOTES:

    Requires weechat and weechat fifo channel: $HOME/.weechat/weechat_fifo_xxxxx

    If the user option is not provided, $USER is assumed.
EOF
}

user=$USER

while getopts "dhu:" options; do
  case $options in

    u ) user=$OPTARG;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

count=0
path=

for fifo in $(find $HOME/.weechat/ -type p -name 'weechat_fifo_*'); do
    count=$(( $count + 1 ))

    logger_debug "Pipe: $fifo"

    pid=$(basename $fifo | sed -e "s/weechat_fifo_//g")
    logger_debug "PID: $pid"

    if [[ ! "$pid" ]]; then
        echo "Unable to determine weechat pipe pid for $fifo" >&2
        continue
    fi

    euser=$(ps -p $pid -o euser --no-headers)
    logger_debug "Euser: $euser"

    comm=$(ps -p $pid -o comm --no-headers)
    logger_debug "Command: $comm"

    if [[ ! "$euser" ]] || [[ ! "$comm" ]]; then
        echo -n "Unable to determine effective user or command of pid $pid. " >&2
        echo -n "Weechat may not have been exited properly. " >&2
        echo "Consider deleting $fifo" >&2
        continue
    fi

    if [[ "$euser" != "$user" ]]; then
        logger_debug "Ignoring $fifo. Not run under user: $user."
        continue
    fi

    if [[ "$comm" != 'weechat-curses' ]]; then
        echo "PID $pid is not a weechat-curses process" >&2
        continue
    fi

    if [[ $path ]]; then
        echo "Multiple effective weechat named pipes. One should be deleted." >&2
        exit 1
    fi

    path=$fifo
done

if [[ "$count" -eq "0" ]]; then
    echo "No weechat named pipes found. Is weechat running?" >&2
    exit 1
fi

if [[ ! "$path" ]]; then
    echo "No weechat named pipes found. Is weechat running under user: $user?" >&2
    exit 1
fi

echo $path
