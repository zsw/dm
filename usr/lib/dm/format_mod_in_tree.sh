#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
usage: $script mod_id [/full/path/to/tree/file]

Format a mod description in a tree.
   -h      Print this help message.

EXAMPLES:
    # Format mod 12345 in the main tree
    $script 12345 $DM_ROOT/trees/main

NOTES:
    A typical mod description is:

        [ ] 12345 This is the mod description

    If the mod is already in the tree, the existing description is
    replaced. Indentation is preserved.

    If the mod is not in the tree, the mod description is appended to
    the end of the tree.

    Paths to tree files must be absolute.

    If a path to a tree file is not provided, ie only one argument, the
    mod_id, is provided, the mod description is formatted in all trees
    that it currently exists in. Under normal conditions that should be
    only one tree, but if it happens to be in more than one tree, it
    will be updated in each of them. If it is not in any tree, nothing
    is done.
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

    (( ${#args[@]} > 2 )) && { _u; exit 1; }
    (( ${#args[@]} < 1 )) && { _u; exit 1; }
    mod_id=${args[0]}
    tree=${args[1]}
}

_options "$@"

# Ensure mod is valid
mod_dir=$(__mod_dir "$mod_id")

[[ ! $mod_dir ]] && __me "Unable to find mod $mod_id in either $DM_MODS or $DM_ARCHIVE."

unset trees
if [[ $tree ]]; then
    # This will verify the tree exists and is a tree file
    [[ -f $tree && $tree =~ ^$DM_TREES ]] || __me "Tree $tree not found"
    trees=$tree
else
    # Get all trees the mod is in
    # trees=$(find $DM_TREES/ -type f ! -name 'sed*' -exec grep -l "\[.\] $mod_id"  '{}' \;)
    trees=$(grep -lr "\[.\] $mod_id" "$DM_TREES/")
fi

# If the mod is in no trees exit quietly.
[[ ! $trees ]] && __me "Mod $mod_id not found in tree $tree"

# The code below attempts to:
# * Match characters with special meaning within regexp properly.
# * Not match lines where the mod id is within the description of
#   another mod.
# * Preserve indentation.
# Normally sed would be used to search and replace but since it doesn't
# handle special characters well, awk is used.

tmpfile=$(__tmp_file)
line=$("$DM_BIN/format_mod.sh" "%b %i %d" <<< "$mod_id")
pattern="[ ]*\\\[[ x]\\\] $mod_id "
IFS=$'\n'
for t in $trees; do
    if grep -q "\[.\] $mod_id" "$t"; then
        # Replace in tree file
        awk -v line="$line" -v pat="$pattern" \
            '$0 ~ pat {sub(/\[.*$/, line)}; \
            {print}' "$t" > "$tmpfile" && \
            mv "$tmpfile" "$t"
    else
        # Append to tree file
        echo "$line" >> "$t"
    fi
done
