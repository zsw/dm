#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh
__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_lock 2>/dev/null || source $DM_ROOT/lib/lock.sh
__loaded_alert 2>/dev/null || source $DM_ROOT/lib/alert.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [OPTIONS] mod_id...

This script takes a mod off hold.
    -f  Force taking mod off hold even if the mod is assigned to someone else.
    -h  Print this help message.

EXAMPLES:
    $script              # Take all applicable mods off hold
    $script 12345        # Take mod 12345 if applicable
    $script -f 12345     # Take mod 12345 regardless

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
_process_mod() {
    local mod status who hold_file for_another

    mod=$1
    status=$(__hold_status "$mod" | awk '{print $5}')
    [[ $status == off_hold ]] && return

    who=$(__attribute "$mod" 'who')
    if [[ $who != $DM_PERSON_INITIALS ]]; then
        [[ ! $force ]] && return
        for_another=1
    fi

    "$DM_BIN/remind_mod.sh" "$mod"

    hold_file=$(__attr_file "$mod" 'hold')
    [[ ! $hold_file ]] && return

    # Comment out all uncommented lines
    sed -i -e 's/^\([^#]\)/#\1/' "$hold_file" && rm "$DM_USERS/holds/$mod" 2>/dev/null

    # Create an alert if taking a mod off hold for someone else
    [[ $for_another ]] && __create_alert "$who" "$mod_id"
}

_options() {
    args=()
    unset force

    while [[ $1 ]]; do
        case "$1" in
            -f) force=1         ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 1 )) && { _u; exit 1; }
    mod=${args[0]}
}

_options "$@"

__lock_create || __me "${script}: Lock file found. cat $(__lock_file)"

_process_mod "$mod"
