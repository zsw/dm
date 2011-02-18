#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 mod_id [/path/to/tree/file]

Format a mod description in a tree.

OPTIONS:

   -h      Print this help message.

EXAMPLES:

    # Format mod 12345 in the main tree
    $0 12345 $DM_ROOT/trees/main

NOTES:

    A typical mod description is:

        [ ] 12345 This is the mod description

    If the mod is already in the tree, the existing description is
    replaced. Indentation is preserved.

    If the mod is not in the tree, the mod description is appended to
    the end of the tree.

    If a path to a tree file is not provided, ie only one argument, the
    mod_id, is provided, the mod description is formatted in all trees
    that it currently exists in. Under normal conditions that should be
    only one tree, but if it happens to be in more than one tree, it
    will be updated in each of them. If it is not in any tree, nothing
    is done.
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

if [[ $# -lt 1 ]]; then
    echo "ERROR: Missing mod id."
    _u
    exit 1
fi

mod_id=$1
tree=
if [[ $# -gt 1 ]]; then
    tree=$2
fi

# Ensure mod is valid
mod_dir=$(mod_dir $mod_id)

if [[ ! "$mod_dir" ]]; then
    echo "ERROR: Invalid mod, id: $mod_id." >&2
    echo "Unable to find mod in either $DM_MODS or $DM_ARCHIVE." >&2
    exit 1
fi

trees=
if [[ $tree ]]; then
    # This will verify the tree exists and is a tree file
    trees=$(find $tree -type f ! -name 'sed*' | grep "^$DM_TREES")
else
    # Get all trees the mod is in
    trees=$(find $DM_TREES/ -type f ! -name 'sed*' -exec grep -l "\[.\] $mod_id"  '{}' \;)
fi

# If the mod is in no trees exit quietly.
[[ ! $trees ]] && exit 0

# The code below attempts to:
# * Match characters with special meaning within regexp properly.
# * Not match lines where the mod id is within the description of
#   another mod.
# * Preserve indentation.
# Normally sed would be used to search and replace but since it doesn't
# handle special characters well, awk is used.

tmpfile=$(tmp_file)
line=$(echo $mod_id | $DM_BIN/format_mod.sh "%b %i %d")
pattern="[ ]*\\\[[ x]\\\] $mod_id "
for t in $trees; do
    found=$(grep -l "\[.\] $mod_id" $t)
    if [[ $found ]]; then
        # Replace in tree file
        # Preserve indentation
        indent=$(grep "\[.\] $mod_id" $t | grep -o '^[ ]*')
        awk -v line="$line" -v pat="$pattern" -v indent="$indent" \
            '$0 ~ pat {print indent line; next} \
            {print $0}' $t > $tmpfile && \
            mv $tmpfile $t
    else
        # Append to tree file
        echo "$line" >> $t
    fi
done
