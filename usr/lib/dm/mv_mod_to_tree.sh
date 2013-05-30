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
from_tree=$(grep -lrP "^ *\[( |x)\] $mod_id " "$DM_TREES" | head -1)

[[ $from_tree == $to_tree ]] && exit 0

# If a mod is in a group, is a dependency or has a dependencies then
# move it manually; otherwise mod.
unset group_id
[[ $from_tree ]] && group_id=$("$DM_BIN/tree_parse.py" --mods "$from_tree" | awk -v v="^$mod_id" '$0 ~ v {print $2}')

if [[ $group_id ]]; then
    __me "Mod $mod_id is in group $group_id and must be moved manually" \
         "eg  vim +/$mod_id -O $from_tree $to_tree"
elif grep -hr -A1 "$mod_id" "$DM_TREES"/* | grep -Eq '^    '; then
    __me "Mod $mod_id is a dependency or has dependencies and must be moved manually" \
         "eg  vim +/$mod_id -O $from_tree $to_tree"
else
    # Remove from original tree
    [[ $from_tree ]] && sed -i "/\[.\] $mod_id /d" "$from_tree"

    # Add to new tree
    "$DM_BIN/format_mod_in_tree.sh" "$mod_id" "$to_tree"
fi

# Print the mod id to stdout so script pipes nicely.
echo "$mod_id"
