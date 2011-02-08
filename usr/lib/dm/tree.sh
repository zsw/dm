#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }


usage() {

    cat << EOF

usage: $0 [ <tree> <tree> ]

Print the full path file(s) associated with a tree(s) name.

OPTIONS:

   -h      Print this help message.

EXAMPLES:

    # Print the file for a tree.
    $ $0 reminders
    /root/dm/trees/jimk/reminders

    # Print the files for several trees
    $ tree.sh reminders main
    /root/dm/trees/jimk/reminders
    /root/dm/trees/main

    # Use the local trees file if no argument is provided
    $ cat $DM_USERS/trees
    unsorted

    $ tree.sh
    /root/dm/trees/jimk/unsorted

NOTES:

    Without an argument the list of tree names is read from $DM_USERS/current_trees

    The order of the tree files printed reflects the order of the tree names.

    Directories are searched in this order

    1. $DM_ROOT/trees
    2. $DM_ROOT/trees/$USERNAME
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


tree_file=

function search {

    keyword=$1


    tree_file=$(find $DM_TREES -mindepth 1 -maxdepth 1 -type f -name $keyword)

    [[ -n $tree_file ]] && return 0;

    tree_file=$(find $DM_TREES/$DM_PERSON_USERNAME -mindepth 1 -maxdepth 1 -type f -name $keyword)

    [[ -n $tree_file ]] && return 0;

    return 1
}

trees="$@"

[[ ! $trees ]] && trees=$(< $DM_USERS/current_trees)

exit_status=0

# Find the tree file associated with the tree name.
# Note: the order has to be preserved.

for tree in $trees; do

    tree_file=

    search $tree

    if [[  "$?" -ne "0" ]]; then
        echo "ERROR: tree file not found for $tree" >&2
        exit_status=1
        continue
    fi

    echo $tree_file
done

exit $exit_status
