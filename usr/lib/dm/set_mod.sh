#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }


usage() {

    cat << EOF

usage: $0 [mod_id]

This script sets the current mod, ie. the contents of $HOME/.dm/mod

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

    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

# Get the id of the mod.
mod_id=

if [ $# -gt 1 ]; then
    usage
    exit 1
fi

if [ $# -eq 1 ]; then
    mod_id=$1;
else
    mod_id=$($DM_BIN/todo.sh -u $DM_PERSON_USERNAME -l 1 | awk '{print $3}' |  tr -d '*' )
fi

if [[ -z $mod_id ]]; then

    echo 'ERROR: Unable to determine top mod id.' >&2
    exit 1
fi

echo $mod_id > $HOME/.dm/mod
