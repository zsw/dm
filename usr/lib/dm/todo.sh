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
    limit=99999999              # ie no limit
    unset colour
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

(( $limit )) || __me "Invalid limit"

initials=$(awk -F',[ \t]*' -v user="$user" '$2 == user || $3 == user { print $2 }' "$DM_PEOPLE")

sm=$(< "$DM_USERS/current_mod")

i=0
while read -r id init tree descr; do
    [[ $user && $init != $initials ]] && continue
    unset col rev
    if [[ $colour ]]; then
        eval "col=\${${tree^^}_COLOUR}"
        [[ $sm == $id ]] && rev=$REVERSE || unset rev
    fi
    printf "${col}%9s$COLOUROFF ${rev}%3s %s %s $COLOUROFF\n" "$tree" "$init" "$id" "$descr";
    (( ++i >= $limit )) && break
done < $DM_USERS/todo

exit 0
