#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [ -m mod_id ] <date option>

This script postpones a mod.
   -f      Force postpone. Ignore checks.
   -m      Id of mod
   -h      Print this help message.

EXAMPLES:
    $script -m 12345 tomorrow
    $script -m 23456 2008-09-12 11:30
    $script next thursday
    $script 2 days

NOTES:
   If the -m options is not provided, the mod postponed is the current one,
   ie. one indicated in $DM_USERS/current_mod

   All arguments are passed along to the date command --date option
   and so must follow the appropriate syntax. See man date.

   Unless the force, -f, option is provided, the script exits with error
   message if the postpone date is in the past.
EOF
}

_options() {
    # set defaults
    args=()
    mod=$(< "$DM_USERS/current_mod");
    unset force

    while [[ $1 ]]; do
        case "$1" in
            -f) force=1         ;;
            -m) shift; mod=$1   ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} < 1 )) && { _u; exit 1; }
}

_options "$@"


[[ ! $mod ]] && __me 'Unable to determine mod id.'

date=$(date "+%Y-%m-%d %H:%M:%S" --date="${args[@]}")
[[ ! $date ]] && __me "Invalid date: ${args[@]}"

if [[ ! $force ]]; then
    date_as_sec=$(date "+%s" --date="${args[@]}")
    now_as_sec=$(date "+%s")
    (( $date_as_sec < $now_as_sec )) && __me 'Refusing to postpone mod to time in the past.'
fi

# Take the mod off hold if it currently is on hold
"$DM_BIN/take_off_hold.sh" -f "$mod"

# Add a FIXME:Usage comment to hold file if not already done
__hold_has_usage_comment "$mod" || __hold_add_usage_comment "$mod"

__hold_crontab "$mod" "$date" >> "$DM_MODS/$mod/hold"

holds_dir=$DM_USERS/holds
mkdir -p "$holds_dir"
cd "$holds_dir"
ln -f -s "../../../mods/$mod/hold"  "./$mod"
"$DM_BIN/crontab.sh" -r         ## reload crontab
__mi "Mod $mod on hold until $date."
