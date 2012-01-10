#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

script=${0##*/}
_u() { cat << EOF
usage: $script [mod_id]

This script moves a mod from mods directory to archive directory.
   -h      Print this help message.

EXAMPLE:
    $script 12345

NOTES:
    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod
EOF
}

_options() {
    args=()

    while [[ $1 ]]; do
        case "$1" in
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} > 1 )) && { _u; exit 1; }
    (( ${#args[@]} == 0 )) && args[0]=$(< "$DM_USERS/current_mod")
    mod_id=${args[0]}
}

_options "$@"

[[ ! $mod_id ]] && __me 'Unable to determine current mod id.'

# Do not permit the move if the mod is already in the archive directory.
[[ ! -d $DM_ARCHIVE/$mod_id ]] && mv "$DM_MODS/$mod_id" "$DM_ARCHIVE"

# Assign mod to original owner
"$DM_BIN/assign_mod.sh" -m "$mod_id" -o

# Format the mod properly in the tree
"$DM_BIN/format_mod_in_tree.sh" "$mod_id"
