#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

usage() {

    cat << EOF

usage:   $0 [ mod_id ... ]
      or echo mod_id | $0 -

This script flags mods as reusable.

OPTIONS:
    -v  Verbose.
    -h  Print this help message.

EXAMPLES:

    $0                  # Flag the current mod as reusable.
    $0 12345 23456      # Flag mods 12345 and 23456 as reusable.
    echo 12345 | $0 -   # Flag mod 12345 as reusable.

NOTES:

    Mod ids can be provided through stdin or as arguments.
    To read the mod list from stdin, use the mod_id '-'.

    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod

    The mod id is printed to stdout if successful.

    A mod is flagged as reusable by setting the description to REUSE.
EOF
}


#
# process_mod
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Process a mod for reuse.
#
function process_mod {

    local mod_id=$1

    local mod_dir=$(mod_dir $mod_id)

    logger_debug "Mod: $mod_id, mod_dir: $mod_dir"

    [[ -z $mod_dir ]] && return

    [[ ! -d $mod_dir ]] && return

    # Replace description
    echo 'REUSE' > $mod_dir/description || return

    # Reassign mod to the original creator
    $DM_BIN/assign_mod.sh -m "$mod_id" -o

    # Done mod
    local mods=${mod_dir%/*}
    local dir=${mods##*/}

    if [[ "$dir" == "mods" ]]; then
        logger_debug "Doning mod $mod_id"
        $DM_BIN/done_mod.sh $mod_id
    fi

    echo "$mod_id"
}

verbose=

while getopts "hv" options; do
  case $options in

    v ) verbose=1;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ -n $verbose ]] && LOG_LEVEL=debug
[[ -n $verbose ]] && LOG_TO_STDOUT=1

# Default to current mod if not provided
[[ "$#" -eq "0" ]] && set -- $(< $DM_USERS/current_mod)

while [[ ! "$#" -eq "0" ]]; do
    if [ "$1" == "-" ]; then
        # eg echo 12345 | reuse_mod.sh -
        while read arg; do
            process_mod "$arg"
        done
    else
        process_mod "$1"
    fi
    shift
done
