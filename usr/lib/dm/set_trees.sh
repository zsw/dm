#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1


script=${0##*/}
_u() {

    cat << EOF

usage: $0 options

This script sets the active dependency trees.

OPTIONS:

    -h  Print this help message.

EXAMPLES:

    $0 now unsorted reminders               # Set the dependency trees for sorting.
    $0 now reminders main                   # Set the dependency trees for main project development.
    $0 personal                             # Set the dependency trees for personal stuff.

NOTES:

    Personal trees can be identified by their tree name.
    eg the tree "reminders" is $DM_ROOT/trees/jimk/reminders if the
    current user is jimk.
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

trees=
for tree in $*; do
    $DM_BIN/tree.sh $tree > /dev/null && trees="$trees $tree"
done
trees=$(echo $trees | sed 's/^[ \t]*//;s/[ \t]*$//')        # Trim whitespace

echo "$trees" > $DM_USERS/current_trees
