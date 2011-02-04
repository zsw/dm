#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

usage() {

    cat << EOF

usage: $0 [mod_id]

This script moves a mod from mods directory to archive directory.

OPTIONS:

   -h      Print this help message.

EXAMPLE:

    $0 12345

NOTES:

    If a mod id is not provided the current one is used, ie. the one
    indicated in $HOME/.dm/mod
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
    mod_id=$(cat $HOME/.dm/mod);
    if [ -z $mod_id ]; then

        echo 'ERROR: Unable to determine current mod id.' >&2
        exit 1
    fi
fi

# Do not permit the move if the mod is already in the archive directory.
find $DM_ARCHIVE/$mod_id -type d > /dev/null 2>&1
if [[ "$?" != "0" ]]; then
    # Move the mod from the mods directory to the archive directory
    mv $DM_MODS/$mod_id $DM_ARCHIVE
fi

# Assign mod to original owner
$DM_BIN/assign_mod.sh -m "$mod_id" -o

# Format the mod properly in the tree
$DM_BIN/format_mod_in_tree.sh "$mod_id"
