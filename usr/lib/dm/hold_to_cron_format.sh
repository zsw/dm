#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh
_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 [OPTIONS] [mod_id mod_id ...]
       or
       echo mod_id | $0 [OPTIONS] -

This script converts a mod's hold file to the crontab format.

OPTIONS:

    -d  Dry run. Actions not performed.
    -v  Verbose.

    -h  Print this help message.

EXAMPLES:

    $0 12345            # Convert the hold file for mod 12345
    echo 12345 | $0 -   # Convert the hold file for mod 12345

    # Clean all hold files
    find \$DM_ROOT/ -name hold | sed -e "s/\/hold$//g" | format_mod.sh "%i" | $0 -


NOTES:

    Mod ids can be provided through stdin or as arguments.
    To read the mod list from stdin, use the mod_id '-'.

    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod

    If a mod's hold file is already in the crontab format, nothing is
    changed.
EOF
}


#
# process_mod
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Convert the hold file of a mod.
#
function process_mod {

    local mod=$1

    logger_debug "$mod - processing"

    local hold_file=$(attr_file $mod 'hold')

    [[ ! $hold_file ]] && return

    # Ignore files with git conflict markers. Processing them may cause
    # foo. Eg, the user may be editing the file fixing the conflict or
    # the hold time may get commented out.

    has_conflict_markers $hold_file
    if [[ "$?" == "0" ]]; then
        echo "Mod $mod has git conflict markers. Refusing to convert." >&2
        return
    fi

    # Validate timestamp
    local line=$(tail -1 $hold_file | grep -v '^#')
    [[ ! "$line" ]] && logger_debug "$mod - not on hold"

    timestamp=""
    if [[ "$line" ]]; then
        local print_time=$(echo $line | cut -b -20)
        logger_debug "$mod - hold file line: $print_time"

        # Try crontab format
        timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$line")

        # If not, try old timestamp format
        if [[ ! $timestamp ]]; then
            timestamp=$(date --date="$timestamp" "+%F %T" > /dev/null 2>&1)
            if [[ "$?" != "0" ]]; then
                echo "ERROR: mod $mod - Invalid crontab format." >&2
                return
            fi
        fi
    fi

    logger_debug "$mod - timestamp: $timestamp"

    $dryrun && echo "Dry run. Actions not performed."
    $dryrun && return

    logger_debug "$mod - converting..."

    cp /dev/null $hold_file
    if [[ "$timestamp" ]]; then
        $DM_BIN/postpone.sh -m "$mod" "$timestamp"
    fi

    return
}


dryrun=false
verbose=

while getopts "dhv" options; do
  case $options in

    d ) dryrun=true;;
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

[[ $verbose ]] && LOG_LEVEL=debug
[[ $verbose ]] && LOG_TO_STDOUT=1

[[ "$#" -eq "0" ]] && set -- $(< $DM_USERS/current_mod)

while [[ ! "$#" -eq "0" ]]; do
    if [ "$1" == "-" ]; then
        # eg echo 12345 | hold_to_cron_format.sh -
        while read arg; do
            process_mod "$arg"
        done
    else
        process_mod "$1"
    fi
    shift
done
