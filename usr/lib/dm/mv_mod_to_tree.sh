#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 mod_id /path/to/tree/file

This script moves a mod from one tree to another.

OPTIONS:

   -h      Print this help message.

EXAMPLE:

    $0 12345 $DM_ROOT/trees/main
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


# Validate the arguments
if [ $# -ne 2 ]; then
    _u
    exit 1
fi

mod_id=$1
to_tree=$2

if [[ ! -e $to_tree ]]; then
    echo "Unable to find tree file: $to_tree" >&2
    exit 1
fi

if [[ ! -w $to_tree ]]; then
    echo "Permission denied. Unable to write tree file: $to_tree" >&2
    exit 1
fi

# Ensure mod is valid
mod_dir=$(mod_dir $mod_id)

if [[ ! "$mod_dir" ]]; then
    echo "ERROR: Unable to mv mod $mod_id." >&2
    echo "Unable to find mod in either $DM_MODS or $DM_ARCHIVE." >&2
    exit 1
fi
# Find the tree file the mod is currently in.
# The integrity script will report issues if a mod is in more than one
# tree. This script will only look at the first tree the mod is found
# in.
from_tree=$( grep -srl  "\[.\] $mod_id" $DM_TREES | head -1)

if [[ "$from_tree" == "$to_tree" ]]; then
    # Nothing to do
    exit 0
fi

group_id=
if [[ $from_tree ]]; then
    # If the mod is in a group (project) then we need to move the whole
    # group to prevent the group from being disorganized.
    group_id=$($DM_BIN/tree_parse.py --mods $from_tree | grep "^$mod_id " | awk '{print $2}')
fi

if [[ $group_id ]]; then
    $DM_BIN/mv_group_to_tree.sh "$group_id" "$to_tree"
else
    if [[ $from_tree ]]; then
        # Remove from original tree
        sed -i "/\[.\] $mod_id /d" $from_tree
    fi

    # Add to new tree
    $DM_BIN/format_mod_in_tree.sh "$mod_id" "$to_tree"
fi

# Print the mod id to stdout so script pipes nicely.
echo $mod_id
