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

This script cleans a mod hold file.

OPTIONS:

    -d  Dry run. Actions not performed.
    -v  Verbose.

    -h  Print this help message.

EXAMPLES:

    $0 12345            # Clean the hold file for mod 12345
    echo 12345 | $0 -   # Clean the hold file for mod 12345

    # Clean all hold files
    find \$DM_ROOT/ -name hold | sed -e "s/\/hold$//g" | format_mod.sh "%i" | $0 -


NOTES:

    Mod ids can be provided through stdin or as arguments.
    To read the mod list from stdin, use the mod_id '-'.

    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod

    Cleaning a hold file involves the following steps:
    * Remove leading and trailing whitespace from all lines.
    * Remove trailing blank lines.
    * Comment all uncommented lines but last uncommented line.
    * Report error if last uncommented line is not a valid timestamp.
EOF
}


#
# process_mod
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Clean the hold file of a mod.
#
function process_mod {

    mod=$1

    logger_debug "Processing mod $mod"

    hold_file=$(attr_file $mod 'hold')

    [[ ! $hold_file ]] && return

    # Ignore files with git conflict markers. Processing them may cause
    # foo. Eg, the user may be editing the file fixing the conflict or
    # the hold time may get commented out.

    has_conflict_markers $hold_file && return

    $dryrun && echo "Dry run. Actions not performed."
    $dryrun && return

    # Remove leading and trailing whitespace from each line
    sed -i -e 's/^[ \t]*//;s/[ \t]*$//' $hold_file

    # Remove all trailing blank lines at end of file
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' $hold_file

    # Comment all uncommented lines but the last
    sed -i -e '$!s/^\([^#]\)/#\1/' $hold_file

    # Validate timestamp
    local crontab=$(tail -1 $hold_file | grep -v '^#')
    [[ ! "$crontab" ]] && return

    logger_debug "Crontab: $crontab"

    timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$crontab")
    logger_debug "Timestamp: $timestamp"

    date -d "$timestamp" > /dev/null 2>&1

    if [[ "$?" -ne "0" ]]; then
        echo "ERROR: Invalid hold time $timestamp in hold file $hold_file" >&2
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
        # eg echo 12345 | hold_clean.sh -
        while read arg; do
            process_mod "$arg"
        done
    else
        process_mod "$1"
    fi
    shift
done
