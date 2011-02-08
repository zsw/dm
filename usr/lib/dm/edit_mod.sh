#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script="${0##*/}"
usage() {
    cat << EOF
usage: $script [mod_id]
This script assembles a mod, opens it in an editor, then dissembles it.

    -h      Print this help message.

EXAMPLE:
    $script 12345

NOTES:
    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod

    If a mod is slated for sorting, ie it is found in the 'now' or
    'unsorted' tree, it is opened read-only.
EOF
}


sort_msg() {
    cat << EOT
**************  SORT MOD   **************  SORT MOD   **************

This mod is in the $tree_base tree indicating it should be sorted first not
done. You can edit the mod if necessary.

Instructions:

# Do mod now (postpone for 5 minutes, finish sorting first!)
um at 5 minutes in reminders

# Create reminder:
um at next thursday 11:00 in reminders

# Sort again later
um at tomorrow in unsorted
um at next Sunday in unsorted

# Move mod to project:
um in main

# Move mod to suggestions
um in suggestions

**************  SORT MOD   **************  SORT MOD   **************

EOT
}

while getopts "h" options; do
  case $options in

    h ) usage ; exit 0  ;;
    \?) usage ; exit 1  ;;
    * ) usage ; exit 1  ;;

  esac
done

shift $(($OPTIND - 1))

mod_id=     # Get the id of the mod.

(( $# > 1 )) && { usage ; exit 1 ;}
(( $# ==  1 )) && mod_id=$1 || mod_id=$(< $DM_USERS/current_mod)
[[ -z $mod_id ]] && { echo 'ERROR: Unable to determine current mod id.' >&2 ; exit 1 ;}
which vim &>/dev/null || { echo "vim not installed" ; exit 1 ;}

tmpdir=$(tmp_dir)
mkdir -p "$tmpdir"
description="$(< $(find $DM_ROOT/ -type d -name $mod_id)/description)" # Get raw mod description
description=${description//[^a-zA-Z0-9 ]/}            # Sanitize mod description
description=${description// /_}                       # Change spaces to _'s in mod description
file=${tmpdir}/${mod_id}-${description}.txt
echo -n '' > $file                          # Empty if it exists

# Check if we are sorting
unsorted="$DM_PERSON_USERNAME/unsorted"
now="$DM_PERSON_USERNAME/now"

tree=$(grep -lsr "\[.\] $mod_id" $DM_TREES/*)
tree_base=
vim_opt=

if [[ $tree == $DM_TREES/$unsorted ]]; then
    tree_base='unsorted'
    sort_msg >> $file
    vim_opt='-R'                # Readonly
fi

if [[ $tree == $DM_TREES/$now ]]; then
    tree_base='now'
    sort_msg >> $file
    vim_opt='-R'                # Readonly
fi

$DM_BIN/assemble_mod.sh $mod_id >> $file

cp -p $file{,.bak}      # Back up file
vim '+' $vim_opt "$file"  # Edit the file

# Test if file was changed, if so save is required.
diff -q $file ${file}.bak > /dev/null
if (( $? == 0 )); then
    echo "Quit without saving."
else
    echo "Saving file $file to mod $mod_id."
    $DM_BIN/dissemble_mod.sh $file $mod_id
    $DM_BIN/format_mod_in_tree.sh "$mod_id"
fi

exit 0
