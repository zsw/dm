#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_lock 2>/dev/null || source $DM_ROOT/lib/lock.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [options] [EMAIL ...]

This script sends alerts if the dm lock file exists.
    -a  Required age of lock file before alert is sent.

    -h  Print this help message.

EXAMPLES:
    # Send an alert if the dm lock file exists.
    $script

    # Send an alert if the dm lock file exists and was created at least 1 hour
    # ago.
    $script -a "1 hour"

    # Send alert to specified email address
    $script -a "1 hour" email@example.com

    # Send alert to several email addresses
    $script -a "1 hour" email@example.com username@gmail.com

    # Cron lock alerting. Delay the first alert 30 minutes, then send alert
    # at the top of every hour.
    $ crontab -l | grep $script
    00 * * * *  /root/dm/bin/run.sh $script -a "30 minutes"

NOTES:
    This script is intended to be cronned.

    If no email addresses are provided, alerts are sent to $DM_PERSON_EMAIL.

    The age, -a, option should be a string acceptable by the date command in
    in this format: date --date="now + $age"

    Examples:
        15 min
        15 minutes
         2 hours
         1 day
         7 days
EOF
}


_options() {
    args=()
    unset age

    while [[ $1 ]]; do
        case "$1" in
            -a) shift; age=$1   ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} == 0 )) && args+=("$DM_PERSON_EMAIL")
}

_options "$@"

__is_locked || exit 0
__lock_is_alertable "$age" || exit 0

for i in "${args[@]}"; do
    __lock_alert "$i" || __mi "Alert email for $i failed." >&2
done
