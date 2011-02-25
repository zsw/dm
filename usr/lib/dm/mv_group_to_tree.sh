#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 group_id /path/to/tree/file

This script moves a group (project) from one tree to another.

OPTIONS:

   -d      Dry run. Go through the motions but don't move anything.
   -t DIR  Directory where tree data is stored. Default \$HOME/dm/trees
   -v      Verbose.
   -h      Print this help message.

EXAMPLE:

    $0 123 $DM_ROOT/trees/main

NOTES:
    The -t tree directory option can be used to change the directory the
    script should look for tree files. This is useful for testing.
    For example:
    $ cp -r $DM_TREES /tmp/trees
    $ $0 -t /tmp/trees 123 /tmp/trees/main
EOF
}

dryrun=
dm_trees=$DM_TREES
verbose=

while getopts "dht:v" options; do
  case $options in

    d ) dryrun=1;;
    t ) dm_trees=$OPTARG;;
    v ) verbose=1;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))


# Validate the tree argument

if [ $# -ne 2 ]; then
    _u
    exit 1
fi

[[ $verbose ]] && LOG_LEVEL=debug
[[ $verbose ]] && LOG_TO_STDERR=1

group=$1
to_tree=$2

# Convert group to an zero padded string.
# This will also validate that the group is a number.
group_id=$(printf "%03d" "$group")
if [[ "$?" != "0" ]]; then
    echo "Invalid group id. Digits only: $group" >&2
    exit 1
fi

if [[ ! -e $to_tree ]]; then
    echo "Unable to find tree file: $to_tree" >&2
    exit 1
fi

if [[ ! -w $to_tree ]]; then
    echo "Permission denied. Unable to write tree file: $to_tree" >&2
    exit 1
fi

if [[ ! -d $dm_trees ]]; then
    echo "No such tree directory: $dm_trees" >&2
    exit 1
fi

# Find the tree file the group is currently in.
# The integrity script will report issues if a group is in more than one
# tree. This script will only look at the first tree the group is found
# in.

from_tree=$(grep -lsr "^[ ]*group $group_id" $dm_trees | head -1)
if [[ ! $from_tree ]]; then
    echo "Unable to find group $group_id in any tree." >&2
    exit 1
fi

if [[ "$from_tree" == "$to_tree" ]]; then
    # Nothing to do
    __logger_debug "Group $group_id is already in tree $to_tree."
    exit 0
fi

__logger_debug "From tree: $from_tree"

# If the group is contained in another group, then we have to move the
# root parent group.

__logger_debug "Getting root group of group $group_id"
root_id=$($DM_BIN/tree_parse.py --root-id $group_id $from_tree)
if [[ "$?" != "0" ]]; then
    exit 1
fi

__logger_debug "Root group id: $root_id"

# It is much easier to extract the contents of a project if the ends are
# tagged.
__logger_debug "Tagging ends of the 'from' tree file"
from_tagged=$(__tmp_file)
$DM_BIN/tree_parse.py --tag-ends  $from_tree > $from_tagged
if [[ "$?" != "0" ]]; then
    exit 1
fi

__logger_debug "Copying contents of the root group into a pattern file"
group_contents_file=$(__tmp_file)
cat $from_tagged | awk "/group $root_id/,/end $root_id/" > $group_contents_file

replace_file=$(__tmp_file)
cp /dev/null $replace_file
echo "" > $replace_file

__logger_debug "Removing group from the 'from' tree"
from_new=$(__tmp_file)
$DM_BIN/block_substitute.py $from_tagged $group_contents_file $replace_file > $from_new
if [[ "$?" != "0" ]]; then
    exit 1
fi

# Groups (projects) are stored at the top of trees, miscellaneous non-grouped
# mods at the bottom. When moving a group, it gets inserted at the end
# of the groups just prior to the non-grouped mods.

__logger_debug "Tagging ends of the 'to' tree file"
to_tagged=$(__tmp_file)
$DM_BIN/tree_parse.py --tag-ends  $to_tree > $to_tagged
if [[ "$?" != "0" ]]; then
    exit 1
fi

# Get the end tag of the last group in the to_tree, it becomes the
# anchor indicating where the group will be inserted.
to_new=$(__tmp_file)
pattern_file=$(__tmp_file)
replace_file=$(__tmp_file)
final_end=$(cat $to_tagged | grep '^[ ]*end' | tail -1)
if [[ "$final_end" ]]; then
    __logger_debug "Adding group to the 'to' tree"
    echo "$final_end" > $pattern_file
    echo "$final_end" > $replace_file           # We don't want the end tag removed
    echo "" >> $replace_file                    # Add blank line separator
    cat $group_contents_file >> $replace_file
    $DM_BIN/block_substitute.py $to_tagged $pattern_file $replace_file > $to_new
    if [[ "$?" != "0" ]]; then
        exit 1
    fi
else
    # If the 'to' tree has no groups, then just prepend new group at top
    __logger_debug "Prepending group to the 'to' tree"
    cat $group_contents_file > $replace_file
    echo "" >> $replace_file                    # Add blank line separator
    cat $to_tagged >> $replace_file
    mv $replace_file $to_new
fi

# Remove end tags
sed -i -e 's/^\([ ]*end\) [0-9]\+/\1/' $from_new
sed -i -e 's/^\([ ]*end\) [0-9]\+/\1/' $to_new

__logger_debug "group_contents_file: $group_contents_file"
__logger_debug "pattern_file: $pattern_file"
__logger_debug "replace_file: $replace_file"
__logger_debug "from_tagged: $from_tagged"
__logger_debug "from_new: $from_new"
__logger_debug "to_tagged: $to_tagged"
__logger_debug "to_new: $to_new"

# Nothing yet has affected live data. Time to update live trees.
if [[ ! $dryrun ]]; then
    __logger_debug "Copying new trees to live."
    cp $from_new $from_tree && cp $to_new $to_tree
else
    __logger_debug "### Dry run - Live data not changed ###"
fi

