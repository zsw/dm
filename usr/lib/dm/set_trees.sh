#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


script=${0##*/}
_u() { cat << EOF
usage: $script options

This script sets the active dependency trees.
    -h  Print this help message.

EXAMPLES:
    $script reminders main      # Set the dependency trees for main project development.
    $script reminders personal  # Set the dependency trees for personal stuff.

NOTES:
    Personal trees can be identified by their tree name.
    eg the tree "reminders" is $DM_ROOT/trees/jimk/reminders if the
    current user is jimk.
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

    (( ${#args[@]} == 0 )) && { _u; exit 1; }
}

_options "$@"

trees=${args[@]}
"$DM_BIN/tree.sh" "$trees" >/dev/null || exit 1

echo "$trees" > "$DM_USERS/current_trees"
