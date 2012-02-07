#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
usage: $script group_id /path/to/tree/file

This script moves a group from one tree to another.
   -t DIR  Directory where tree data is stored. Default \$HOME/dm/trees

   -h      Print this help message.

EXAMPLE:
    $script 123 $DM_ROOT/trees/main

NOTES:
    The -t tree directory option can be used to change the directory the
    script should look for tree files. This is useful for testing.
    For example:
    $ cp -r $DM_TREES /tmp/trees
    $ $script -t /tmp/trees 123 /tmp/trees/main
EOF
}

_options() {
    args=()
    dm_trees=$DM_TREES

    while [[ $1 ]]; do
        case "$1" in
            -t) shift; dm_trees=$1  ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 2 )) && { _u; exit 1; }
    group=${args[0]}
    to_tree=${args[1]}
}

_options "$@"


# Convert group to an zero padded string.
# This will also validate that the group is a number.
# 10# forces bash to interpret decimal vs octal
group_id=$(printf "%03d" "$((10#$group))")
(( $? != 0 )) && __me "Invalid group id. Digits only: $group"

[[ ! -e $to_tree ]] && __me "Unable to find tree file: $to_tree"
[[ ! -w $to_tree ]] && __me "Permission denied. Unable to write tree file: $to_tree"
[[ ! -d $dm_trees ]] && __me "No such tree directory: $dm_trees"

# Find the tree file the group is currently in.
# The integrity script will report issues if a group is in more than one
# tree. This script will only look at the first tree the group is found
# in.
from_tree=$(grep -lrP "^ *group $group_id" "$dm_trees" | head -1)

[[ ! $from_tree ]] && __me "Unable to find group $group_id in any tree."
[[ $from_tree == $to_tree ]] && exit 0


# If the group is contained in another group, then we have to move the
# root parent group.
root_id=$("$DM_BIN/tree_parse.py" --root-id "$group_id" "$from_tree")
(( $? != 0 )) && exit 1

# It is much easier to extract the contents of a project if the ends are
# tagged.
from_tagged=$(__tmp_file)
"$DM_BIN/tree_parse.py" --tag-ends "$from_tree" > "$from_tagged" || exit 1

group_contents_file=$(__tmp_file)
awk "/group $root_id/,/end $root_id/" "$from_tagged" > "$group_contents_file"

replace_file=$(__tmp_file)
echo "" > "$replace_file"

from_new=$(__tmp_file)
"$DM_BIN/block_substitute.py" "$from_tagged" "$group_contents_file" "$replace_file" > "$from_new" || exit 1

# Groups (projects) are stored at the top of trees, miscellaneous non-grouped
# mods at the bottom. When moving a group, it gets inserted at the end
# of the groups just prior to the non-grouped mods.
to_tagged=$(__tmp_file)
"$DM_BIN/tree_parse.py" --tag-ends "$to_tree" > "$to_tagged" || exit 1

# Get the end tag of the last group in the to_tree, it becomes the
# anchor indicating where the group will be inserted.
to_new=$(__tmp_file)
pattern_file=$(__tmp_file)
replace_file=$(__tmp_file)
final_end=$(grep -P '^ *end' "$to_tagged" | tail -1)

if [[ $final_end ]]; then
    echo "$final_end" > "$pattern_file"
    echo "$final_end" > "$replace_file"           # We don't want the end tag removed
    echo "" >> "$replace_file"                    # Add blank line separator
    cat "$group_contents_file" >> "$replace_file"
    "$DM_BIN/block_substitute.py" "$to_tagged" "$pattern_file" "$replace_file" > "$to_new" || exit 1
else
    # If the 'to' tree has no groups, then just prepend new group at top
    mv "$group_contents_file" "$replace_file"
    echo "" >> "$replace_file"                    # Add blank line separator
    cat "$to_tagged" >> "$replace_file"
    mv "$replace_file" "$to_new"
fi

# Remove end tags
sed -i -e 's/^\([ ]*end\) [0-9]\+/\1/' "$from_new"
sed -i -e 's/^\([ ]*end\) [0-9]\+/\1/' "$to_new"

# Nothing yet has affected live data. Time to update live trees.
cp "$from_new" "$from_tree" && cp "$to_new" "$to_tree"
