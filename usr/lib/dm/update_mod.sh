#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


script=${0##*/}
_u() { cat << EOF
usage: $script at|by|in|to option [option...] [at|by|in|to option...]

This script is used to do any or all of these tasks for a mod
    * Postpone a mod
    * Set how alerts will be notified
    * Move the mod to a specific dependency tree
    * Assign the mod to a different person

OPTIONS:
    at TIME     Postpone time
    by METHOD   Remind by jabber|email|pager
    in FILE     Tree file to move mod to
    to WHO      Who to assign mod to

    -h  Print this help message

EXAMPLES:
    $script at tomorrow             # Postpone mod until tomorrow
    $script by jabber pager         # Remind by jabber and pager
    $script in \$HOME/dm/trees/main # Move mod to the main tree
    $script to jimk                 # Assign mod to person with username jimk

    # Postpone mod until Oct 19 at 11am, remind by pager, move mod
    # to main tree, and assign to SB
    $script at 2008-10-19 11:00 by pager in \$HOME/dm/trees/main to SB

NOTES:
    All arguments for the 'at' option are passed along to postpone.sh. See
    script for option syntax.

    All arguments for the 'by' option are passed along to remind_by.sh.
    See script for option syntax.

    All arguments for the 'in' option are passed along to mv_mod_to_tree.sh.
    See script for option syntax.

    All arguments for the 'to' option are passed along to assign_mod.sh.
    See script for option syntax.
EOF
}

## The command line args include keywords (at, by, in, to) followed by
## one or more parameters. Since we don't know the number of parameters,
## the while...case loop is a little unconventional. The args are
## checked by the loop one at a time. When a keyword is found k is set
## to that, eg k='at'. The loop continues. The next non-keyword arg is a
## parameter for the keyword. The arg is concatenated to $args[$k], the
## associative array element associated with the keyword.
## If a non-keyword arg is found before k is set, it's an error, exit.

declare -A args

_options() {
    args=()
    unset k

    while [[ $1 ]]; do
        case "$1" in
   at|by|in|to) k=$1            ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break ;;
            -*) _u; exit 0      ;;
             *) [[ ! $k ]] && { _u; exit 1; }
                [[ ${args[$k]} ]] && args[$k]="${args[$k]} $1" || args[$k]=$1 ;;
        esac
        shift
    done
}


_options "$@"

mod_id=$(< "$DM_USERS/current_mod")
[[ ! $mod_id ]] && __me 'Unable to determine mod id.'

for index in "${!args[@]}"; do

    case "$index" in
        at) "$DM_BIN/postpone.sh" -m "$mod_id" "${args['at']}"  ;;
        by) "$DM_BIN/remind_by.sh" -m "$mod_id" "${args['by']}" ;;
        in) tree=$("$DM_BIN/tree.sh" "${args['in']}")
            "$DM_BIN/mv_mod_to_tree.sh" "$mod_id" "$tree" &>/dev/null ;;
        to) "$DM_BIN/assign_mod.sh" -m "$mod_id" "${args['to']}"     ;;
    esac

done
