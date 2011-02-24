#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh

script=${0##*/}
_u() { cat << EOF
usage:   $script mod_id

This script guts a mod.
    -h  Print this help message.

EXAMPLES:
    $script 12345       # Gut mod 12345

NOTES:
    Gutting a mod does the following

    * Removes all mod attribute files and attachments.
    * Creates a description for the mod: "Blank mod"
    * Assigns the mod to the person associated with \$USERNAME

    WARNING: Gutting a mod will destroy its contents.
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

    (( ${#args[@]} != 1 )) && { _u; exit 1; }
    mod_id=${args[0]}
}

_options "$@"

mod_dir=$(mod_dir "$mod_id")

[[ ! -d $mod_dir ]] && __me "Directory $mod_dir not found"

[[ $mod_dir =~ /(mods|archive)/ ]] && rm -r "$mod_dir"
mkdir -p "$mod_dir"

echo 'Blank mod' > "$mod_dir/description"
echo "$DM_PERSON_INITIALS" > "$mod_dir/who"
