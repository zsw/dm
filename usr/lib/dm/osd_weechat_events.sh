#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

# osd_weechat_events.sh

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_weechat 2>/dev/null || source $DM_ROOT/lib/weechat.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() {

cat << EOF

usage: $0 [options]

This script will monitor the weechat events log file and display logged events
using OSD.

OPTIONS:

    -f      Fork process (detach).

    -h      Print this help message.

NOTES:

The script runs as a daemon with the -f option.

Only one copy of the script can run at a given time.

The weechat events log file is monitored: $log_file.

Logged events are printed to the OSD pipe: $osd_pipe.
The pipe is created if it doesn't exist. Requires the osd_daemon.sh to be
running to display OSD messages.

Only messages from usernames in the whitelist file are displayed: $whitelist_file

Monitoring is controlled by the existence of the osd file: $osd_file.
If the file exists, events logs are displayed with OSD. If the file does not exist, events
are not displayed.

Uses inotail if installed, tail otherwise. The former is more efficient and recommended.
EOF
}


#
# fork
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Fork (detach) the script.
#
# Notes:
#
#   A fork simply retarts this script in the background
#   using setsid with all arguments except the fork option
#   and then exits.
#
function fork {

    cmd=$( echo "$0 $args" | sed -e "s/ -f//" )          # Remove fork option.

    logger_debug "Forking... $cmd"

    /usr/bin/setsid $cmd <&- >&- &                      # Close stdin/stdout and run in background.

    exit 0
}


fork=0

args="$*"

while getopts "hf" options; do
  case $options in

    f ) fork=1;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

if [[ "$fork" -eq "1" ]]; then
    fork
fi

LOG_TO_STDOUT=                      # Prevent logging to stdout

# Remove duplicate processes.
# pgrep only matches on first 15 characters without -f option
for pid in $(pgrep -f osd_weechat_events.sh); do
    # $$ is the current process id. Don't kill it!
    if [ "$pid" -eq "$$" ]; then
        continue;
    fi
    kill -9 $pid
done


whitelist_file="${HOME}/.weechat/whitelist";
whitelist=
[[ -e $whitelist_file ]] && whitelist=1

osd_file="${HOME}/.weechat/osd"         # File exists = logging
                                        # File does not exists = no logging
tmpdir=$(tmp_dir)
pipe_dir="${tmpdir}/pipes"
osd_pipe="$pipe_dir/osd"

log_file=$(weechat_events_file)

logger_debug "Monitoring events file: $log_file";
logger_debug "OSD pipe: $osd_pipe";
logger_debug "OSD file: $osd_file";


tail=$(which inotail 2>/dev/null || which tail 2>/dev/null)

logger_debug "Tail using: $tail";

set -f      # Disable parameter expansion, prevents * in message from expanding

# The -n 0 tail option prevents existing message from being redisplayed.
$tail -n 0 -f $log_file |
while read -r line; do

    # Typical line
    # Tue Nov 18 20:20:55 EST 2008|private|jimk|hi there again

    logger_debug "msg: $line"

    if  [[ ! -e $osd_file ]]; then
        logger_debug "No osd file. Messages not printed to osd pipe."
        continue
    fi

    type=$(echo $line | awk -F'|' '{ print $2}')
    from=$(echo $line | awk -F'|' '{ print $3}')
    msg=$( echo $line | awk -F'|' '{ print $4}')

    logger_debug "Type: $type"
    logger_debug "From: $from"
    logger_debug "Msg: $msg"

    username=$from
    [[ $whitelist ]] && username=$(awk /^$from$/ $whitelist_file)

    if [[ ! $username ]]; then
        logger_debug "Username not whitelisted. Message not printed to osd pipe."
        continue
    fi

    osd=$(printf "%s: %s" "$from" "$msg");

    logger_debug "Printing message to osd pipe."

    echo "$osd" > $osd_pipe
done
set +f
