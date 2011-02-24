#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh
__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_lock 2>/dev/null || source $DM_ROOT/lib/lock.sh
__loaded_alert 2>/dev/null || source $DM_ROOT/lib/alert.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 [OPTIONS] mod_id...
       or
       echo mod_id | $0 [OPTIONS] -

This script takes a mod off hold.

OPTIONS:

    -f  Force taking mod off hold even if the mod is assigned to someone else.

    -d  Dry run. Actions not performed.
    -v  Verbose.

    -h  Print this help message.

EXAMPLES:

    $0              # Take all applicable mods off hold
    $0 12345        # Take mod 12345 if applicable
    $0 -f 12345     # Take mod 12345 regardless

NOTES:

    Mod ids can be provided through stdin or as arguments.
    To read the mod list from stdin, use the mod_id '-'.

    A mod id is required. If a mod id is not provided the script does nothing.

    The script will take the mod off hold regardless of the contents of
    the hold file. For example, the script will take a mod off hold even
    if the hold file contains a crontab entry for a future time.

    Unless the -f force option is provided, only mods assigned to the
    local user, as indicated by \$USERNAME, are taken off hold.

    This script puts a lock on the dm system while processing. If it
    cannot obtain a lock, it exits with message.
EOF
}


#
# process_mod
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Process take_off_hold.sh for a mod.
#
function process_mod {

    mod=$1

    logger_debug "Processing mod id: $mod"

    status=$(__hold_status $mod | awk '{print $5}')

    if [[ "$status" == 'off_hold' ]]; then
        logger_debug "Mod status: off_hold. Nothing to do"
        return
    fi

    who=$(attribute $mod 'who')

    for_another=
    if [[ "$who" != $DM_PERSON_INITIALS ]]; then
        if [[ ! $force ]]; then
            logger_debug "Mod is not assigned to $DM_PERSON_INITIALS. No force option. Skipping."
            return
        fi
        for_another=1
    fi

    logger_debug "Mod status: $status. Mod $mod will be taken off hold"

    logger_debug "Calling remind_mod.sh $mod"

    $dryrun && logger_debug "Dry run, remind_mod.sh not called."
    $dryrun || $DM_BIN/remind_mod.sh $mod

    hold_file=$(attr_file $mod 'hold')

    logger_debug "Hold file: $hold_file"

    [[ ! $hold_file ]] && return

    logger_debug "Commenting out all lines in $hold_file"

    # Comment all uncommented lines
    $dryrun || { sed -i -e 's/^\([^#]\)/#\1/' $hold_file && rm $DM_USERS/holds/$mod 2>/dev/null ; }

    $dryrun && logger_debug "Dry run, mod $mod left unchanged."

    # Create an alert if taking a mod off hold for someone else
    if [[ $for_another ]]; then
        create_alert $who $mod_id
    fi
    return
}


dryrun=false
force=false
verbose=

while getopts "dfhv" options; do
  case $options in

    d ) dryrun=true;;
    f ) force=true;;
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

$dryrun && logger_debug "Dry run. Mods not changed."

lock_obtained=$(lock_create)
if [[ "$lock_obtained" == 'false' ]]; then
    if [[ $verbose ]]; then
        echo "Unable to run $0. The dm system is locked at the moment."
        echo "Try again in a few minutes."
        lock_file=$(lock_file)
        echo "Run this command to see which script has the file locked."
        echo "cat $lock_file"
    fi
    exit 1
fi

trap 'lock_remove; exit $?' INT TERM EXIT
while [[ ! "$#" -eq "0" ]]; do
    if [ "$1" == "-" ]; then
        # eg echo 12345 | take_off_hold.sh -
        while read arg; do
            process_mod "$arg"
        done
    else
        process_mod "$1"
    fi
    shift
done

lock_remove
trap - INT TERM EXIT
