#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
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

_options() {
    # set defaults
    args=()
    mod_id=

    while [[ $1 ]]; do
        case "$1" in
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} > 1 )) && { _u; exit 1; }
    (( ${#args[@]} == 0 )) && args[0]=$(< "$DM_USERS/current_mod")
    mod_id=${args[0]}
}

_options "$@"

[[ ! $mod_id ]] && __me 'Unable to determine current mod id.'

tmpdir=$(tmp_dir)
mkdir -p "$tmpdir"
description=$(attribute $mod_id 'description')      # Get raw mod description
description=${description//[^a-zA-Z0-9 ]/}          # Sanitize mod description
description=${description// /_}                     # Change spaces to _'s in mod description
file=$tmpdir/${mod_id}-${description}.txt
echo -n '' > "$file"                                # Empty if it exists

# Check if we are sorting
unsorted=$DM_PERSON_USERNAME/unsorted
now=$DM_PERSON_USERNAME/now
tree=$(grep -lsr "\[.\] $mod_id" $DM_TREES/*)

"$DM_BIN/assemble_mod.sh" "$mod_id" >> "$file"

cp -p "$file"{,.bak}    # Back up file
vim '+' "$file"         # Edit the file

# Test if file was changed, if so save is required.
diff -q "$file" "${file}.bak" >/dev/null && __me "Quit without saving."

echo "Saving file $file to mod $mod_id."
"$DM_BIN/dissemble_mod.sh" "$file" "$mod_id"
"$DM_BIN/format_mod_in_tree.sh" "$mod_id"
