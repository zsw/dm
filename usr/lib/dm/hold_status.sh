#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh

usage() {

    cat << EOF

usage: $0 [OPTIONS] [mod_id mod_id ...]
       or
       echo mod_id | $0 [OPTIONS] -

This script reports the hold status of a mod.

OPTIONS:

    -h  Print this help message.

EXAMPLES:

    $0 12345            # Determine the hold status of mod 12345
    echo 12345 | $0 -   # Determine the hold status of mod 12345

    # Determine the hold status of all mods on hold.
    find \$DM_ROOT/ -name hold | sed -e "s/\/hold$//g" | format_mod.sh "%i" | $0 -

    # Determine all mods on hold
    find \$DM_ROOT/ -name hold | sed -e "s/\/hold$//g" | format_mod.sh "%i" | $0 - | grep 'on_hold'

NOTES:

    Mod ids can be provided through stdin or as arguments.
    To read the mod list from stdin, use the mod_id '-'.

    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod

    The columns of the output are: mod id, hold date, hold time, hold status

    Sample output:

    12222 2009-01-21 11:11:11 on_hold
    13333 ---------- --:--:-- off_hold
    14444 2009-01-01 11:11:11 expired
EOF
}


#
# process_mod
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Process hold_status for a mod.
#
function process_mod {

    mod=$1

    hold_file=$(attr_file $mod 'hold')

    # Ignore files with git conflict markers. Processing them may cause
    # foo. Eg, the user may be editing the file fixing the conflict or
    # the hold time may get commented out.

    has_conflict_markers $hold_file && return

    timestamp=$(hold_timestamp $mod)

    status=$(hold_timestamp_status "$timestamp")

    [[ -z "$timestamp" ]] && timestamp='---------- --:--:--'
    [[ -z "$status" ]]    && status='off_hold'

    who_file=$(attr_file $mod 'who')
    who=$(cat $who_file | tr -d -c 'A-Z')

    echo "$mod $who $timestamp $status"
}


while getopts "h" options; do
  case $options in

    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ "$#" -eq "0" ]] && set -- $(< $DM_USERS/current_mod)

while [[ ! "$#" -eq "0" ]]; do
    if [ "$1" == "-" ]; then
        # eg echo 12345 | hold_status.sh -
        while read arg; do
            process_mod "$arg"
        done
    else
        process_mod "$1"
    fi
    shift
done

