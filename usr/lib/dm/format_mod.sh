#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh

script=${0##*/}
_u() { cat << EOF

usage: echo mod_id | $script  [format]
or     echo /path/to/mod/directory | $script [format]

This script formats attributes of a mod suitable for printing.
    -t  Tree format. full=complete path,      eg /root/dm/trees/jimk/reminders
                     sub=include subdirectory,eg jimk/reminders
                     name=tree name only,     eg reminders (default)

    -h  Print this help message.

EXAMPLES:
    echo 12345 | $script
    echo \$DM_ROOT/mods/12345 | $script
    find \$DM_ROOT/ | filter_mods.pl | sort | $script

    # Example output

    12345  JK ---------- --:--:-- main  Do the thing whereby the problem is fixed.

NOTES:
    The format string controls the output.  Interpreted sequences are:

    %%   A literal %.
    %b   Box, [ ] if mod is live, [x] if mod is done
    %d   Contents of /description
    %h   Contents of /hold, or "---------- --:--:--" nothing in hold/.
    %i   The mod's id (scraped from the subdirectory name)
    %l   Location: mods or archive.
    %t   The dependency tree the mod belongs to.
    %w   Contents of /who (three initials, left-padded, empty if unassigned).

    The format will default to "%i %w %h %t %l %d" if unspecified.


    The -t tree format option can take the following values.

    Option  Description             Example

    name    Tree name only          reminders
    sub     Include subdirectory    jimk/reminders
    full    Complete path           /root/dm/trees/jimk/reminders

    If the option is not provided, the "name" format is used.

    When the "-t name" options is used, trees in the $DM_ROOT/trees/archive
    directory are prefixed with x_ to distinguish them from trees with the same
    name in the $DM_ROOT/trees directory. For example:

    tree                            name
    $DM_ROOT/trees/main             main
    $DM_ROOT/trees/archive/main     x_main
EOF
}

#
# _tree_name
#
# Sent: tree file name
# Return: tree name
# Purpose:
#
#   Return the name of the tree for the given tree file name.
#
_tree_name() {
    local file name sub_name subdir

    file=$1
    name=${file##*/}
    sub_name=${tree#$DM_TREES/}
    subdir=${sub_name%%/*}

    ## Add a prefix to distinguish trees in the archive directory
    [[ $subdir == archive ]] && name=x_$name

    echo "$name"
}

_options() {
    # set defaults
    args=()
    tree_format=name

    while [[ $1 ]]; do
        case "$1" in
            -t) shift; tree_format=$1 ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} > 1 )) && { _u; exit 1; }
    (( ${#args[@]} == 0 )) && args[0]="%i %w %h %t %l %d"
    format=${args[0]}
}

_options "$@"


while IFS="" read -r mod; do
    if [[ ${mod:0:1} == / ]]; then
        mod_dir=$mod
    else
        mod_dir=$(mod_dir "$mod")
    fi

    [[ ! $mod_dir ]] && __mi "Unable to locate directory for mod $mod" >&2

    id=${mod##*/}
    line=$format

    # Replace %% with an placeholder character, the "\x1b" (ESC) is used
    # because it's not likely to be in the mod text, so the % symbols do not
    # interfere with pattern matching. Later, the "\e" will be replaced with %%
    # again to restore it.
    line=${line//\%\%/$'\x1b'}

    line=${line//\%i/$id}

    if [[ $format == *%b* ]]; then
        box="[ ]"
        [[ $mod_dir == $DM_ARCHIVE/$id ]] && box="[x]"
        line=${line//\%b/$box}
    fi

    if [[ $format == *%d* ]]; then
        line=${line//\%d/$(< "$mod_dir/description")}
    fi

    if [[ $format == *%h* ]]; then
        unset hold
        if [[ -e $mod_dir/hold ]]; then
            hold=$(hold_timestamp "$id")
        fi
        [[ ! $hold ]] && hold='---------- --:--:--'
        line=${line//\%h/$hold}
    fi

    if [[ $format == *%l* ]]; then
        location='????'
        [[ $mod_dir == $DM_MODS/$id ]]    && location='mods'
        [[ $mod_dir == $DM_ARCHIVE/$id ]] && location='arch'
        line=${line//\%l/$location}
    fi

    if [[ $format == *%t* ]]; then
        tree=$(grep -lsr "\[.\] $id" "$DM_TREES"/*)
        [[ $tree =~ $'\n' ]] && __me "Mod $id found in multiple trees: $tree"

        case "$tree_format" in
            full) size=30 ;;
            name) tree=$(_tree_name "$tree") size=9 ;;
             sub) tree=${tree#$DM_TREES/} size=20   ;;
               *) __me "Invalid tree format: $tree_format" ;;
        esac
        # The printf "%10.10s" format means print exactly 10 characters regardless
        # if the string is more or less than 10 characters.
        line=${line//\%t/$(printf "%${size}.${size}s" "$tree")}
    fi

    if [[ $format == *%w* ]]; then
        who=$(< "$mod_dir/who")
        line=${line//\%w/$(printf "%3s" "$who")}
    fi

    line=${line//$'\x1b'/%}       # Restore literal %

    echo "$line"
done
