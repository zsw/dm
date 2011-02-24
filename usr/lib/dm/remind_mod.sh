#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [OPTIONS] [mod_id]

This script sends a message to all remind email addresses for a mod.
   -h      Print this help message.

NOTES:
    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod

    This script will send reminders regardless if the mod is in the mods
    directory of in the archive directory.
EOF
}

_options() {
    # set defaults
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

mod_dir=$(mod_dir "$mod_id")
remind=$mod_dir/remind_by
[[ ! -e $remind ]] && exit 0

while read -r method; do
    # 'email' => 'EMAIL' => 'DM_NOTIFY_EMAIL'
    account_var=DM_NOTIFY_${method^^}
    account=${!account_var}
    command_var=${account_var}_COMMAND
    command=${!command_var}
    script=${command%% *}
    options=${command#* }
    type "$script" >&/dev/null && "$script" "$options" "$account" "$mod_dir"
done < "$remind"
