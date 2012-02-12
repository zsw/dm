#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


script=${0##*/}
_u() { cat << EOF
usage: $script [mod_id]

This script sets the current mod, ie. the contents of $DM_USERS/current_mod
   -h      Print this help message.

EXAMPLE:
    $script                      # Sets the highest priority mod as current.
    $script 12345                # Sets mod 12345 as current.

NOTES:
    If a mod id is not provided, the one assigned to the person and
    highest in the todo list is used.
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

    (( ${#args[@]} > 1 ))  && { _u; exit 1; }
    (( ${#args[@]} == 1 )) && mod_id=${args[0]}
}

_options "$@"

[[ ! $mod_id ]] && mod_id=$("$DM_BIN/prioritize.sh" | "$DM_BIN/format_mod.sh" "%w %i" | awk -v v="$DM_PERSON_INITIALS" '$1==v {print $2; exit}')
[[ ! $mod_id ]] && __me 'Unable to determine top mod id.'

echo "$mod_id" > "$DM_USERS/current_mod"
