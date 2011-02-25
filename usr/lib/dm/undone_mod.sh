#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 mod_id

This script undones a mod, ie it moves it from the archive to the mods
directory.

OPTIONS:

    -f      Force mod off hold.
    -q      Quiet. Suppress printing messages.

    -h      Print this help message.

EXAMPLE:

    $0 12345            # Undone mod 12345
    $0 -f 12222         # Undone mod 12222 and take off hold.

NOTES:
    This script is useful for resetting recurring mods with a crontab
    entry. For example:

        # Undone mod every Wednesday at 9am.
        00 09 * * 3 /root/dm/bin/run.sh undone.sh -f 12345
EOF
}

force=
quiet=

while getopts "fhq" options; do
  case $options in

    f ) force=1;;
    q ) quiet=1;;

    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))


if [ $# -ne 1 ]; then
    _u
    exit 1
fi

mod_id=$1;

mod_dir=$(__mod_dir $mod_id)


if [[ ! "$mod_dir" ]]; then
    echo "ERROR: Unable to mv mod $mod_id." >&2
    echo "Unable to find mod in either $DM_MODS or $DM_ARCHIVE." >&2
    exit 1
fi


# If the mod is in both the mods and archive directories, we have foo.
# Better to exit with error message and let the user handle this manually.

if [[ -d "$DM_ARCHIVES/$mod_id ]] && [[ -d "$DM_MODS/$mod_id ]]; then
    echo "ERROR: Unable to mv mod $mod_id." >&2
    echo "Exists in both $DM_MODS and $DM_ARCHIVE." >&2
    exit 1
fi

# Mods in archived trees are not prioritized. If the mod is in an archived tree
# it has to be moved to an unarchived tree.
#
# Technically a mod should be only in one tree but set up a loop in case of
# unusual data. It's not the place of this script to fix unusual data but it
# can report it.

from_trees=$(find $DM_TREES/ -type f ! -name 'sed*' | xargs --replace grep -l  "\[.\] $mod_id"  {})
tree_count=$(echo "$from_trees" | wc -l)
if [[ ! "$from_trees" ]]; then
    echo "WARNING: mod $mod_id is not found in any trees" >&2
elif [[ $tree_count -gt 1 ]]; then
    echo "WARNING: mod $mod_id is found in multiple trees" >&2
fi

for from_tree in $from_trees; do
    # Is the tree an archive tree? if so move it out.
    found=$(echo $from_tree | grep "^$DM_TREES_ARCHIVE/")
    if [[ $found ]]; then
        to_tree=$(echo $from_tree | sed -e "s@^$DM_TREES_ARCHIVE@$DM_TREES@")
        # If the calculated to tree doesn't exist, use a default tree
        # instead, and inform the user
        if ! test -w $to_tree; then
            default_tree=$DM_TREES/main
            echo "ERROR: invalid tree $to_tree, moving mod $mod_id to default tree $default_tree" >&2
            to_tree=$default_tree
        fi
        echo "NOTICE: mod $mod_id will be moved from an archive tree $from_tree to a live tree $to_tree" >&2
        # Capture result so it doesn't print to stdout
        res=$($DM_BIN/mv_mod_to_tree.sh $mod_id $to_tree)
    fi
done


# Move the mod from archive to the mods directory if necessary

if [[ "$mod_dir" == "$DM_ARCHIVE/$mod_id" ]]; then
    find $DM_ARCHIVE/ -maxdepth 1 -type d -name $mod_id | xargs --replace mv {} $DM_MODS/
fi

# Take the mod off hold if applicable
status=$(__hold_status $mod_id | awk '{print $5}')
if [[ "$status" != 'off_hold' ]]; then
    if [[ $force ]]; then
        $DM_BIN/take_off_hold.sh -f $mod_id
    else
        if [[ ! $quiet ]]; then
            echo "undone_mod.sh: Mod $mod_id has been undone but is on hold."
            echo "No force option provided. Mod is left on hold."
            echo ""
            echo "ID    WHO HOLD                TREE           DESCRIPTION"
            echo $mod_id | $DM_BIN/format_mod.sh
        fi
    fi
fi


status=$(__hold_status $mod_id | awk '{print $5}')
if [[ "$status" == 'off_hold' ]]; then
    # Trigger remind alerts if necessary (useful if mod was undoned by cron)
    $DM_BIN/remind_mod.sh $mod_id
fi

# Assign mod to the current user
$DM_BIN/assign_mod.sh -m "$mod_id" -u

# Format the mod properly in the tree
$DM_BIN/format_mod_in_tree.sh "$mod_id"
