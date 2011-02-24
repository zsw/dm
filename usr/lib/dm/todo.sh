#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 options

This script prints a todo list.

OPTIONS:

    -c  Colour output.
    -l  Limit the number of mods in the list.
    -u  Print todo list for this user.

    -h  Print this help message.

EXAMPLES:

    $0                      # Print all mods on todo list.
    $0 -l 15                # Print the top 15 mods on the todo list.

    $0 -u jimk -l 10        # Print the top 10 mods assigned to jimk.
    $0 -u JK -l 10          # Print the top 10 mods assigned to JK.

    $0 -u \$USERNAME         # Print my todo list

NOTES:

    The user option accepts either a username or a user's initials.
EOF
}


colour=
limit=99999999              # ie no limit
username=

while getopts "chl:u:" options; do
  case $options in
    c ) colour=1 ;;
    l ) limit=$OPTARG ;;
    u ) username=$OPTARG ;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

initials=$(cat $DM_PEOPLE | awk -v username=$username 'BEGIN { FS = ",[ \t]*" } { if ( $2 == username || $3 == username ) print $2 }')

sm=$(< $DM_USERS/current_mod)

logger_debug "username: $username"
logger_debug "limit: $limit"
logger_debug "initials: $initials"
logger_debug "current mod: $sm"

awk -v initials=$initials '$2 ~ initials {print $0}' $DM_USERS/todo | \
    head -$limit | \
    awk '{printf "%9s %3s %s ",$3,$2,$1;for (i=4;i<NF+1;i++) {printf "%s ",$i};print ""}' | \
    awk -v mod=$sm -v rev=$(tput rev) -v off=$(tput sgr0) -v colour=$colour '

function get_colour(arg1) {

    set_colour = "echo -e $" toupper(arg1) "_COLOUR"
    set_colour | getline col
    close(set_colour)

    return col
}

{
    if ( ! colour ) {
        print $0
        next
    }

    tree_colour=get_colour($1)

    if ($3 == mod ) {
        # Right align who
        sub(/.*/, sprintf("%3s", $2), $2)

        # Colour and right align tree
        sub(/.*/, sprintf("%1s%9s%s%s", tree_colour, $1, off, rev), $1)
        print rev $0 off
    }
    else {
        # Right align who
        sub(/.*/, sprintf("%3s", $2), $2)

        # Colour and right align tree
        sub(/.*/, sprintf("%1s%9s%s", tree_colour, $1, off), $1)
        print
    }
}
'
