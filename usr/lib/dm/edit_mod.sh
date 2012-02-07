#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [mod_id]

This script assembles a mod, opens it in an editor, then dissembles it.
    -h      Print this help message.

EXAMPLE:
    $script 12345

NOTES:
    If a mod id is not provided, the current one is used, ie. the one
    indicated in $DM_USERS/current_mod
EOF
}

_options() {
    args=()
    unset mod_id
    unset verbose

    while [[ $1 ]]; do
        case "$1" in
            -v) verbose=true    ;;
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

tmpdir=$(__tmp_dir)
mkdir -p "$tmpdir"
description=$(__attribute $mod_id 'description')    # Get raw mod description
description=${description//[^a-zA-Z0-9 ]/}          # Sanitize mod description
description=${description// /_}                     # Change spaces to _'s in mod description
file=$tmpdir/$mod_id-$description.txt
echo -n '' > "$file"                                # Empty if it exists

"$DM_BIN/assemble_mod.sh" "$mod_id" >> "$file" || exit 1

cp -p "$file"{,.bak}    # Back up file
[[ $EDITOR == vim ]] && vim '+' "$file" || "$EDITOR" "$file"    # Edit the file

# Test if file was changed, if so save is required.
diff -q "$file" "$file.bak" >/dev/null && __me "Quit without saving."

__v && __mi "Saving file $file to mod $mod_id."
"$DM_BIN/dissemble_mod.sh" "$file" "$mod_id"
"$DM_BIN/format_mod_in_tree.sh" "$mod_id"
who=$(__attribute "$mod_id" 'who')
"$DM_BIN/assign_mod.sh" -m "$mod_id" "$who"
