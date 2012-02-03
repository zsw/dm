#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh

script=${0##*/}
_u() { cat << EOF
usage: $script mod_id /path/to/tree/file

This script moves a mod from one tree to another.
   -h      Print this help message.

EXAMPLE:
    $script 12345 $DM_ROOT/trees/main
EOF
}

_options() {
    # set defaults
    args=()

    while [[ $1 ]]; do
        case "$1" in
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 2 )) && { _u; exit 1; }
    mod_id=${args[0]}
    to_tree=${args[1]}
}

_options "$@"

[[ ! -e $to_tree ]] && __me "Unable to find tree file: $to_tree"
[[ ! -w $to_tree ]] && __me "Permission denied. Unable to write tree file: $to_tree"

# Ensure mod is valid
__mod_dir "$mod_id" >&/dev/null || __me "Unable to mv mod $mod_id." \
        "Unable to find mod in either $DM_MODS or $DM_ARCHIVE."

# Find the tree file the mod is currently in.
# The integrity script will report issues if a mod is in more than one
# tree. This script will only look at the first tree the mod is found
# in.
from_tree=$(grep -lrP  "^ *\[.\] $mod_id " "$DM_TREES" | head -1)

[[ $from_tree == $to_tree ]] && exit 0

# If the mod is in a group (project) then we need to move the whole
# group to prevent the group from being disorganized.
unset group_id
[[ $from_tree ]] && group_id=$("$DM_BIN/tree_parse.py" --mods "$from_tree" | awk -v v="^$mod_id" '$0 ~ v {print $2}')

if [[ $group_id ]]; then
    "$DM_BIN/mv_group_to_tree.sh" "$group_id" "$to_tree"
else
    # Remove from original tree
    [[ $from_tree ]] && sed -i "/\[.\] $mod_id /d" "$from_tree"

    # Add to new tree
    "$DM_BIN/format_mod_in_tree.sh" "$mod_id" "$to_tree"
fi

# Print the mod id to stdout so script pipes nicely.
echo "$mod_id"
