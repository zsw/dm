#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh

script=${0##*/}
_u() { cat << EOF
usage: $script mod_id

This script undones a mod, ie it moves it from the archive to the mods
directory.
    -f      Force mod off hold.
    -h      Print this help message.

EXAMPLE:
    $script 12345            # Undone mod 12345
    $script -f 12222         # Undone mod 12222 and take off hold.

NOTES:
    This script is useful for resetting recurring mods with a crontab
    entry. For example:

        # Undone mod every Wednesday at 9am.
        00 09 * * 3 /root/dm/bin/run.sh undone.sh -f 12345
EOF
}

_options() {
    args=()
    unset force
    unset mod

    while [[ $1 ]]; do
        case "$1" in
            -f) force=1         ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

     (( ${#args[@]} != 1 )) && { _u; exit 1; }
     mod=${args[0]}
}

_options "$@"


mod_dir=$(__mod_dir "$mod")
[[ ! $mod_dir ]] && __me "Unable to find mod: $mod in either $DM_MODS or $DM_ARCHIVE."


# If the mod is in both the mods and archive directories, we have foo.
# Better to exit with error message and let the user handle this manually.
[[ -d $DM_ARCHIVES/$mod && -d $DM_MODS/$mod ]] && __me "mod: $mod exists in both $DM_MODS and $DM_ARCHIVE."

# Mods in archived trees are not prioritized. If the mod is in an archived tree
# it has to be moved to an unarchived tree.
#
# Technically a mod should be only in one tree but set up a loop in case of
# unusual data. It's not the place of this script to fix unusual data but it
# can report it.

mod_list=$(grep --exclude=sed* -rP "^ *\[.\] $mod " "$DM_TREES"/*)
mod_count=$(wc -l <<< "$mod_list")
if (( $mod_count > 1 )); then
    echo "$mod_list"
    __me "mod $mod found in multiple trees" >&2
fi

[[ ! $mod_list ]] && __me "mod $mod not found in any tree."

from_tree=${mod_list%%:*}

# Is the tree an archive tree? if so move it out.
if grep -qP "^$DM_TREES_ARCHIVE/" <<< "$from_tree"; then
    to_tree=${from_tree/$DM_TREES_ARCHIVE/$DM_TREES}
    __mi "mod $mod will be moved from an archive tree $from_tree to a live tree $to_tree" >&2
    # Capture result so it doesn't print to stdout
    "$DM_BIN/mv_mod_to_tree.sh" "$mod" "$to_tree" >/dev/null || exit 1
fi

# Move the mod from archive to the mods directory if necessary
[[ $mod_dir == $DM_ARCHIVE/$mod ]] && { mv "$DM_ARCHIVE/$mod" "$DM_MODS/" || exit 1; }

# Take the mod off hold if applicable
status=$(__hold_status "$mod" | awk '{print $5}')

if [[ $status != off_hold ]]; then
    if [[ $force ]]; then
        $DM_BIN/take_off_hold.sh -f $mod
    else
        __mi "undone_mod.sh: Mod $mod has been undone but is on hold." \
            "No force option provided. Mod is left on hold." \
            "" \
            "ID    WHO HOLD                 TREE          DESCRIPTION"
        echo -n "===: "
        echo "$mod" | "$DM_BIN/format_mod.sh"
    fi
fi

# Get the hold status again in case the call to take_off_hold.sh above changed it
status=$(__hold_status "$mod" | awk '{print $5}')
# Trigger remind alerts if necessary (useful if mod was undoned by cron)
[[ $status == off_hold ]] && "$DM_BIN/remind_mod.sh" "$mod"

# Assign mod to the current user
"$DM_BIN/assign_mod.sh" -m "$mod" -u

# Format the mod properly in the tree
"$DM_BIN/format_mod_in_tree.sh" "$mod"
