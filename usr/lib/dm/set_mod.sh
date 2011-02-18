#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


script=${0##*/}
_u() {

    cat << EOF

usage: $0 [mod_id]

This script sets the current mod, ie. the contents of $DM_USERS/current_mod

OPTIONS:

   -h      Print this help message.

EXAMPLE:

    $0                      # Sets the highest priority mod as current.
    $0 12345                # Sets mod 12345 as current.

NOTES:

    If a mod id is not provided, the one assigned to the person and
    highest in the todo list is used.
EOF
}

while getopts "h" options; do
  case $options in

    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

# Get the id of the mod.
mod_id=

if [ $# -gt 1 ]; then
    _u
    exit 1
fi

if [ $# -eq 1 ]; then
    mod_id=$1;
else
    mod_id=$($DM_BIN/todo.sh -u $DM_PERSON_USERNAME -l 1 | awk '{print $3}' |  tr -d '*' )
fi

if [[ ! $mod_id ]]; then

    echo 'ERROR: Unable to determine top mod id.' >&2
    exit 1
fi

echo $mod_id > $DM_USERS/current_mod
