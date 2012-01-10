#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


script=${0##*/}
_u() { cat << EOF
usage: $script [ <tree> <tree> ]

Print the full path file(s) associated with a tree(s) name.
   -h      Print this help message.

EXAMPLES:
    # Print the file for a tree.
    $ $script reminders
    $DM_ROOT/trees/jimk/reminders

    # Print the files for several trees
    $ tree.sh reminders main
    $DM_ROOT/trees/jimk/reminders
    $DM_ROOT/trees/main

    # Use the local trees file if no argument is provided
    $ cat $DM_USERS/trees
    unsorted

    $ tree.sh
    $DM_ROOT/trees/jimk/unsorted

NOTES:
    Without an argument the list of tree names is read from $DM_USERS/current_trees

    The order of the tree files printed reflects the order of the tree names.

    Directories are searched in this order

    1. $DM_ROOT/trees
    2. $DM_ROOT/trees/$USERNAME
EOF
}


_options() {
    args=()
    unset trees

    while [[ $1 ]]; do
        case "$1" in
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done
     (( ${#args[@]} > 0 )) && trees="${args[@]}"
     (( ${#args[@]} == 0 )) && trees=$(< "$DM_USERS/current_trees")
}

_options "$@"

# Find the tree file associated with the tree name.
# Note: the order has to be preserved.
for tree in $trees; do
    if [[ -e $DM_TREES/$tree ]]; then
        echo "$DM_TREES/$tree"
    elif [[ -e $DM_TREES/$DM_PERSON_USERNAME/$tree ]]; then
        echo "$DM_TREES/$DM_PERSON_USERNAME/$tree"
    else
        __me "tree file not found for $tree"
    fi
done
