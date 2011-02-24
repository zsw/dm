#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_lock 2>/dev/null || source $DM_ROOT/lib/lock.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 [options] [EMAIL ...]

This script sends alerts if the dm lock file exists.

OPTIONS:

    -a  Required age of lock file before alert is sent.
    -v  Verbose.

    -h  Print this help message.

EXAMPLES:

    # Send an alert if the dm lock file exists.
    $0

    # Send an alert if the dm lock file exists and was created at least 1 hour
    # ago.
    $0  -a "1 hour"

    # Send alert to specified email address
    $0 -a "1 hour" email@example.com

    # Send alert to several email addresses
    $0 -a "1 hour" email@example.com username@gmail.com

    # Cron lock alerting. Delay the first alert 30 minutes, then send alert
    # at the top of every hour.
    $ crontab -l | grep $0
    00 * * * *  /root/dm/bin/run.sh $0 -a "30 minutes"

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

age=
verbose=

while getopts "a:hv" options; do
  case $options in

    a ) age=$OPTARG;;
    v ) verbose=1;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

lock_status=$(is_locked)
[[ "$verbose" ]] && echo "lock status: $lock_status"
if [[ "$lock_status" != 'true' ]]; then
    [[ "$verbose" ]] && echo "dm system is not locked, no alerts sent"
    exit 0
fi

alert_status=$(lock_is_alertable "$age")
[[ "$verbose" ]] && echo "alert status: $alert_status"
if [[ "$alert_status" != 'true' ]]; then
    [[ "$verbose" ]] && echo "dm system is locked but no alertable, no alerts sent"
    exit 0
fi

if [[ "$#" == "0" ]]; then
    [[ "$verbose" ]] && echo "alerting email: $DM_PERSON_EMAIL"
    result=$(lock_alert $DM_PERSON_EMAIL)
    if [[ "$result" != 'true' ]]; then
        echo "Alert email for $DM_PERSON_EMAIL failed." >&2
    fi
else
    while (( "$#" )); do
        [[ "$verbose" ]] && echo "alerting email: $1"
        result=$(lock_alert $1)
        if [[ "$result" != 'true' ]]; then
            echo "Alert email for $1 failed." >&2
        fi
        shift
    done
fi
