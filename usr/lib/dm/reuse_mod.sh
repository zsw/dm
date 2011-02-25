#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

script=${0##*/}
_u() { cat << EOF
usage:   $script [ mod_id ... ]

This script flags mods as reusable.
    -h  Print this help message.

EXAMPLES:
    $script                  # Flag the current mod as reusable.
    $script 12345 23456      # Flag mods 12345 and 23456 as reusable.

NOTES:
    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod

    The follow actions are taken when a mod is set as reusable:
        * The mod is removed from all trees.
        * The mod is deleted.
        * The id of the mod is added to the reusable_ids file of the
          mod's creator.
EOF
}


#
# _process_mod
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Process a mod for reuse.
#
_process_mod() {
    local mod_id mod_dir mods dir

    mod_id=$1
    mod_dir=$(mod_dir "$mod_id")

    [[ ! -d $mod_dir ]] && return

    # Add to reusable_ids

    # Reassign mod to the original creator so we know who the original creator
    # is.
    "$DM_BIN/assign_mod.sh" -m "$mod_id" -o
    initials=$(< "$mod_dir/who")
    username=$(__person_attribute username initials "$initials")
    ids=$DM_ROOT/users/$username/reusable_ids
    echo "$mod_id" >> "$ids"
    sort "$ids" -o "$ids"

    # Remove mod from all trees
    while read -r tree; do
        sed -i "/\[.\] $mod_id /d" "$tree"
    done < <(grep -rl "\[.\] $mod_id" "$DM_TREES")

    # Delete mod from mods/archive directory
    [[ $mod_dir =~ /(mods|archive)/ ]] && rm -r "$mod_dir" &>/dev/null
}

_options() {
    # set defaults
    args=()
    unset interactive

    while [[ $1 ]]; do
        case "$1" in
            -i) interactive=1   ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} == 0 )) && args[0]=$(< "$DM_USERS/current_mod")
}

_options "$@"


for mod_id in "${args[@]}"; do
    if [[ $interactive ]]; then
        unset reply
        while true; do
            read -p "Reuse mod $mod_id ? (Y/n): " reply

            [[ ! $reply ]] && reply=y
            reply=$(tr "[:upper:]" "[:lower:]" <<< "$reply")

            [[ $reply == y || $reply == n ]] && break
        done
        [[ $reply == n ]] && continue
    fi

    _process_mod "$mod_id"
done
