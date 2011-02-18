#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


script=${0##*/}
_u() {

    cat << EOF

usage: $0 options

This script is a user friendly interface to update_mod.sh.

OPTIONS:

    at timestamp
    by jabber|email|pager
    in tree
    to who

    -h  Print this help message.

EXAMPLES:

    $0 at tomorrow          # Postpone current mod until tomorrow
    $0 by jabber pager      # Remind by jabber and pager
    $0 in reminders         # Move current mod to the reminders tree
    $0 to jimk              # Assign current mod to jimk.

    # Send a pager reminder for current mod on Oct 19 at 11am
    $0 at 2008-10-19 11:00 by pager in reminders

NOTES:

   The mod updated is the current one, ie. one indicated in $DM_USERS/current_mod

   All arguments are passed to update_mod.sh. See that script for option syntax.
EOF
}


#
# exit_with_message
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Print message, FIXME:Usage and exit.
#
function exit_with_message {

    echo "ERROR: One of 'at', 'by', 'in' or 'to' plus argument must be provided" >&2
    _u
    exit 1
}


#
# key
#
# Sent: string, 'at', 'by', 'in', 'to'
# Return: nothing
# Purpose:
#
#   Convert string 'at' to it's variable value $at
#
function key {


    x=\$"$1"                    # dereference
    y=`eval "expr \"$x\" "`
    return $y
}


declare -a options

key=
value=

at=1
by=2
in=3
to=4

while [ "$1" != "" ]; do
    case $1 in

        at|by|in|to)
                            [[ "$key" ]] && options["$key"]="$value"
                            key $1
                            key=$?
                            value=
                           ;;

        -h | --help )       _u
                            exit 0
                            ;;
        * )                 [[ "$value" ]] && value="$value $1" || value=$1
                            ;;
    esac
    shift
done

[[ "$key" ]] && options[$key]=$value

cmd="$DM_BIN/update_mod.sh"

[[ "${#options[@]}" == "0" ]] && exit_with_message

[[ ! ${options[$at]} ]] &&  \
[[ ! ${options[$by]} ]] &&  \
[[ ! ${options[$in]} ]] &&  \
[[ ! ${options[$to]} ]] &&  \
exit_with_message

if [[ ${options[$at]} ]]; then
    [[ "${#options[$at]}" == "0" ]] && exit_with_message
    cmd="$cmd -p \"${options[$at]}\""
fi

if [[ ${options[$by]} ]]; then
    [[ "${#options[$by]}" == "0" ]] && exit_with_message
    cmd="$cmd -b \"${options[$by]}\""
fi

if [[ ${options[$in]} ]]; then
    [[ "${#options[$in]}" == "0" ]] && exit_with_message

    # Convert the tree name to a tree file w/ path
    tree=$($DM_BIN/tree.sh ${options[$in]})
    cmd="$cmd -t \"$tree\""
fi

if [[ ${options[$to]} ]]; then
    [[ "${#options[$to]}" == "0" ]] && exit_with_message
    cmd="$cmd -w \"${options[$to]}\""
fi


echo "$cmd"
res=$(eval $cmd)    # Use eval so quotes are interpreted properly

echo "$res"
echo ""
