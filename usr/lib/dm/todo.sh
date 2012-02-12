#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

script=${0##*/}
_u() { cat << EOF
usage: $script options

This script prints a todo list.
    -c  Colour output.
    -l  Limit the number of mods in the list.
    -u  Print todo list for this user.

    -h  Print this help message.

EXAMPLES:
    $script                      # Print all mods on todo list.
    $script -l 15                # Print the top 15 mods on the todo list.

    $script -u jimk -l 10        # Print the top 10 mods assigned to jimk.
    $script -u JK -l 10          # Print the top 10 mods assigned to JK.

    $script -u \$USERNAME         # Print my todo list

NOTES:
    The user option accepts either a username or a user's initials.
EOF
}

_options() {
    args=()
    unset colour
    unset limit
    unset user

    while [[ $1 ]]; do
        case "$1" in
            -c) colour=1        ;;
            -l) shift; limit=$1 ;;
            -u) shift; user=$1  ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 0 )) && { _u; exit 1; }
}

_options "$@"

[[ $user ]] && dm_initials=$(awk -F',[ \t]*' -v user="$user" '$2 == user || $3 == user { print $2 }' "$DM_PEOPLE")
[[ $user ]] && [[ ! $dm_initials ]] && __me "No initials found for username: $user"

cm=$(< "$DM_USERS/current_mod")
(( $cm )) || __me "Current mod not set"

while read -r tree initials mod_id description; do
    if [[ $colour ]]; then
        [[ $cm == $mod_id ]] && rev=$REVERSE || unset rev
        eval "col=\${${tree^^}_COLOUR}"
    fi
    printf "$col%9.9s$COLOUROFF $rev%3s %s %s $COLOUROFF\n" "$tree" "$initials" "$mod_id" "$description"
done < <("$DM_BIN/prioritize.sh" | "$DM_BIN/format_mod.sh" "%t %w %i %d" | awk -v l="$limit" -v i="$dm_initials" '!i || $2==i {if (x++ == l) exit; print}')

exit 0
