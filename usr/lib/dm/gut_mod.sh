#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

script=${0##*/}
_u() {

    cat << EOF

usage:   $0 mod_id ...
      or echo mod_id | $0 -

This script guts a mod and prints the mod id.

OPTIONS:

    -h  Print this help message.

EXAMPLES:

    $0 12345 23456      # Gut mods 12345 and 23456
    echo 12345 | $0 -   # Gut mod 12345

NOTES:

    Mod ids can be provided through stdin or as arguments.
    To read the mod list from stdin, use the mod_id '-'.

    The mod id is printed to stdout if the gut is successful.

    Gutting a mod does the following

    * Removes all mod attribute files and attachments.
    * Creates a description for the mod: "Blank mod"
    * Assigns the mod to the person associated with \$USERNAME

    WARNING: Gutting a mod will destroy its contents.
EOF
}


#
# process_mod
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Gut a mod.
#
function process_mod {

    mod=$1

    mod_dir=$(mod_dir $mod)

    logger_debug "Mod: $mod, mod_dir: $mod_dir"

    [[ ! $mod_dir ]] && return

    [[ ! -d $mod_dir ]] && return

    # Add a few precautions since we are about to do a rm -r
    [[ "$mod_dir" == '/' ]] && return
    [[ ! $mod_dir = "$DM_ROOT/archive/$mod" && ! $mod_dir =~ "$DM_ROOT/mods/$mod" ]] && return

    rm -r $mod_dir || return

    mkdir -p $mod_dir || return

    echo 'Blank mod' > $mod_dir/description || return
    echo $DM_PERSON_INITIALS > $mod_dir/who || return

    echo "$mod"
}


while getopts "h" options; do
  case $options in

    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

while [[ ! "$#" -eq "0" ]]; do
    if [ "$1" == "-" ]; then
        # eg echo 12345 | gut_mod.sh -
        while read arg; do
            process_mod "$arg"
        done
    else
        process_mod "$1"
    fi
    shift
done
